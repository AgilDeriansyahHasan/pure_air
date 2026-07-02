import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../services/users.dart';

/// =========================================================
/// MODEL DATA LOKASI (mapping dari response lokasi.php)
/// =========================================================
class LokasiData {
  final int id;
  String nama;
  LatLng koordinat;
  bool aktif;
  int aqi;
  String updateTerakhir;

  // Parameter polutan, disinkronkan otomatis dari halaman Validasi
  // Data ketika status sebuah pembacaan di-set "Valid". Bisa null
  // kalau lokasi belum pernah disinkronkan sama sekali.
  double? pm25;
  double? pm10;
  double? co;
  double? no2;
  double? so2;
  double? o3;

  LokasiData({
    required this.id,
    required this.nama,
    required this.koordinat,
    required this.aktif,
    required this.aqi,
    required this.updateTerakhir,
    this.pm25,
    this.pm10,
    this.co,
    this.no2,
    this.so2,
    this.o3,
  });

  factory LokasiData.fromJson(Map<String, dynamic> json) {
    return LokasiData(
      id: int.parse(json["id"].toString()),
      nama: json["nama"] ?? "",
      koordinat: LatLng(
        double.parse(json["latitude"].toString()),
        double.parse(json["longitude"].toString()),
      ),
      aktif: (json["status"] ?? "aktif") == "aktif",
      aqi: json["aqi"] != null
          ? int.tryParse(json["aqi"].toString()) ?? 0
          : 0,
      updateTerakhir: json["update_terakhir"]?.toString() ?? "-",
      pm25: _toDoubleOrNull(json["pm25"]),
      pm10: _toDoubleOrNull(json["pm10"]),
      co: _toDoubleOrNull(json["co"]),
      no2: _toDoubleOrNull(json["no2"]),
      so2: _toDoubleOrNull(json["so2"]),
      o3: _toDoubleOrNull(json["o3"]),
    );
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  // Apakah lokasi ini sudah pernah punya data parameter (bukan cuma AQI)
  bool get punyaParameter =>
      pm25 != null || pm10 != null || co != null || no2 != null || so2 != null || o3 != null;

  // Kategori AQI (bisa disesuaikan ke standar ISPU/EPA)
  String get kategori {
    if (aqi <= 50) return "Baik";
    if (aqi <= 100) return "Sedang";
    if (aqi <= 150) return "Tidak Sehat (SG)";
    if (aqi <= 200) return "Tidak Sehat";
    return "Sangat Tidak Sehat";
  }

  Color get warna {
    if (aqi <= 50) return const Color(0xFF5D9C2E);
    if (aqi <= 100) return const Color(0xFFD7A52E);
    if (aqi <= 150) return const Color(0xFFD7822E);
    if (aqi <= 200) return const Color(0xFFD85A30);
    return const Color(0xFF8E1B1B);
  }
}

/// =========================================================
/// SERVICE -- semua panggilan ke lokasi.php dikumpulkan di sini
/// =========================================================
class LokasiService {
  static Future<List<LokasiData>> list({String search = "", String status = ""}) async {
    final res = await http.post(Uri.parse("${ApiService.baseUrl}/admin/lokasi.php"), body: {
      "action": "list",
      "search": search,
      "status": status,
    });
    final body = jsonDecode(res.body);
    if (body["status"] == true) {
      return (body["data"] as List).map((e) => LokasiData.fromJson(e)).toList();
    }
    throw Exception(body["message"] ?? "Gagal mengambil data lokasi");
  }

  static Future<void> tambah({
    required String nama,
    required double lat,
    required double lon,
    String status = "aktif",
  }) async {
    final res = await http.post(Uri.parse("${ApiService.baseUrl}/admin/lokasi.php"), body: {
      "action": "tambah",
      "nama": nama,
      "latitude": lat.toString(),
      "longitude": lon.toString(),
      "status": status,
    });
    final body = jsonDecode(res.body);
    if (body["status"] != true) {
      throw Exception(body["message"] ?? "Gagal menambah lokasi");
    }
  }

  static Future<void> update({
    required int id,
    required String nama,
    required double lat,
    required double lon,
    String status = "aktif",
  }) async {
    final res = await http.post(Uri.parse("${ApiService.baseUrl}/admin/lokasi.php"), body: {
      "action": "update",
      "id": id.toString(),
      "nama": nama,
      "latitude": lat.toString(),
      "longitude": lon.toString(),
      "status": status,
    });
    final body = jsonDecode(res.body);
    if (body["status"] != true) {
      throw Exception(body["message"] ?? "Gagal memperbarui lokasi");
    }
  }

