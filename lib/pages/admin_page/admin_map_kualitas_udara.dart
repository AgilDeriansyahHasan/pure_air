import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../services/users.dart';

// =========================================================
// HELPER TANGGAL
// =========================================================
String formatTanggal(String? raw) {
  if (raw == null || raw.isEmpty) return "-";
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  const bulan = ["", "Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
    "Jul", "Agu", "Sep", "Okt", "Nov", "Des"];
  return "${dt.day} ${bulan[dt.month]} ${dt.year}, "
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
}

// =========================================================
// MODEL
// =========================================================
class LokasiData {
  final int id;
  String nama;
  LatLng koordinat;
  bool aktif;
  int aqi;
  String updateTerakhir;
  String? dibuatPada;
  double? pm25, pm10, co, no2, so2, o3;

  LokasiData({
    required this.id,
    required this.nama,
    required this.koordinat,
    required this.aktif,
    required this.aqi,
    required this.updateTerakhir,
    this.dibuatPada,
    this.pm25, this.pm10, this.co, this.no2, this.so2, this.o3,
  });

  factory LokasiData.fromJson(Map<String, dynamic> json) {
    double? toD(dynamic v) => v == null ? null : double.tryParse(v.toString());
    return LokasiData(
      id: int.parse(json["id"].toString()),
      nama: json["nama"] ?? "",
      koordinat: LatLng(
        double.parse(json["latitude"].toString()),
        double.parse(json["longitude"].toString()),
      ),
      aktif: (json["status"] ?? "aktif") == "aktif",
      aqi: json["aqi"] != null ? int.tryParse(json["aqi"].toString()) ?? 0 : 0,
      updateTerakhir: json["update_terakhir"]?.toString() ?? "-",
      dibuatPada: json["created_at"]?.toString(),
      pm25: toD(json["pm25"]), pm10: toD(json["pm10"]),
      co: toD(json["co"]),     no2: toD(json["no2"]),
      so2: toD(json["so2"]),   o3: toD(json["o3"]),
    );
  }

  bool get punyaParameter =>
      pm25 != null || pm10 != null || co != null ||
          no2 != null || so2 != null || o3 != null;

  // Warna netral khusus lokasi NONAKTIF -- dipakai di marker peta,
  // badge kategori, dan lingkaran AQI, supaya lokasi nonaktif langsung
  // kelihatan "mati" tanpa perlu baca teks "Nonaktif"-nya dulu.
  static const Color _abuTua  = Color(0xFF9CA3AF);
  static const Color _abuMuda = Color(0xFFF1F5F9);

  String get kategori {
    if (aqi <= 50)  return "Baik";
    if (aqi <= 100) return "Sedang";
    if (aqi <= 150) return "Tidak Sehat (SG)";
    if (aqi <= 200) return "Tidak Sehat";
    return "Sangat Tidak Sehat";
  }

  // Label yang ditampilkan di badge kategori. Kalau lokasinya nonaktif,
  // tampilkan "Tidak dipantau" alih-alih kategori AQI -- soalnya AQI
  // lama itu sudah tidak relevan lagi selama lokasi nonaktif.
  String get kategoriTampilan => aktif ? kategori : "Tidak dipantau";

  Color get warna {
    if (!aktif) return _abuTua;
    if (aqi <= 50)  return const Color(0xFF16A34A);
    if (aqi <= 100) return const Color(0xFFCA8A04);
    if (aqi <= 150) return const Color(0xFFEA580C);
    if (aqi <= 200) return const Color(0xFFDC2626);
    return const Color(0xFF7C3AED);
  }

  Color get warnaMuda {
    if (!aktif) return _abuMuda;
    if (aqi <= 50)  return const Color(0xFFDCFCE7);
    if (aqi <= 100) return const Color(0xFFFEF9C3);
    if (aqi <= 150) return const Color(0xFFFFEDD5);
    if (aqi <= 200) return const Color(0xFFFEE2E2);
    return const Color(0xFFEDE9FE);
  }
}

