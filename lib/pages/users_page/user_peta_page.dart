import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart'; // tambahkan geolocator di pubspec.yaml
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../services/users.dart';

/// =========================================================
/// MODEL DATA LOKASI (versi user -- read only + info jarak/favorit)
/// =========================================================
class LokasiUserData {
  final int id;
  final String nama;
  final LatLng koordinat;
  final int aqi;
  final String updateTerakhir;

  final double? pm25;
  final double? pm10;
  final double? co;
  final double? no2;
  final double? so2;
  final double? o3;

  // TAMBAHAN untuk kartu detail seperti mockup. Belum ada kolomnya di
  // tabel `lokasi` saat ini -- kalau nanti kolomnya ditambahkan
  // (mis. `suhu`, `kelembapan`), tinggal isi mapping-nya di fromJson.
  final double? suhu;
  final double? kelembapan;

  // Hanya terisi kalau data ini datang dari hasil pencarian "lokasi terdekat"
  final double? jarakKm;

  LokasiUserData({
    required this.id,
    required this.nama,
    required this.koordinat,
    required this.aqi,
    required this.updateTerakhir,
    this.pm25,
    this.pm10,
    this.co,
    this.no2,
    this.so2,
    this.o3,
    this.suhu,
    this.kelembapan,
    this.jarakKm,
  });

  factory LokasiUserData.fromJson(Map<String, dynamic> json) {
    return LokasiUserData(
      id: int.parse(json["id"].toString()),
      nama: json["nama"] ?? "",
      koordinat: LatLng(
        double.parse(json["latitude"].toString()),
        double.parse(json["longitude"].toString()),
      ),
      aqi: json["aqi"] != null ? int.tryParse(json["aqi"].toString()) ?? 0 : 0,
      updateTerakhir: json["update_terakhir"]?.toString() ?? "-",
      pm25: _toDoubleOrNull(json["pm25"]),
      pm10: _toDoubleOrNull(json["pm10"]),
      co: _toDoubleOrNull(json["co"]),
      no2: _toDoubleOrNull(json["no2"]),
      so2: _toDoubleOrNull(json["so2"]),
      o3: _toDoubleOrNull(json["o3"]),
      suhu: _toDoubleOrNull(json["suhu"]),
      kelembapan: _toDoubleOrNull(json["kelembapan"]),
      jarakKm: _toDoubleOrNull(json["jarak_km"]),
    );
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  bool get punyaParameter =>
      pm25 != null || pm10 != null || co != null || no2 != null || so2 != null || o3 != null;

  // Disederhanakan jadi 4 kategori sesuai legenda di mockup:
  // Baik / Sedang / Tidak Sehat / Berbahaya
  String get kategori {
    if (aqi <= 50) return "Baik";
    if (aqi <= 100) return "Sedang";
    if (aqi <= 150) return "Tidak Sehat";
    return "Berbahaya";
  }

  Color get warna {
    if (aqi <= 50) return AppColors.baik;
    if (aqi <= 100) return AppColors.sedang;
    if (aqi <= 150) return AppColors.tidakSehat;
    return AppColors.berbahaya;
  }
}

/// Palet warna khusus status AQI, dipakai berulang di banyak tempat
/// (pin peta, badge, ringkasan status, kartu detail).
class AppColors {
  static const Color primary = Color(0xFF2AA9E0);
  static const Color baik = Color(0xFF2FB259);
  static const Color sedang = Color(0xFFF2C230);
  static const Color tidakSehat = Color(0xFFF08A2E);
  static const Color berbahaya = Color(0xFFE0473C);
}

/// =========================================================
/// SERVICE -- panggilan ke user/user_peta.php (endpoint khusus user)
/// =========================================================
class LokasiUserService {
  static const String _endpoint = "${ApiService.baseUrl}/user/user_peta.php";