  static Future<void> hapus(int id) async {
    final res = await http.post(Uri.parse("${ApiService.baseUrl}/admin/lokasi.php"), body: {
      "action": "hapus",
      "id": id.toString(),
    });
    final body = jsonDecode(res.body);
    if (body["status"] != true) {
      throw Exception(body["message"] ?? "Gagal menghapus lokasi");
    }
  }

  /// Cari koordinat dari nama lokasi lewat geocoding (tidak menyimpan apa pun).
  /// Mengembalikan daftar kandidat -- bisa lebih dari satu kalau nama ambigu.
  static Future<List<KandidatLokasi>> cariKoordinat(String nama) async {
    final res = await http.post(Uri.parse("${ApiService.baseUrl}/lokasi.php"), body: {
      "action": "cari_koordinat",
      "nama": nama,
    });
    final body = jsonDecode(res.body);
    if (body["status"] != true) {
      throw Exception(body["message"] ?? "Lokasi tidak ditemukan");
    }
    return (body["data"] as List).map((e) => KandidatLokasi.fromJson(e)).toList();
  }
}

/// Hasil pencarian geocoding -- satu kandidat lokasi yang cocok
/// dengan nama yang diketik admin, sebelum disimpan ke database.
class KandidatLokasi {
  final String nama;
  final String label;
  final double latitude;
  final double longitude;