// =========================================================
// SERVICE
// =========================================================
class LokasiService {
  static Future<List<LokasiData>> list({String search = "", String status = ""}) async {
    final res = await http.post(Uri.parse("${ApiService.baseUrl}/admin/lokasi.php"),
        body: {"action": "list", "search": search, "status": status});
    final body = jsonDecode(res.body);
    if (body["status"] == true) {
      return (body["data"] as List).map((e) => LokasiData.fromJson(e)).toList();
    }
    throw Exception(body["message"] ?? "Gagal mengambil data lokasi");
  }

  static Future<void> tambah({required String nama, required double lat, required double lon, String status = "aktif"}) async {
    final res = await http.post(Uri.parse("${ApiService.baseUrl}/admin/lokasi.php"),
        body: {"action": "tambah", "nama": nama, "latitude": lat.toString(), "longitude": lon.toString(), "status": status});
    final body = jsonDecode(res.body);
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal menambah lokasi");
  }

  static Future<void> update({required int id, required String nama, required double lat, required double lon, String status = "aktif"}) async {
    final res = await http.post(Uri.parse("${ApiService.baseUrl}/admin/lokasi.php"),
        body: {"action": "update", "id": id.toString(), "nama": nama, "latitude": lat.toString(), "longitude": lon.toString(), "status": status});
    final body = jsonDecode(res.body);
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal memperbarui lokasi");
  }

  static Future<void> hapus(int id) async {
    final res = await http.post(Uri.parse("${ApiService.baseUrl}/admin/lokasi.php"),
        body: {"action": "hapus", "id": id.toString()});
    final body = jsonDecode(res.body);
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal menghapus lokasi");
  }

  static Future<List<KandidatLokasi>> cariKoordinat(String nama) async {
    final res = await http.post(Uri.parse("${ApiService.baseUrl}/admin/lokasi.php"),
        body: {"action": "cari_koordinat", "nama": nama});
    final body = jsonDecode(res.body);
    if (body["status"] != true) throw Exception(body["message"] ?? "Lokasi tidak ditemukan");
    return (body["data"] as List).map((e) => KandidatLokasi.fromJson(e)).toList();
  }

  static Future<HasilAmbilData> ambilDataKualitas(int idLokasi) async {
    final res = await http.post(Uri.parse("${ApiService.baseUrl}/admin/lokasi.php"),
        body: {"action": "ambil_data", "id": idLokasi.toString()});
    final body = jsonDecode(res.body);
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal mengambil data");
    return HasilAmbilData.fromJson(body);
  }
}

class HasilAmbilData {
  final int aqi;
  final double? pm25, pm10, co, no2, so2, o3;
  final String message;

  HasilAmbilData({required this.aqi, this.pm25, this.pm10, this.co, this.no2, this.so2, this.o3, required this.message});

  factory HasilAmbilData.fromJson(Map<String, dynamic> json) {
    final data = json["data"] ?? {};
    double? toD(dynamic v) => v == null ? null : double.tryParse(v.toString());
    return HasilAmbilData(
      aqi: int.tryParse(data["aqi"].toString()) ?? 0,
      pm25: toD(data["pm25"]), pm10: toD(data["pm10"]),
      co: toD(data["co"]),     no2: toD(data["no2"]),
      so2: toD(data["so2"]),   o3: toD(data["o3"]),
      message: json["message"]?.toString() ?? "",
    );
  }
}

class KandidatLokasi {
  final String nama, label;
  final double latitude, longitude;

  KandidatLokasi({required this.nama, required this.label, required this.latitude, required this.longitude});

  factory KandidatLokasi.fromJson(Map<String, dynamic> json) => KandidatLokasi(
    nama: json["nama"]?.toString() ?? "",
    label: json["label"]?.toString() ?? "",
    latitude: double.tryParse(json["latitude"].toString()) ?? 0,
    longitude: double.tryParse(json["longitude"].toString()) ?? 0,
  );
}

// =========================================================
// HALAMAN UTAMA
// =========================================================
class MapAirQualityPage extends StatefulWidget {
  const MapAirQualityPage({super.key});

  @override
  State<MapAirQualityPage> createState() => _MapAirQualityPageState();
}

class _MapAirQualityPageState extends State<MapAirQualityPage> {
  static const _blue = Color(0xFF2563EB);