  static Future<List<LokasiUserData>> list({String search = ""}) async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action": "list",
      "search": search,
    });
    final body = jsonDecode(res.body);
    if (body["status"] == true) {
      return (body["data"] as List).map((e) => LokasiUserData.fromJson(e)).toList();
    }
    throw Exception(body["message"] ?? "Gagal mengambil data lokasi");
  }

  static Future<LokasiUserData> detail(int id) async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action": "detail",
      "id": id.toString(),
    });
    final body = jsonDecode(res.body);
    if (body["status"] == true) {
      return LokasiUserData.fromJson(body["data"]);
    }
    throw Exception(body["message"] ?? "Lokasi tidak ditemukan");
  }

  static Future<List<LokasiUserData>> nearest({
    required double latitude,
    required double longitude,
    int limit = 5,
  }) async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action": "nearest",
      "latitude": latitude.toString(),
      "longitude": longitude.toString(),
      "limit": limit.toString(),
    });
    final body = jsonDecode(res.body);
    if (body["status"] == true) {
      return (body["data"] as List).map((e) => LokasiUserData.fromJson(e)).toList();
    }
    throw Exception(body["message"] ?? "Gagal mencari lokasi terdekat");
  }

  // user_id TIDAK dikirim manual dari sini -- user_peta.php mengambilnya
  // dari $_SESSION['user_id'] yang sudah di-set oleh auth/login.php.
  // Pastikan http client yang dipakai ApiService menyimpan & mengirim
  // cookie session PHP (mis. pakai package cookie_jar / dio) supaya ini jalan.

  static Future<List<LokasiUserData>> favoritList() async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action": "favorit_list",
    });
    final body = jsonDecode(res.body);
    if (body["status"] == true) {
      return (body["data"] as List).map((e) => LokasiUserData.fromJson(e)).toList();
    }
    throw Exception(body["message"] ?? "Gagal mengambil data favorit");
  }

  static Future<void> favoritTambah(int lokasiId) async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action": "favorit_tambah",
      "lokasi_id": lokasiId.toString(),
    });
    final body = jsonDecode(res.body);
    if (body["status"] != true) {
      throw Exception(body["message"] ?? "Gagal menambah favorit");
    }
  }

  static Future<void> favoritHapus(int lokasiId) async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action": "favorit_hapus",
      "lokasi_id": lokasiId.toString(),
    });
    final body = jsonDecode(res.body);
    if (body["status"] != true) {
      throw Exception(body["message"] ?? "Gagal menghapus favorit");
    }
  }
}

/// =========================================================
/// HALAMAN UTAMA (USER) -- Peta Lokasi, sesuai mockup PureAir
/// =========================================================
class MapAirQualityUserPage extends StatefulWidget {
  const MapAirQualityUserPage({super.key});

  @override
  State<MapAirQualityUserPage> createState() => _MapAirQualityUserPageState();
}