  KandidatLokasi({
    required this.nama,
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  factory KandidatLokasi.fromJson(Map<String, dynamic> json) {
    return KandidatLokasi(
      nama: json["nama"]?.toString() ?? "",
      label: json["label"]?.toString() ?? "",
      latitude: double.tryParse(json["latitude"].toString()) ?? 0,
      longitude: double.tryParse(json["longitude"].toString()) ?? 0,
    );
  }
}

/// =========================================================
/// HALAMAN UTAMA: LOKASI
/// =========================================================
class MapAirQualityPage extends StatefulWidget {
  const MapAirQualityPage({super.key});

  @override
  State<MapAirQualityPage> createState() => _MapAirQualityPageState();
}

class _MapAirQualityPageState extends State<MapAirQualityPage> {
  final MapController _mapController = MapController();

  List<LokasiData> _lokasiList = [];
  bool _loading = true;
  String? _error;

  String _searchQuery = "";
  String _filterStatus = "Semua Status";

  // Dipakai untuk mode "tap peta untuk pilih koordinat" saat tambah lokasi
  LatLng? _tappedPoint;
  bool _pickMode = false;

  // Titik preview dari hasil pencarian nama lokasi (mode "cari").
  // Beda dari _tappedPoint (hasil tap manual di peta). Saat ada
  // nilai, peta utama otomatis bergeser ke titik ini dan menampilkan
  // marker khusus -- tanpa menutup sheet form di atasnya.
  LatLng? _previewPoint;
  String? _previewLabel;

  // Tombol "Export ke Laporan"
  bool _mengekspor = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statusParam = _filterStatus == "Aktif"
          ? "aktif"
          : _filterStatus == "Nonaktif"
          ? "nonaktif"
          : "";
      final data = await LokasiService.list(search: _searchQuery, status: statusParam);
      setState(() => _lokasiList = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  int get _totalLokasi => _lokasiList.length;
  int get _totalAktif => _lokasiList.where((l) => l.aktif).length;
  int get _totalNonaktif => _lokasiList.where((l) => !l.aktif).length;
  int get _totalTidakSehat => _lokasiList.where((l) => l.aqi > 100).length;

  /// Dipanggil dari FlutterMap saat peta di-tap (dipakai saat mode tambah lokasi)
  void _onTapMap(LatLng pos) {
    if (!_pickMode) return;
    setState(() => _tappedPoint = pos);
  }

  void _onMarkerTap(LokasiData lokasi) {
    _mapController.move(lokasi.koordinat, 12);
    _showLokasiDetailSheet(lokasi);
  }

  /// Geser peta utama ke titik hasil pencarian nama lokasi dan
  /// tampilkan marker preview, tanpa menutup sheet form di atasnya.
  void _showPreviewOnMap(LatLng pos, String label) {
    setState(() {
      _previewPoint = pos;
      _previewLabel = label;
    });
    _mapController.move(pos, 13);
  }

  void _clearPreview() {
    setState(() {
      _previewPoint = null;
      _previewLabel = null;
    });
  }

  // ===================== EXPORT KE LAPORAN =====================

  /// Kirim ringkasan kondisi semua lokasi (total, aktif, nonaktif,
  /// tidak sehat) ke laporan.php sebagai kategori "lokasi". Detail
  /// lengkap per-lokasi diambil ulang dari DB saat item laporan ini
  /// dibuka (action=detail_lokasi), bukan dibekukan di sini.
  Future<void> _kirimKeLaporan() async {
    if (_lokasiList.isEmpty) {
      _showError("Tidak ada data lokasi untuk dikirim");
      return;
    }
    if (_mengekspor) return;

    setState(() => _mengekspor = true);
    try {
      final ringkasan = "Total $_totalLokasi lokasi "
          "(Aktif: $_totalAktif, Nonaktif: $_totalNonaktif, "
          "Tidak sehat: $_totalTidakSehat)";

      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
        body: {
          "action": "kirim",
          "kategori": "lokasi",
          "ringkasan": ringkasan,
        },
      );

      if (!mounted) return;

      if (response.body.isEmpty) {
        throw "Server tidak mengirim response";
      }

      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['status'] == "success"
                ? "Data lokasi berhasil dikirim ke laporan"
                : (data['message'] ?? "Gagal mengirim ke laporan"),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _mengekspor = false);
    }
  }

  // ===================== DETAIL SHEET =====================

  void _showLokasiDetailSheet(LokasiData lokasi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lokasi.nama,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: lokasi.warna.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${lokasi.aqi}",
                      style: TextStyle(color: lokasi.warna, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                lokasi.kategori,
                style: TextStyle(color: lokasi.warna, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              _detailRow(
                "Koordinat",
                "${lokasi.koordinat.latitude.toStringAsFixed(4)}, "
                    "${lokasi.koordinat.longitude.toStringAsFixed(4)}",
              ),
              _detailRow("Terakhir update", lokasi.updateTerakhir),
              _detailRow("Status", lokasi.aktif ? "Aktif" : "Nonaktif"),

              // Parameter polutan, hanya ditampilkan kalau lokasi ini
              // sudah pernah disinkronkan dari halaman Validasi Data
              // (statusnya pernah "Valid").
              if (lokasi.punyaParameter) ...[
                const SizedBox(height: 16),
                const Text(
                  "Parameter Polutan",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                _buildParameterGrid(lokasi),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "Belum ada data parameter polutan untuk lokasi ini. "
                        "Data akan terisi otomatis setelah ada pembacaan yang "
                        "ditandai \"Valid\" di halaman Validasi Data.",
                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showLokasiForm(existing: lokasi);
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text("Edit"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDelete(lokasi);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text("Hapus"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParameterGrid(LokasiData lokasi) {
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
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(8),
          ),
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
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(LokasiData lokasi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus lokasi?"),
        content: Text("Lokasi \"${lokasi.nama}\" akan dihapus permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await LokasiService.hapus(lokasi.id);
                _loadData();
              } catch (e) {
                _showError(e.toString());
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ===================== FORM TAMBAH / EDIT =====================

  void _showLokasiForm({LokasiData? existing}) {
    final namaCtrl = TextEditingController(text: existing?.nama ?? "");
    final latCtrl = TextEditingController(
      text: existing?.koordinat.latitude.toString() ?? _tappedPoint?.latitude.toString() ?? "",
    );
    final lonCtrl = TextEditingController(
      text: existing?.koordinat.longitude.toString() ?? _tappedPoint?.longitude.toString() ?? "",
    );
    bool aktif = existing?.aktif ?? true;
    bool saving = false;

    // Mode hanya relevan untuk tambah lokasi baru -- saat edit,
    // koordinat sudah ada jadi langsung pakai input manual.
    // "cari" = ketik nama, koordinat dicari otomatis lewat geocoding.
    // "peta" = cara lama, tap peta untuk pilih titik.
    String mode = existing != null
        ? "peta"
        : (_tappedPoint != null ? "peta" : "cari");

    bool searching = false;
    String? searchError;
    List<KandidatLokasi> kandidatList = [];
    KandidatLokasi? kandidatTerpilih;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {

            Future<void> doSearch() async {
              if (namaCtrl.text.trim().isEmpty) {
                setSheetState(() => searchError = "Ketik nama lokasi dulu");
                return;
              }
              setSheetState(() {
                searching = true;
                searchError = null;
                kandidatList = [];
                kandidatTerpilih = null;
              });
              _clearPreview();
              try {
                final hasil = await LokasiService.cariKoordinat(namaCtrl.text.trim());
                setSheetState(() {
                  kandidatList = hasil;
                  searching = false;
                });
                // Kalau cuma satu kandidat yang cocok, langsung pilih
                // otomatis dan tampilkan preview-nya di peta -- admin
                // tidak perlu tap lagi untuk kasus yang jelas.
                if (hasil.length == 1) {
                  final k = hasil.first;
                  setSheetState(() {
                    kandidatTerpilih = k;
                    namaCtrl.text = k.nama;
                    latCtrl.text = k.latitude.toString();
                    lonCtrl.text = k.longitude.toString();
                  });
                  _showPreviewOnMap(LatLng(k.latitude, k.longitude), k.label);
                }
              } catch (e) {
                setSheetState(() {
                  searchError = e.toString().replaceFirst("Exception: ", "");
                  searching = false;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null ? "Tambah Lokasi" : "Edit Lokasi",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      existing == null
                          ? "Cari berdasarkan nama, atau pilih titik langsung di peta."
                          : "Ubah data lokasi lalu simpan.",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),

                    // ── Toggle mode, hanya saat tambah baru ──────────
                    if (existing == null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _modeChip(
                              label: "Cari nama",
                              selected: mode == "cari",
                              onTap: () => setSheetState(() {
                                mode = "cari";
                                _pickMode = false;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _modeChip(
                              label: "Pilih di peta",
                              selected: mode == "peta",
                              onTap: () {
                                Navigator.pop(ctx);
                                _tappedPoint = null;
                                _startAddLocation();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    _inputField("Nama lokasi", namaCtrl),

                    // ── MODE: CARI NAMA ───────────────────────────────
                    if (mode == "cari") ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: searching ? null : doSearch,
                          icon: searching
                              ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.search, size: 16),
                          label: Text(searching ? "Mencari..." : "Cari koordinat"),
                        ),
                      ),
                      if (searchError != null) ...[
                        const SizedBox(height: 8),
                        Text(searchError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                      ],
                      if (kandidatList.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text("Pilih lokasi yang cocok:",
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 6),
                        ...kandidatList.map((k) {
                          final terpilih = kandidatTerpilih == k;
                          return GestureDetector(
                            onTap: () => setSheetState(() {
                              kandidatTerpilih = k;
                              namaCtrl.text = k.nama;
                              latCtrl.text = k.latitude.toString();
                              lonCtrl.text = k.longitude.toString();
                            }),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: terpilih ? const Color(0xFFEFF6FF) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: terpilih ? const Color(0xFF2563EB) : const Color(0xFFE0E0E0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    terpilih ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    size: 16,
                                    color: terpilih ? const Color(0xFF2563EB) : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(k.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        Text(
                                          "${k.latitude.toStringAsFixed(4)}, ${k.longitude.toStringAsFixed(4)}",
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ]

                    // ── MODE: PILIH DI PETA ───────────────────────────
                    else ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _inputField("Latitude", latCtrl, keyboardType: TextInputType.number),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _inputField("Longitude", lonCtrl, keyboardType: TextInputType.number),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text("Status", style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text("Aktif"),
                          selected: aktif,
                          onSelected: (v) => setSheetState(() => aktif = true),
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(color: aktif ? Colors.white : Colors.black87),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text("Nonaktif"),
                          selected: !aktif,
                          onSelected: (v) => setSheetState(() => aktif = false),
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(color: !aktif ? Colors.white : Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _tappedPoint = null;
                              Navigator.pop(ctx);
                            },
                            child: const Text("Batal"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: saving
                                ? null
                                : () async {
                              final lat = double.tryParse(latCtrl.text);
                              final lon = double.tryParse(lonCtrl.text);
                              if (namaCtrl.text.trim().isEmpty || lat == null || lon == null) {
                                _showError(mode == "cari"
                                    ? "Cari dan pilih lokasi dulu sebelum menyimpan"
                                    : "Lengkapi semua data dengan benar");
                                return;
                              }
                              setSheetState(() => saving = true);
                              try {
                                if (existing != null) {
                                  await LokasiService.update(
                                    id: existing.id,
                                    nama: namaCtrl.text.trim(),
                                    lat: lat,
                                    lon: lon,
                                    status: aktif ? "aktif" : "nonaktif",
                                  );
                                } else {
                                  await LokasiService.tambah(
                                    nama: namaCtrl.text.trim(),
                                    lat: lat,
                                    lon: lon,
                                    status: aktif ? "aktif" : "nonaktif",
                                  );
                                }
                                _tappedPoint = null;
                                _pickMode = false;
                                if (mounted) Navigator.pop(ctx);
                                _loadData();
                              } catch (e) {
                                _showError(e.toString());
                                setSheetState(() => saving = false);
                              }
                            },
                            child: saving
                                ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Text(
                              "Simpan lokasi",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => setState(() => _pickMode = false));
  }

  Widget _modeChip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE0E0E0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
          ),
        ),
      ],
    );
  }

  void _startAddLocation() {
    setState(() => _pickMode = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ketuk titik di peta untuk memilih koordinat")),
    );
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Lokasi"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            onPressed: _mengekspor ? null : _kirimKeLaporan,
            tooltip: "Export ke Laporan",
            icon: _mengekspor
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.ios_share),
          ),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        onPressed: () {
          if (_pickMode && _tappedPoint != null) {
            _showLokasiForm();
          } else {
            _startAddLocation();
          }
        },
        icon: Icon(_pickMode ? Icons.check : Icons.add, color: Colors.white),
        label: Text(
          _pickMode ? "Pakai titik ini" : "Tambah Lokasi",
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
              ElevatedButton(onPressed: _loadData, child: const Text("Coba lagi")),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildSummaryGrid(),
        const SizedBox(height: 12),
        _buildSearchAndFilter(),
        const SizedBox(height: 12),
        if (_pickMode) _buildPickModeBanner(),
        _buildMap(),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text("Daftar Lokasi", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        if (_lokasiList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text("Belum ada data lokasi", style: TextStyle(color: Colors.grey))),
          )
        else
          ..._lokasiList.map((lokasi) => _lokasiListItem(lokasi)),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSummaryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _summaryCard("Total lokasi", "$_totalLokasi", Colors.black87),
        _summaryCard("Aktif", "$_totalAktif", const Color(0xFF5D9C2E)),
        _summaryCard("Nonaktif", "$_totalNonaktif", Colors.grey),
        _summaryCard("Tidak sehat", "$_totalTidakSehat lokasi", const Color(0xFFD85A30)),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Cari lokasi...",
                prefixIcon: Icon(Icons.search, size: 18),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => _searchQuery = v,
              onSubmitted: (_) => _loadData(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: DropdownButton<String>(
            value: _filterStatus,
            underline: const SizedBox(),
            items: ["Semua Status", "Aktif", "Nonaktif"]
                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) {
              setState(() => _filterStatus = v!);
              _loadData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPickModeBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tappedPoint == null
                  ? "Mode pilih lokasi aktif -- ketuk peta untuk menentukan titik"
                  : "Titik dipilih: ${_tappedPoint!.latitude.toStringAsFixed(4)}, "
                  "${_tappedPoint!.longitude.toStringAsFixed(4)}",
              style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 280,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(-6.4, 107.0),
            initialZoom: 8,
            onTap: (tapPos, latlng) => _onTapMap(latlng),
          ),
          children: [
            TileLayer(
              urlTemplate: "https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png",
              subdomains: const ['a', 'b', 'c'],
            ),
            MarkerLayer(
              markers: [
                ..._lokasiList.map((lokasi) {
                  return Marker(
                    point: lokasi.koordinat,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _onMarkerTap(lokasi),
                      child: Container(
                        decoration: BoxDecoration(
                          color: lokasi.warna,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "${lokasi.aqi}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                        ),
                      ),
                    ),
                  );
                }),
                if (_pickMode && _tappedPoint != null)
                  Marker(
                    point: _tappedPoint!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }

  Widget _lokasiListItem(LokasiData lokasi) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: InkWell(
        onTap: () => _onMarkerTap(lokasi),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: lokasi.warna, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                "${lokasi.aqi}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lokasi.nama, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(lokasi.kategori, style: TextStyle(color: lokasi.warna, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: lokasi.aktif ? const Color(0xFFEAF3DE) : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    lokasi.aktif ? "Aktif" : "Nonaktif",
                    style: TextStyle(fontSize: 11, color: lokasi.aktif ? const Color(0xFF27500A) : Colors.grey),
                  ),
                ),
                const SizedBox(height: 4),
                Text(lokasi.updateTerakhir, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}