  final MapController _mapController = MapController();
  final _searchCtrl = TextEditingController();

  List<LokasiData> _lokasiList = [];
  bool _loading = true;
  String? _error;
  String _filterStatus = "Semua";
  LatLng? _tappedPoint;
  bool _pickMode = false;
  LatLng? _previewPoint;
  bool _mengekspor = false;
  final Set<int> _sedangAmbilData = {};

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

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final statusParam = _filterStatus == "Aktif" ? "aktif" : _filterStatus == "Nonaktif" ? "nonaktif" : "";
      final data = await LokasiService.list(search: _searchCtrl.text, status: statusParam);
      setState(() => _lokasiList = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  int get _totalLokasi   => _lokasiList.length;
  int get _totalAktif    => _lokasiList.where((l) => l.aktif).length;
  int get _totalNonaktif => _lokasiList.where((l) => !l.aktif).length;
  int get _totalTidakSehat => _lokasiList.where((l) => l.aqi > 100).length;

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _ambilDataKualitas(LokasiData lokasi) async {
    if (_sedangAmbilData.contains(lokasi.id)) return;
    setState(() => _sedangAmbilData.add(lokasi.id));
    try {
      // 1. Panggil API
      final hasil = await LokasiService.ambilDataKualitas(lokasi.id);

      // 2. Refresh UI atau reload marker/peta
      setState(() {});

      // 3. Tampilkan notifikasi SUKSES saja (pakai null check agar tidak error)
      _showSnack("${hasil?.message ?? 'Data berhasil diperbarui'} (AQI ${hasil?.aqi ?? '-'})");

    } catch (e) {
      // 4. BUNGKUS / HAPUS _showSnack di sini agar notifikasi error TIDAK MUNCUL
      print("$e");
    }
  }

  Future<void> _kirimKeLaporan() async {
    if (_lokasiList.isEmpty || _mengekspor) return;
    setState(() => _mengekspor = true);
    try {
      final ringkasan = "Total $_totalLokasi lokasi (Aktif: $_totalAktif, Nonaktif: $_totalNonaktif, Tidak sehat: $_totalTidakSehat)";
      final response = await http.post(Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
          body: {"action": "kirim", "kategori": "lokasi", "ringkasan": ringkasan});
      if (!mounted) return;
      final data = jsonDecode(response.body);
      _showSnack(data['status'] == "success" ? "Berhasil dikirim ke laporan" : (data['message'] ?? "Gagal"));
    } catch (e) {
      if (!mounted) return;
      _showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => _mengekspor = false);
    }
  }