class _MapAirQualityUserPageState extends State<MapAirQualityUserPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<LokasiUserData> _lokasiList = [];
  Set<int> _favoritIds = {};

  bool _loading = true;
  String? _error;

  // null = tampilkan semua kategori
  String? _filterKategori;

  LokasiUserData? _selected;
  bool _mencariTerdekat = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData({String? search}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final semua = await LokasiUserService.list(search: search ?? _searchCtrl.text.trim());
      List<LokasiUserData> favorit = [];
      try {
        favorit = await LokasiUserService.favoritList();
      } catch (_) {
        // User belum login / gagal ambil favorit -- jangan blok halaman
      }
      setState(() {
        _lokasiList = semua;
        _favoritIds = favorit.map((e) => e.id).toSet();
        _selected = semua.isNotEmpty
            ? (_selected != null ? semua.firstWhere((l) => l.id == _selected!.id, orElse: () => semua.first) : semua.first)
            : null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<LokasiUserData> get _displayedList {
    if (_filterKategori == null) return _lokasiList;
    return _lokasiList.where((l) => l.kategori == _filterKategori).toList();
  }

  int get _totalAktif => _lokasiList.length;
  int get _totalBaik => _lokasiList.where((l) => l.kategori == "Baik").length;
  int get _totalSedang => _lokasiList.where((l) => l.kategori == "Sedang").length;
  int get _totalTidakSehat => _lokasiList.where((l) => l.kategori == "Tidak Sehat").length;
  int get _totalBerbahaya => _lokasiList.where((l) => l.kategori == "Berbahaya").length;

  void _pilihLokasi(LokasiUserData lokasi) {
    setState(() => _selected = lokasi);
    _mapController.move(lokasi.koordinat, 13);
  }

  Future<void> _toggleFavorit(LokasiUserData lokasi) async {
    final sudahFavorit = _favoritIds.contains(lokasi.id);
    setState(() {
      if (sudahFavorit) {
        _favoritIds.remove(lokasi.id);
      } else {
        _favoritIds.add(lokasi.id);
      }
    });
    try {
      if (sudahFavorit) {
        await LokasiUserService.favoritHapus(lokasi.id);
      } else {
        await LokasiUserService.favoritTambah(lokasi.id);
      }
    } catch (e) {
      setState(() {
        if (sudahFavorit) {
          _favoritIds.add(lokasi.id);
        } else {
          _favoritIds.remove(lokasi.id);
        }
      });
      _showError(e.toString());
    }
  }

  Future<void> _cariLokasiTerdekat() async {
    setState(() => _mencariTerdekat = true);
    try {
      final layananAktif = await Geolocator.isLocationServiceEnabled();
      if (!layananAktif) {
        _showError("Aktifkan layanan lokasi (GPS) terlebih dahulu");
        return;
      }
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.deniedForever || izin == LocationPermission.denied) {
        _showError("Izin lokasi ditolak. Aktifkan izin lokasi untuk memakai fitur ini.");
        return;
      }

      final posisi = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      final hasil = await LokasiUserService.nearest(
        latitude: posisi.latitude,
        longitude: posisi.longitude,
        limit: 1,
      );

      if (!mounted) return;
      _mapController.move(LatLng(posisi.latitude, posisi.longitude), 12);
      if (hasil.isNotEmpty) {
        setState(() => _selected = hasil.first);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _mencariTerdekat = false);
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final opsi = <String?, String>{
          null: "Semua Status",
          "Baik": "Baik",
          "Sedang": "Sedang",
          "Tidak Sehat": "Tidak Sehat",
          "Berbahaya": "Berbahaya",
        };
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Filter AQI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...opsi.entries.map((e) {
                final aktif = _filterKategori == e.key;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    aktif ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: aktif ? AppColors.primary : Colors.grey,
                  ),
                  title: Text(e.value, style: const TextStyle(fontSize: 14)),
                  onTap: () {
                    setState(() => _filterKategori = e.key);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showDetailSheet(LokasiUserData lokasi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final isFavorit = _favoritIds.contains(lokasi.id);
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: lokasi.warna),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text("Sensor ${lokasi.nama}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      onPressed: () async {
                        await _toggleFavorit(lokasi);
                        setSheetState(() {});
                      },
                      icon: Icon(
                        isFavorit ? Icons.favorite : Icons.favorite_border,
                        color: isFavorit ? Colors.redAccent : Colors.grey,
                      ),
                    ),
                  ],
                ),
                _AqiBadge(aqi: lokasi.aqi, kategori: lokasi.kategori, warna: lokasi.warna, besar: true),
                const SizedBox(height: 12),
                _detailRow("Koordinat",
                    "${lokasi.koordinat.latitude.toStringAsFixed(4)}, ${lokasi.koordinat.longitude.toStringAsFixed(4)}"),
                _detailRow("Terakhir update", lokasi.updateTerakhir),
                if (lokasi.punyaParameter) ...[
                  const SizedBox(height: 16),
                  const Text("Parameter Polutan",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 8),
                  _buildParameterGrid(lokasi),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration:
                    BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(10)),
                    child: const Text(
                      "Belum ada data parameter polutan untuk lokasi ini.",
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildParameterGrid(LokasiUserData lokasi) {
    final items = <Map<String, String?>>[
      {"label": "PM2.5", "unit": "µg/m³", "value": lokasi.pm25?.toStringAsFixed(1)},
      {"label": "PM10", "unit": "µg/m³", "value": lokasi.pm10?.toStringAsFixed(1)},
      {"label": "CO", "unit": "ppm", "value": lokasi.co?.toStringAsFixed(2)},
      {"label": "NO2", "unit": "ppb", "value": lokasi.no2?.toStringAsFixed(1)},
      {"label": "SO2", "unit": "ppb", "value": lokasi.so2?.toStringAsFixed(1)},
      {"label": "O3", "unit": "ppb", "value": lokasi.o3?.toStringAsFixed(1)},
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item["label"]!, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                item["value"] != null ? "${item["value"]} ${item["unit"]}" : "-",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorState()
            : RefreshIndicator(
          onRefresh: () => _loadData(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildSearchFilterRow(),
              const SizedBox(height: 14),
              _buildMapCard(),
              const SizedBox(height: 14),
              _buildSummaryCard(),
              const SizedBox(height: 14),
              if (_selected != null) _buildSelectedLocationCard(_selected!),
            ],
          ),
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.air, color: AppColors.primary, size: 26),
                  SizedBox(width: 8),
                  Text("PureAir", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text("Peta Lokasi"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text("Lokasi Favorit"),
              onTap: () {
                Navigator.pop(context);
                setState(() => _filterKategori = null);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Riwayat"),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _loadData(), child: const Text("Coba lagi")),
          ],
        ),
      ),
    );
  }

  // ---------- Header: back/menu, logo PureAir, profil ----------
  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            Builder(
              builder: (innerCtx) {
                final bisaKembali = Navigator.canPop(innerCtx);
                return IconButton(
                  onPressed: () {
                    if (bisaKembali) {
                      Navigator.pop(innerCtx);
                    } else {
                      Scaffold.of(innerCtx).openDrawer();
                    }
                  },
                  icon: Icon(
                    bisaKembali ? Icons.arrow_back : Icons.menu,
                    color: Colors.black87,
                  ),
                );
              },
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.air, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "PureAir",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                ],
              ),
            ),
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFF0F0F0),
              child: const Icon(Icons.person_outline, color: Colors.black54, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          "Peta Lokasi",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  // ---------- Search + Filter AQI ----------
  Widget _buildSearchFilterRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE3E6EA)),
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: "Cari Lokasi",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(fontSize: 13),
              onSubmitted: (v) => _loadData(search: v),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _showFilterSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE3E6EA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  _filterKategori ?? "Filter AQI",
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Peta dengan pin AQI ----------
  Widget _buildMapCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 300,
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE3E6EA))),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(-6.4, 107.0),
                initialZoom: 8,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: _displayedList.map((lokasi) {
                    final terpilih = _selected?.id == lokasi.id;
                    return Marker(
                      point: lokasi.koordinat,
                      width: 54,
                      height: 54,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: () => _pilihLokasi(lokasi),
                        child: _AqiPin(aqi: lokasi.aqi, warna: lokasi.warna, aktif: terpilih),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            // Tombol zoom +/-
            Positioned(
              right: 10,
              bottom: 10,
              child: Column(
                children: [
                  _zoomButton(Icons.add, () {
                    final z = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, z + 1);
                  }),
                  const SizedBox(height: 6),
                  _zoomButton(Icons.remove, () {
                    final z = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, z - 1);
                  }),
                ],
              ),
            ),
            // Tombol lokasi saya (GPS -- cari sensor terdekat)
            Positioned(
              left: 10,
              bottom: 10,
              child: _zoomButton(
                Icons.my_location,
                _mencariTerdekat ? () {} : _cariLokasiTerdekat,
                loading: _mencariTerdekat,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap, {bool loading = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }

  // ---------- Ringkasan status sensor ----------
  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6EA)),
      ),
      child: Row(
        children: [
          _summaryItem(icon: Icons.location_on, iconColor: Colors.black54, label: "Sensor Aktif", value: "$_totalAktif"),
          _summaryItem(dotColor: AppColors.baik, label: "Baik", value: "$_totalBaik"),
          _summaryItem(dotColor: AppColors.sedang, label: "Sedang", value: "$_totalSedang"),
          _summaryItem(dotColor: AppColors.tidakSehat, label: "Tidak Sehat", value: "$_totalTidakSehat"),
          _summaryItem(dotColor: AppColors.berbahaya, label: "Berbahaya", value: "$_totalBerbahaya"),
        ],
      ),
    );
  }

  Widget _summaryItem({IconData? icon, Color? iconColor, Color? dotColor, required String label, required String value}) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Icon(icon, size: 12, color: iconColor)
              else
                Container(width: 9, height: 9, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5, color: Colors.black54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ---------- Kartu lokasi terpilih ----------
  Widget _buildSelectedLocationCard(LokasiUserData lokasi) {
    final isFavorit = _favoritIds.contains(lokasi.id);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Sensor ${lokasi.nama}",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => _toggleFavorit(lokasi),
                icon: Icon(
                  isFavorit ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: isFavorit ? Colors.redAccent : Colors.grey,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              _AqiBadge(aqi: lokasi.aqi, kategori: lokasi.kategori, warna: lokasi.warna),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _infoBox(
                  "PM2.5",
                  lokasi.pm25 != null ? "${lokasi.pm25!.toStringAsFixed(1)} µg/m³" : "-",
                  "Kelembapan",
                  lokasi.kelembapan != null ? "${lokasi.kelembapan!.toStringAsFixed(0)}%" : "-",
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoBoxSingleRow(
            "Suhu",
            lokasi.suhu != null ? "${lokasi.suhu!.toStringAsFixed(1)}°C" : "-",
            "Waktu",
            lokasi.updateTerakhir,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showDetailSheet(lokasi),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                "Lihat Detail",
                style: TextStyle(color: AppColors.primary, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(String label1, String value1, String label2, String value2) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE3E6EA)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: _infoCell(label1, value1)),
          Container(width: 1, height: 44, color: const Color(0xFFE3E6EA)),
          Expanded(child: _infoCell(label2, value2)),
        ],
      ),
    );
  }

  Widget _infoBoxSingleRow(String label1, String value1, String label2, String value2) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE3E6EA)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: _infoCell(label1, value1)),
          Container(width: 1, height: 44, color: const Color(0xFFE3E6EA)),
          Expanded(child: _infoCell(label2, value2)),
        ],
      ),
    );
  }

  Widget _infoCell(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Badge bulat kecil "95 Sedang" di kartu lokasi / detail sheet
class _AqiBadge extends StatelessWidget {
  final int aqi;
  final String kategori;
  final Color warna;
  final bool besar;

  const _AqiBadge({required this.aqi, required this.kategori, required this.warna, this.besar = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: besar ? 40 : 32,
          height: besar ? 40 : 32,
          decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            "$aqi",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: besar ? 13 : 11),
          ),
        ),
        const SizedBox(width: 6),
        Text(kategori, style: TextStyle(fontSize: besar ? 13 : 12, fontWeight: FontWeight.w600, color: warna)),
      ],
    );
  }
}

/// Pin marker di peta -- lingkaran ber-angka AQI dengan ekor kecil di
/// bawahnya, meniru gaya pin pada mockup.
class _AqiPin extends StatelessWidget {
  final int aqi;
  final Color warna;
  final bool aktif;

  const _AqiPin({required this.aqi, required this.warna, this.aktif = false});

  @override
  Widget build(BuildContext context) {
    final ukuran = aktif ? 34.0 : 28.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ukuran,
          height: ukuran,
          decoration: BoxDecoration(
            color: warna,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
          ),
          alignment: Alignment.center,
          child: Text(
            "$aqi",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: aktif ? 11 : 10),
          ),
        ),
        CustomPaint(size: const Size(8, 5), painter: _SegitigaPainter(warna)),
      ],
    );
  }
}

class _SegitigaPainter extends CustomPainter {
  final Color color;
  _SegitigaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}