  // ===================== DETAIL SHEET =====================
  void _showDetailSheet(LokasiData lokasi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final mengambil = _sedangAmbilData.contains(lokasi.id);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (_, scrollCtrl) => SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(color: lokasi.warnaMuda, shape: BoxShape.circle),
                        child: Center(
                          child: Text("${lokasi.aqi}",
                              style: TextStyle(color: lokasi.warna, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lokasi.nama, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: lokasi.warnaMuda,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(lokasi.kategoriTampilan,
                                      style: TextStyle(color: lokasi.warna, fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: lokasi.aktif ? const Color(0xFFDCFCE7) : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(lokasi.aktif ? "Aktif" : "Nonaktif",
                                      style: TextStyle(
                                          color: lokasi.aktif ? const Color(0xFF16A34A) : Colors.grey.shade600,
                                          fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  // Info rows
                  _infoTile(Icons.location_on_outlined, "Koordinat",
                      "${lokasi.koordinat.latitude.toStringAsFixed(4)}, ${lokasi.koordinat.longitude.toStringAsFixed(4)}"),
                  _infoTile(Icons.access_time, "Terakhir update", lokasi.updateTerakhir),
                  _infoTile(Icons.calendar_today_outlined, "Ditambahkan", formatTanggal(lokasi.dibuatPada)),

                  // Parameter polutan
                  if (lokasi.punyaParameter) ...[
                    const SizedBox(height: 20),
                    const Text("Parameter Polutan",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
                    const SizedBox(height: 10),
                    _parameterGrid(lokasi),
                  ] else ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Belum ada data parameter. Terapkan data dari halaman Validasi Data terlebih dahulu.",
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Tombol ambil data
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: mengambil ? null : () async {
                        setSheet(() {});
                        await _ambilDataKualitas(lokasi);
                        setSheet(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: mengambil
                          ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_download_outlined, size: 18),
                      label: Text(mengambil ? "Mengambil data..." : "Ambil Data Kualitas Udara",
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showLokasiForm(existing: lokasi);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Color(0xFFFEE2E2)),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text("Hapus"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _parameterGrid(LokasiData lokasi) {
    final items = [
      {"label": "PM2.5", "unit": "µg/m³", "value": lokasi.pm25?.toStringAsFixed(1)},
      {"label": "PM10",  "unit": "µg/m³", "value": lokasi.pm10?.toStringAsFixed(1)},
      {"label": "CO",    "unit": "ppm",   "value": lokasi.co?.toStringAsFixed(2)},
      {"label": "NO₂",   "unit": "ppb",   "value": lokasi.no2?.toStringAsFixed(1)},
      {"label": "SO₂",   "unit": "ppb",   "value": lokasi.so2?.toStringAsFixed(1)},
      {"label": "O₃",    "unit": "ppb",   "value": lokasi.o3?.toStringAsFixed(1)},
    ];
    return GridView.count(
      crossAxisCount: 3, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.5,
      children: items.map((item) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(item["label"]!, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              item["value"] != null ? item["value"]! : "-",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
            if (item["value"] != null)
              Text(item["unit"]!, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      )).toList(),
    );
  }

  void _confirmDelete(LokasiData lokasi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Lokasi?"),
        content: Text("\"${lokasi.nama}\" akan dihapus permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try { await LokasiService.hapus(lokasi.id); _loadData(); }
              catch (e) { _showSnack(e.toString()); }
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  // ===================== FORM TAMBAH/EDIT =====================
  void _showTambahPilihan() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Tambah Lokasi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Pilih cara menentukan titik lokasi",
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            ),
            const SizedBox(height: 20),
            _pilihanCard(Icons.search_rounded, "Cari nama lokasi",
                "Ketik nama tempat, koordinat dicari otomatis", () {
                  Navigator.pop(ctx);
                  _showLokasiForm(mode: "cari");
                }),
            const SizedBox(height: 10),
            _pilihanCard(Icons.touch_app_rounded, "Pilih titik di peta",
                "Ketuk langsung titik lokasi pada peta", () {
                  Navigator.pop(ctx);
                  setState(() { _tappedPoint = null; _pickMode = true; });
                  _showSnack("Ketuk titik di peta untuk memilih koordinat");
                }),
          ],
        ),
      ),
    );
  }

  Widget _pilihanCard(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _blue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  void _showLokasiForm({LokasiData? existing, String mode = "peta"}) {
    final isEdit = existing != null;
    final effectiveMode = isEdit ? "peta" : mode;
    final namaCtrl = TextEditingController(text: existing?.nama ?? "");
    final latCtrl  = TextEditingController(text: existing?.koordinat.latitude.toString() ?? _tappedPoint?.latitude.toString() ?? "");
    final lonCtrl  = TextEditingController(text: existing?.koordinat.longitude.toString() ?? _tappedPoint?.longitude.toString() ?? "");
    bool aktif = existing?.aktif ?? true;
    bool saving = false;
    bool searching = false;
    String? searchError;
    List<KandidatLokasi> kandidatList = [];
    KandidatLokasi? kandidatTerpilih;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> doSearch() async {
            if (namaCtrl.text.trim().isEmpty) { setSheet(() => searchError = "Ketik nama lokasi dulu"); return; }
            setSheet(() { searching = true; searchError = null; kandidatList = []; kandidatTerpilih = null; });
            try {
              final hasil = await LokasiService.cariKoordinat(namaCtrl.text.trim());
              setSheet(() { kandidatList = hasil; searching = false; });
              if (hasil.length == 1) {
                final k = hasil.first;
                setSheet(() { kandidatTerpilih = k; namaCtrl.text = k.nama; latCtrl.text = k.latitude.toString(); lonCtrl.text = k.longitude.toString(); });
                _mapController.move(LatLng(k.latitude, k.longitude), 13);
                setState(() => _previewPoint = LatLng(k.latitude, k.longitude));
              }
            } catch (e) {
              setSheet(() { searchError = e.toString().replaceFirst("Exception: ", ""); searching = false; });
            }
          }

          return Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 16),
                  Text(
                    isEdit ? "Edit Lokasi" : effectiveMode == "cari" ? "Tambah — Cari Nama" : "Tambah — Pilih di Peta",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _formField("Nama Lokasi", namaCtrl),

                  if (effectiveMode == "cari") ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: searching ? null : doSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: searching
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search, size: 16),
                        label: Text(searching ? "Mencari..." : "Cari Koordinat"),
                      ),
                    ),
                    if (searchError != null) ...[
                      const SizedBox(height: 8),
                      Text(searchError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                    ],
                    if (kandidatList.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text("Pilih lokasi:", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ...kandidatList.map((k) {
                        final terpilih = kandidatTerpilih == k;
                        return GestureDetector(
                          onTap: () => setSheet(() {
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
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: terpilih ? _blue : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Icon(terpilih ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    size: 16, color: terpilih ? _blue : Colors.grey),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(k.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      Text("${k.latitude.toStringAsFixed(4)}, ${k.longitude.toStringAsFixed(4)}",
                                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ] else ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _formField("Latitude", latCtrl, keyboardType: TextInputType.number)),
                        const SizedBox(width: 10),
                        Expanded(child: _formField("Longitude", lonCtrl, keyboardType: TextInputType.number)),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Text("Status", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _statusChip("Aktif", aktif, () => setSheet(() => aktif = true)),
                      const SizedBox(width: 8),
                      _statusChip("Nonaktif", !aktif, () => setSheet(() => aktif = false)),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () { _tappedPoint = null; Navigator.pop(ctx); },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: const Text("Batal"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: saving ? null : () async {
                            final lat = double.tryParse(latCtrl.text);
                            final lon = double.tryParse(lonCtrl.text);
                            if (namaCtrl.text.trim().isEmpty || lat == null || lon == null) {
                              _showSnack(effectiveMode == "cari" ? "Pilih lokasi dari hasil pencarian dulu" : "Lengkapi semua data");
                              return;
                            }
                            setSheet(() => saving = true);
                            try {
                              if (existing != null) {
                                await LokasiService.update(id: existing.id, nama: namaCtrl.text.trim(), lat: lat, lon: lon, status: aktif ? "aktif" : "nonaktif");
                              } else {
                                await LokasiService.tambah(nama: namaCtrl.text.trim(), lat: lat, lon: lon, status: aktif ? "aktif" : "nonaktif");
                              }
                              _tappedPoint = null; _pickMode = false;
                              setState(() => _previewPoint = null);
                              if (mounted) Navigator.pop(ctx);
                              _loadData();
                            } catch (e) {
                              _showSnack(e.toString());
                              setSheet(() => saving = false);
                            }
                          },
                          child: saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text("Simpan", style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => setState(() => _pickMode = false));
  }

  Widget _formField(String label, TextEditingController ctrl, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _blue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _blue : const Color(0xFFE2E8F0)),
        ),
        child: Text(label,
            style: TextStyle(color: selected ? Colors.white : Colors.grey, fontWeight: FontWeight.w500, fontSize: 13)),
      ),
    );
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Peta Lokasi", style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        actions: [
          IconButton(
            onPressed: _mengekspor ? null : _kirimKeLaporan,
            tooltip: "Export ke Laporan",
            icon: _mengekspor
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded),
          ),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _blue,
        elevation: 2,
        onPressed: () {
          if (_pickMode) {
            if (_tappedPoint != null) _showLokasiForm(mode: "peta");
            else _showSnack("Ketuk dulu titiknya di peta");
          } else {
            _showTambahPilihan();
          }
        },
        icon: Icon(_pickMode ? Icons.check_rounded : Icons.add_rounded, color: Colors.white),
        label: Text(_pickMode ? "Pakai titik ini" : "Tambah Lokasi",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(onRefresh: _loadData, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text("Coba lagi"),
              style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryGrid(),
        const SizedBox(height: 14),
        _searchAndFilter(),
        const SizedBox(height: 14),
        if (_pickMode) _pickModeBanner(),
        _buildMap(),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text("Daftar Lokasi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text("${_lokasiList.length} lokasi", style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 10),
        if (_lokasiList.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.location_off_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text("Belum ada data lokasi", style: TextStyle(color: Colors.grey.shade400)),
                ],
              ),
            ),
          )
        else
          ..._lokasiList.map((l) => _lokasiCard(l)),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _summaryGrid() {
    return Row(
      children: [
        _summaryTile("Total", "$_totalLokasi", Icons.place_rounded, Colors.black87, const Color(0xFFF1F5F9)),
        const SizedBox(width: 10),
        _summaryTile("Aktif", "$_totalAktif", Icons.check_circle_rounded, const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
        const SizedBox(width: 10),
        _summaryTile("Nonaktif", "$_totalNonaktif", Icons.cancel_rounded, Colors.grey, const Color(0xFFF1F5F9)),
        const SizedBox(width: 10),
        _summaryTile("Tidak Sehat", "$_totalTidakSehat", Icons.warning_rounded, const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
      ],
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _searchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: "Cari lokasi...",
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => _loadData(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterStatus,
              items: ["Semua", "Aktif", "Nonaktif"]
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) { setState(() => _filterStatus = v!); _loadData(); },
            ),
          ),
        ),
      ],
    );
  }

  Widget _pickModeBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_rounded, size: 16, color: _blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tappedPoint == null
                  ? "Ketuk titik di peta untuk memilih koordinat"
                  : "Dipilih: ${_tappedPoint!.latitude.toStringAsFixed(4)}, ${_tappedPoint!.longitude.toStringAsFixed(4)}",
              style: const TextStyle(fontSize: 12, color: _blue),
            ),
          ),
          TextButton(
            onPressed: () => setState(() { _pickMode = false; _tappedPoint = null; }),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
            child: const Text("Batal", style: TextStyle(fontSize: 12, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 260,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(-6.4, 107.0),
            initialZoom: 8,
            onTap: (_, latlng) {
              if (!_pickMode) return;
              setState(() => _tappedPoint = latlng);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: "https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png",
              subdomains: const ['a', 'b', 'c'],
            ),
            MarkerLayer(markers: [
              ..._lokasiList.map((l) => Marker(
                point: l.koordinat, width: 44, height: 44,
                child: GestureDetector(
                  onTap: () { _mapController.move(l.koordinat, 12); _showDetailSheet(l); },
                  child: Container(
                    decoration: BoxDecoration(
                      color: l.warna, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    alignment: Alignment.center,
                    child: Text("${l.aqi}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
                ),
              )),
              if (_tappedPoint != null)
                Marker(point: _tappedPoint!, width: 44, height: 44,
                    child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 44)),
              if (_previewPoint != null)
                Marker(point: _previewPoint!, width: 44, height: 44,
                    child: const Icon(Icons.location_on_rounded, color: _blue, size: 44)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _lokasiCard(LokasiData lokasi) {
    final mengambil = _sedangAmbilData.contains(lokasi.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Opacity(
        opacity: lokasi.aktif ? 1 : 0.65,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () { _mapController.move(lokasi.koordinat, 12); _showDetailSheet(lokasi); },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: lokasi.warnaMuda, shape: BoxShape.circle),
                    child: Center(
                      child: Text("${lokasi.aqi}",
                          style: TextStyle(color: lokasi.warna, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lokasi.nama,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: lokasi.warnaMuda, borderRadius: BorderRadius.circular(20)),
                              child: Text(lokasi.kategoriTampilan,
                                  style: TextStyle(color: lokasi.warna, fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: lokasi.aktif ? const Color(0xFFDCFCE7) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(lokasi.aktif ? "Aktif" : "Nonaktif",
                                  style: TextStyle(
                                      color: lokasi.aktif ? const Color(0xFF16A34A) : Colors.grey.shade600,
                                      fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: mengambil ? null : () => _ambilDataKualitas(lokasi),
                    tooltip: "Ambil Data",
                    icon: mengambil
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_download_outlined, size: 20, color: _blue),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}