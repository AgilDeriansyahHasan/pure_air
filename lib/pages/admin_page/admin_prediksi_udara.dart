import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/users.dart';

// =========================================================
// WARNA TEMA (dark) -- konsisten dengan history.dart
// =========================================================
class _Tema {
  static const bg         = Color(0xFF17171B);
  static const card       = Color(0xFF222226);
  static const cardBorder = Color(0xFF2E2E33);
  static const teksAbu    = Color(0xFF9A9AA2);
  static const teksPutih  = Color(0xFFF2F2F3);
  static const aksen      = Color(0xFFFB7155);
}

// =========================================================
// Daftar slot jam prediksi (sinkron dgn $JAM_SLOT_LIST di PHP)
// =========================================================
const List<int> kJamSlotList = [8, 12, 17, 20, 22];

// =========================================================
// Daftar target yang dilatih/diprediksi (sinkron dgn PHP)
// =========================================================
const List<String> kDaftarTarget = ["aqi", "pm25", "pm10", "co", "no2", "so2", "o3"];

const Map<String, String> kLabelTarget = {
  "aqi":  "AQI",
  "pm25": "PM2.5",
  "pm10": "PM10",
  "co":   "CO",
  "no2":  "NO2",
  "so2":  "SO2",
  "o3":   "O3",
};

const Map<String, String> kSatuanTarget = {
  "aqi":  "",
  "pm25": "µg/m³",
  "pm10": "µg/m³",
  "co":   "ppm",
  "no2":  "ppb",
  "so2":  "ppb",
  "o3":   "ppb",
};

// =========================================================
// MODEL: info akurasi 1 target dari tabel model_prediksi
// =========================================================
class InfoModelTarget {
  final String target;
  final double mape;
  final double akurasi;
  final int    jumlahDataLatih;
  final String status;
  final DateTime? trainedAt;

  InfoModelTarget({
    required this.target,
    required this.mape,
    required this.akurasi,
    required this.jumlahDataLatih,
    required this.status,
    required this.trainedAt,
  });

  factory InfoModelTarget.fromJson(String target, Map<String, dynamic> j) {
    double d(String k) => double.tryParse((j[k] ?? "0").toString()) ?? 0;
    return InfoModelTarget(
      target: target,
      mape: d("mape"),
      akurasi: d("akurasi"),
      jumlahDataLatih: int.tryParse((j["jumlah_data_latih"] ?? "0").toString()) ?? 0,
      status: (j["status"] ?? "-").toString(),
      trainedAt: DateTime.tryParse((j["trained_at"] ?? "").toString()),
    );
  }
}

// =========================================================
// MODEL: 1 baris hasil prediksi (1 hari) dari monitoring_prediksi
// ATAU dari hasil "jalankan_prediksi" (field sama, beda sumber)
// =========================================================
class PrediksiHarian {
  final DateTime tanggal;
  final double aqi, pm25, pm10, co, no2, so2, o3;
  final double confidence;

  PrediksiHarian({
    required this.tanggal,
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.co,
    required this.no2,
    required this.so2,
    required this.o3,
    required this.confidence,
  });

  factory PrediksiHarian.fromJson(Map<String, dynamic> j) {
    double d(String k) => double.tryParse((j[k] ?? "0").toString()) ?? 0;
    return PrediksiHarian(
      tanggal:    DateTime.tryParse((j["tanggal"] ?? "").toString()) ?? DateTime.now(),
      aqi:        d("aqi_prediksi"),
      pm25:       d("pm25_prediksi"),
      pm10:       d("pm10_prediksi"),
      co:         d("co_prediksi"),
      no2:        d("no2_prediksi"),
      so2:        d("so2_prediksi"),
      o3:         d("o3_prediksi"),
      confidence: d("confidence"),
    );
  }

  double nilai(String target) {
    switch (target) {
      case "aqi":  return aqi;
      case "pm25": return pm25;
      case "pm10": return pm10;
      case "co":   return co;
      case "no2":  return no2;
      case "so2":  return so2;
      case "o3":   return o3;
      default:     return 0;
    }
  }

  factory PrediksiHarian.rataRataSlot(List<PrediksiHarian> slotSatuHari) {
    final n = slotSatuHari.length;
    double rata(double Function(PrediksiHarian) ambil) =>
        slotSatuHari.map(ambil).reduce((a, b) => a + b) / n;

    final tanggalAcuan = slotSatuHari.first.tanggal;
    return PrediksiHarian(
      tanggal:    DateTime(tanggalAcuan.year, tanggalAcuan.month, tanggalAcuan.day),
      aqi:        rata((e) => e.aqi),
      pm25:       rata((e) => e.pm25),
      pm10:       rata((e) => e.pm10),
      co:         rata((e) => e.co),
      no2:        rata((e) => e.no2),
      so2:        rata((e) => e.so2),
      o3:         rata((e) => e.o3),
      confidence: rata((e) => e.confidence),
    );
  }

  static List<PrediksiHarian> kelompokkanPerHari(List<PrediksiHarian> slotSemua) {
    final Map<String, List<PrediksiHarian>> grup = {};
    for (final p in slotSemua) {
      final key = "${p.tanggal.year}-${p.tanggal.month}-${p.tanggal.day}";
      grup.putIfAbsent(key, () => []).add(p);
    }
    final hasil = grup.values.map((slot) => PrediksiHarian.rataRataSlot(slot)).toList();
    hasil.sort((a, b) => a.tanggal.compareTo(b.tanggal));
    return hasil;
  }
}

// =========================================================
// KATEGORI AQI
// =========================================================
class AqiKategori {
  final String label;
  final Color  warna;
  AqiKategori(this.label, this.warna);
}

AqiKategori kategoriDariAqi(double aqi) {
  if (aqi <= 50)  return AqiKategori("Baik",               const Color(0xFF4ADE80));
  if (aqi <= 100) return AqiKategori("Sedang",             const Color(0xFFFACC15));
  if (aqi <= 150) return AqiKategori("Tidak sehat (SG)",   const Color(0xFFFB923C));
  if (aqi <= 200) return AqiKategori("Tidak sehat",        const Color(0xFFF87171));
  if (aqi <= 300) return AqiKategori("Sangat tidak sehat", const Color(0xFFC084FC));
  return             AqiKategori("Berbahaya",               const Color(0xFF991B1B));
}

// =========================================================
// SERVICE
// =========================================================
class PrediksiKualitasUdaraService {
  static const String _endpoint = "${ApiService.baseUrl}/admin/prediksi.php";

  static Future<Map<String, InfoModelTarget>> latihModel(String namaLokasi) async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action":      "latih_model",
      "nama_lokasi": namaLokasi,
    }).timeout(const Duration(seconds: 60));

    final body = jsonDecode(res.body);
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal melatih model");

    final dynamic ringkasanRaw = body["data"]?["ringkasan"];
    final Map ringkasan = (ringkasanRaw is Map) ? ringkasanRaw : {};
    final Map<String, InfoModelTarget> hasil = {};
    ringkasan.forEach((target, v) {
      hasil[target] = InfoModelTarget(
        target: target,
        mape: (v["mape"] is num) ? (v["mape"] as num).toDouble() : 0,
        akurasi: (v["akurasi"] is num) ? (v["akurasi"] as num).toDouble() : 0,
        jumlahDataLatih: 0,
        status: "aktif",
        trainedAt: DateTime.tryParse((body["data"]?["trained_at"] ?? "").toString()),
      );
    });
    return hasil;
  }

  static Future<List<PrediksiHarian>> jalankanPrediksi(
      String namaLokasi, {
        int jumlahHari = 7,
      }) async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action":      "jalankan_prediksi",
      "nama_lokasi": namaLokasi,
      "jumlah_hari": "$jumlahHari",
    }).timeout(const Duration(seconds: 60));

    final body = jsonDecode(res.body);
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal menjalankan prediksi");

    final List data = body["data"] ?? [];
    return data.map((e) => PrediksiHarian.fromJson(e)).toList()
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
  }

  static Future<List<String>> getDaftarLokasi() async {
    final res = await http
        .post(Uri.parse(_endpoint), body: {"action": "list"})
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body);
    if (body["status"] != true) return [];

    final List data = body["data"] ?? [];
    final nama = data
        .map((e) => (e["nama_lokasi"] ?? "").toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    nama.sort();
    return nama;
  }

  static Future<({List<PrediksiHarian> data, Map<String, InfoModelTarget> model})> getPrediksi(
      String namaLokasi,
      ) async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action":      "get_prediksi",
      "nama_lokasi": namaLokasi,
    }).timeout(const Duration(seconds: 20));

    final body = jsonDecode(res.body);
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal mengambil prediksi");

    final dynamic modelJsonRaw = body["model"];
    final Map modelJson = (modelJsonRaw is Map) ? modelJsonRaw : {};
    final Map<String, InfoModelTarget> model = {};
    modelJson.forEach((target, v) {
      model[target] = InfoModelTarget.fromJson(target, Map<String, dynamic>.from(v));
    });

    final List data = body["data"] ?? [];
    final list = data.map((e) => PrediksiHarian.fromJson(e)).toList()
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));

    return (data: list, model: model);
  }
}

// =========================================================
// HALAMAN ADMIN: PREDIKSI KUALITAS UDARA
// =========================================================
class PrediksiKualitasUdaraPage extends StatefulWidget {
  final String namaLokasi;
  const PrediksiKualitasUdaraPage({super.key, this.namaLokasi = "Pilih Lokasi"});

  @override
  State<PrediksiKualitasUdaraPage> createState() => _PrediksiKualitasUdaraPageState();
}

class _PrediksiKualitasUdaraPageState extends State<PrediksiKualitasUdaraPage> {
  late String                    _lokasiAktif = widget.namaLokasi;
  List<String>                   _daftarLokasi = [];
  List<PrediksiHarian>           _prediksi = [];
  List<PrediksiHarian>           _prediksiHarian = [];
  Map<String, InfoModelTarget>   _model    = {};
  int?                            _hariDipilih;
  int?                            _hariDetailTerbuka;
  final Map<int, int>             _jamDipilihPerHari = {};

  String _parameterDipilih = "aqi";

  bool _loading   = true;
  bool _melatih    = false;
  bool _menjalankan = false;
  bool _mengekspor = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muatDaftarLokasi();
    _muatData();
  }

  Future<void> _muatDaftarLokasi() async {
    try {
      final daftar = await PrediksiKualitasUdaraService.getDaftarLokasi();
      if (!mounted) return;
      setState(() => _daftarLokasi = daftar);
    } catch (_) {}
  }

  void _pilihLokasi() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _Tema.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final daftar = _daftarLokasi.isNotEmpty ? _daftarLokasi : [_lokasiAktif];
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: daftar.map((nama) => ListTile(
            leading: const Icon(Icons.location_on_outlined, color: _Tema.teksAbu),
            title: Text(nama, style: const TextStyle(color: _Tema.teksPutih)),
            trailing: nama == _lokasiAktif
                ? const Icon(Icons.check, color: _Tema.aksen)
                : null,
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _lokasiAktif = nama);
              _muatData();
            },
          )).toList(),
        );
      },
    );
  }

  Future<void> _muatData() async {
    if (_lokasiAktif == "Pilih Lokasi") {
      setState(() { _loading = false; _prediksi = []; _prediksiHarian = []; _model = {}; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final hasil = await PrediksiKualitasUdaraService.getPrediksi(_lokasiAktif);
      if (!mounted) return;
      setState(() {
        _prediksi       = hasil.data;
        _prediksiHarian = PrediksiHarian.kelompokkanPerHari(hasil.data);
        _model       = hasil.model;
        _hariDipilih = null;
        _hariDetailTerbuka = null;
        _jamDipilihPerHari.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _latihUlang() async {
    if (_melatih) return;
    if (_lokasiAktif == "Pilih Lokasi") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih lokasi terlebih dahulu")),
      );
      return;
    }
    setState(() => _melatih = true);
    try {
      final model = await PrediksiKualitasUdaraService.latihModel(_lokasiAktif);
      if (!mounted) return;
      setState(() => _model = model);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Model Decision Tree berhasil dilatih ulang (7 parameter)")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _melatih = false);
    }
  }

  Future<void> _jalankan() async {
    if (_menjalankan) return;
    if (_lokasiAktif == "Pilih Lokasi") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih lokasi terlebih dahulu")),
      );
      return;
    }
    setState(() => _menjalankan = true);
    try {
      final hasil = await PrediksiKualitasUdaraService.jalankanPrediksi(_lokasiAktif, jumlahHari: 7);
      if (!mounted) return;
      setState(() {
        _prediksi       = hasil;
        _prediksiHarian = PrediksiHarian.kelompokkanPerHari(hasil);
        _hariDipilih = null; _hariDetailTerbuka = null; _jamDipilihPerHari.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Prediksi 7 hari berhasil dijalankan")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _menjalankan = false);
    }
  }

  /// Tombol "Export" -> kirim kategori "prediksi" ke laporan, khusus
  /// untuk lokasi yang sedang aktif. Polanya sama dengan "Export ke
  /// Laporan" di KualitasUdaraDashboardPage: ringkasan diisi nama
  /// lokasi, dipakai lagi sebagai kunci saat ambil detail nanti.
  Future<void> _kirimKeLaporan() async {
    if (_lokasiAktif == "Pilih Lokasi") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih lokasi terlebih dahulu")),
      );
      return;
    }
    if (_prediksiHarian.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Belum ada hasil prediksi untuk lokasi ini")),
      );
      return;
    }
    if (_mengekspor) return;

    setState(() => _mengekspor = true);
    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
        body: {
          "action": "kirim",
          "kategori": "prediksi",
          "ringkasan": _lokasiAktif,
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
                ? "Prediksi ($_lokasiAktif) dikirim ke laporan"
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Tema.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _muatData,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? _buildError()
                    : _buildKonten(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(children: [
        InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36, height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE9E9EC)),
            child: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF222226)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            "Prediksi -- $_lokasiAktif",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _Tema.teksPutih),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }

  Widget _buildError() {
    return ListView(children: [
      Padding(
        padding: const EdgeInsets.only(top: 120, left: 24, right: 24),
        child: Column(children: [
          const Icon(Icons.cloud_off, size: 40, color: _Tema.teksAbu),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _Tema.teksAbu)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _muatData, child: const Text("Coba lagi")),
        ]),
      ),
    ]);
  }

  Widget _buildKonten() {
    return ListView(padding: const EdgeInsets.all(14), children: [
      _buildLokasiBar(),
      const SizedBox(height: 14),
      if (_lokasiAktif == "Pilih Lokasi")
        _buildBelumPilihLokasi()
      else ...[
        _buildAksiCard(),
        const SizedBox(height: 14),
        _buildAkurasiCard(),
        const SizedBox(height: 14),
        if (_prediksiHarian.isEmpty)
          _buildKosong()
        else
          _buildHasilPrediksi(),
      ],
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildLokasiBar() {
    return InkWell(
      onTap: _pilihLokasi,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _Tema.cardBorder),
        ),
        child: Row(children: [
          const Icon(Icons.location_on, size: 16, color: _Tema.teksAbu),
          const SizedBox(width: 8),
          Text(_lokasiAktif,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _Tema.teksPutih)),
          const Spacer(),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: _Tema.teksAbu),
        ]),
      ),
    );
  }

  Widget _buildBelumPilihLokasi() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: const Text(
        "Pilih lokasi terlebih dahulu untuk\nmelihat atau menjalankan prediksi.",
        textAlign: TextAlign.center,
        style: TextStyle(color: _Tema.teksAbu, fontSize: 13),
      ),
    );
  }

  Widget _buildKosong() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: const Text(
        "Belum ada hasil prediksi.\nLatih model lalu jalankan prediksi.",
        textAlign: TextAlign.center,
        style: TextStyle(color: _Tema.teksAbu, fontSize: 13),
      ),
    );
  }

  Widget _buildAksiCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Decision Tree -- Prediksi Kualitas Udara",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _Tema.teksPutih)),
        const SizedBox(height: 4),
        const Text(
          "Latih model memakai histori rata-rata harian, lalu jalankan untuk memproyeksikan 7 hari ke depan.",
          style: TextStyle(fontSize: 11.5, color: _Tema.teksAbu),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _melatih ? null : _latihUlang,
              icon: _melatih
                  ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _Tema.aksen))
                  : const Icon(Icons.model_training, size: 16, color: _Tema.aksen),
              label: Text(_melatih ? "Melatih..." : "Latih ulang"),
              style: OutlinedButton.styleFrom(
                foregroundColor: _Tema.teksPutih,
                side: const BorderSide(color: _Tema.cardBorder),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _menjalankan ? null : _jalankan,
              icon: _menjalankan
                  ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow, size: 18),
              label: Text(_menjalankan ? "Memproses..." : "Jalankan prediksi"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _Tema.aksen,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _mengekspor ? null : _kirimKeLaporan,
            icon: _mengekspor
                ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _Tema.teksPutih),
            )
                : const Icon(Icons.ios_share, size: 16, color: _Tema.teksPutih),
            label: Text(_mengekspor ? "Mengirim..." : "Export ke Laporan"),
            style: OutlinedButton.styleFrom(
              foregroundColor: _Tema.teksPutih,
              side: const BorderSide(color: _Tema.cardBorder),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildAkurasiCard() {
    if (_model.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Tema.cardBorder),
        ),
        child: const Text("Model belum pernah dilatih untuk lokasi ini.",
            style: TextStyle(color: _Tema.teksAbu, fontSize: 12.5)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Akurasi model per parameter",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _Tema.teksPutih)),
        const SizedBox(height: 10),
        ...kDaftarTarget.where((t) => _model.containsKey(t)).map((t) {
          final m = _model[t]!;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 56, child: Text(kLabelTarget[t] ?? t,
                  style: const TextStyle(fontSize: 12, color: _Tema.teksPutih, fontWeight: FontWeight.w500))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (m.akurasi / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: _Tema.bg,
                    valueColor: AlwaysStoppedAnimation(
                      m.akurasi >= 70 ? const Color(0xFF4ADE80)
                          : m.akurasi >= 50 ? const Color(0xFFFACC15)
                          : const Color(0xFFF87171),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 44, child: Text("${m.akurasi.toStringAsFixed(0)}%",
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11.5, color: _Tema.teksAbu))),
            ]),
          );
        }),
        const SizedBox(height: 6),
        Text(
          "Dilatih dari ${_model.values.first.jumlahDataLatih > 0 ? _model.values.first.jumlahDataLatih : "-"} hari data histori"
              "${_model["aqi"]?.trainedAt != null ? " • ${_formatTanggalJam(_model["aqi"]!.trainedAt!)}" : ""}",
          style: const TextStyle(fontSize: 10.5, color: _Tema.teksAbu),
        ),
      ]),
    );
  }

  Widget _buildHasilPrediksi() {
    final indexAktif = _hariDipilih ?? 0;
    final hariAktif  = _prediksiHarian[indexAktif.clamp(0, _prediksiHarian.length - 1)];

    final nilaiAktif = hariAktif.nilai(_parameterDipilih);
    final isAqi      = _parameterDipilih == "aqi";
    final kategori   = isAqi ? kategoriDariAqi(nilaiAktif) : null;

    final nilaiSemua = _prediksiHarian.map((e) => e.nilai(_parameterDipilih)).toList();
    final rataNilai  = nilaiSemua.reduce((a, b) => a + b) / nilaiSemua.length;
    final kategoriRata = isAqi ? kategoriDariAqi(rataNilai) : null;

    final warnaUtama = kategori?.warna ?? _Tema.aksen;
    final warnaRata   = kategoriRata?.warna ?? _Tema.aksen;
    final labelParam  = kLabelTarget[_parameterDipilih] ?? _parameterDipilih;
    final satuanParam = kSatuanTarget[_parameterDipilih] ?? "";

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildPemilihParameter(),
      const SizedBox(height: 12),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Tema.cardBorder),
        ),
        child: Column(children: [
          Text(_formatTanggalLengkap(hariAktif.tanggal),
              style: const TextStyle(fontSize: 12, color: _Tema.teksAbu)),
          const SizedBox(height: 8),
          Text(
            isAqi
                ? nilaiAktif.toStringAsFixed(0)
                : "${nilaiAktif.toStringAsFixed(1)}${satuanParam.isNotEmpty ? ' $satuanParam' : ''}",
            style: TextStyle(fontSize: 38, fontWeight: FontWeight.w700, color: warnaUtama),
          ),
          Text(
            isAqi ? kategori!.label : labelParam,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: warnaUtama),
          ),
          const SizedBox(height: 4),
          Text("Tingkat keyakinan model: ${hariAktif.confidence.toStringAsFixed(0)}%",
              style: const TextStyle(fontSize: 11, color: _Tema.teksAbu)),
        ]),
      ),
      const SizedBox(height: 12),

      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("Grafik proyeksi $labelParam",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _Tema.teksPutih)),
        Text(
          "Rata-rata ${_prediksiHarian.length} hari: ${rataNilai.toStringAsFixed(isAqi ? 0 : 1)}"
              "${isAqi ? ' (${kategoriRata!.label})' : (satuanParam.isNotEmpty ? ' $satuanParam' : '')}",
          style: TextStyle(fontSize: 11, color: warnaRata, fontWeight: FontWeight.w600),
        ),
      ]),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 14, 14, 8),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Tema.cardBorder),
        ),
        child: SizedBox(
          height: 170,
          child: LayoutBuilder(builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _pilihHariTerdekat(d.localPosition, size),
              onPanUpdate: (d) => _pilihHariTerdekat(d.localPosition, size),
              child: CustomPaint(
                painter: _PrediksiChartPainter(_prediksiHarian, _parameterDipilih, indexAktif: indexAktif, rataRata: rataNilai),
                child: Container(),
              ),
            );
          }),
        ),
      ),
      const SizedBox(height: 14),

      _buildCardDetailHari(),
    ]);
  }

  Widget _buildPemilihParameter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: kDaftarTarget.map((t) {
          final aktif = t == _parameterDipilih;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _parameterDipilih = t),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: aktif ? _Tema.aksen : _Tema.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: aktif ? _Tema.aksen : _Tema.cardBorder),
                ),
                child: Text(
                  kLabelTarget[t] ?? t,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: aktif ? Colors.white : _Tema.teksAbu,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCardDetailHari() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.aksen),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Row(children: [
            const Icon(Icons.calendar_month, size: 16, color: _Tema.aksen),
            const SizedBox(width: 8),
            const Expanded(child: Text(
              "Detail per hari",
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _Tema.teksPutih),
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _Tema.aksen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text("${_prediksiHarian.length} hari",
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _Tema.aksen)),
            ),
          ]),
        ),
        Column(
          children: List.generate(_prediksiHarian.length, (i) => _barisHari(i)),
        ),
      ]),
    );
  }

  Widget _barisHari(int index) {
    final p       = _prediksiHarian[index];
    final terbuka = _hariDetailTerbuka == index;
    final k       = kategoriDariAqi(p.aqi);
    final jamAktif = _jamDipilihPerHari[index] ?? kJamSlotList.first;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: _Tema.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Tema.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() {
            _hariDetailTerbuka = terbuka ? null : index;
            _hariDipilih       = index;
            _jamDipilihPerHari.putIfAbsent(index, () => kJamSlotList.first);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              SizedBox(width: 64,
                  child: Text(_formatTanggalSingkat(p.tanggal),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _Tema.teksPutih))),
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: k.warna, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(k.label,
                  style: TextStyle(fontSize: 11.5, color: k.warna, fontWeight: FontWeight.w500))),
              Text("AQI ${p.aqi.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Tema.teksPutih)),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: terbuka ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: const Icon(Icons.expand_more, size: 16, color: _Tema.teksAbu),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          child: terbuka
              ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildPemilihJam(index, jamAktif),
              const SizedBox(height: 10),
              _buildDetailJam(p.tanggal, jamAktif),
            ]),
          )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ]),
    );
  }

  Widget _buildPemilihJam(int hariIndex, int jamAktif) {
    return Row(
      children: kJamSlotList.map((jam) {
        final aktif = jam == jamAktif;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => setState(() => _jamDipilihPerHari[hariIndex] = jam),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: aktif ? _Tema.aksen : _Tema.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: aktif ? _Tema.aksen : _Tema.cardBorder),
                ),
                child: Text(
                  "${jam.toString().padLeft(2, '0')}:00",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: aktif ? Colors.white : _Tema.teksAbu,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailJam(DateTime tanggal, int jam) {
    final slot = _prediksi.firstWhere(
          (e) => e.tanggal.year == tanggal.year &&
          e.tanggal.month == tanggal.month &&
          e.tanggal.day == tanggal.day &&
          e.tanggal.hour == jam,
      orElse: () => PrediksiHarian(
        tanggal: tanggal, aqi: 0, pm25: 0, pm10: 0, co: 0, no2: 0, so2: 0, o3: 0, confidence: 0,
      ),
    );

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: kDaftarTarget
          .where((t) => t != "aqi")
          .map((t) => _kartuParameterKecil(t, slot.nilai(t)))
          .toList(),
    );
  }

  Widget _kartuParameterKecil(String target, double nilai) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(kLabelTarget[target] ?? target,
              style: const TextStyle(fontSize: 11, color: _Tema.teksAbu, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(nilai.toStringAsFixed(1),
              style: const TextStyle(fontSize: 14, color: _Tema.teksPutih, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void _pilihHariTerdekat(Offset pos, Size size) {
    if (_prediksiHarian.isEmpty) return;
    final stepX = _prediksiHarian.length > 1 ? size.width / (_prediksiHarian.length - 1) : size.width;
    final index = (pos.dx / stepX).round().clamp(0, _prediksiHarian.length - 1);
    if (_hariDipilih != index) setState(() => _hariDipilih = index);
  }

  String _formatTanggalLengkap(DateTime t) {
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    return "${t.day} ${b[t.month - 1]} ${t.year}";
  }

  String _formatTanggalSingkat(DateTime t) {
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    return "${t.day} ${b[t.month - 1]}";
  }

  String _formatTanggalJam(DateTime t) {
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    return "${t.day} ${b[t.month - 1]} ${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }
}

// =========================================================
// GRAFIK GARIS PROYEKSI N HARI (untuk parameter terpilih)
// =========================================================
class _PrediksiChartPainter extends CustomPainter {
  final List<PrediksiHarian> data;
  final String target;
  final int? indexAktif;
  final double? rataRata;
  _PrediksiChartPainter(this.data, this.target, {this.indexAktif, this.rataRata});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final nilai = data.map((e) => e.nilai(target)).toList();
    final maxV  = nilai.reduce(math.max);
    final minV  = nilai.reduce(math.min);
    final range = (maxV - minV).clamp(1, double.infinity);

    const paddingBottom = 22.0;
    final chartH = size.height - paddingBottom;
    final stepX  = data.length > 1 ? size.width / (data.length - 1) : size.width;

    final linePaint = Paint()
      ..color = _Tema.aksen
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_Tema.aksen.withOpacity(0.25), _Tema.aksen.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartH));
    final dotPaint = Paint()..color = _Tema.aksen;

    final path = Path(), fillPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = chartH - ((nilai[i] - minV) / range * chartH);
      points.add(Offset(x, y));
      if (i == 0) { path.moveTo(x, y); fillPath.moveTo(x, chartH); fillPath.lineTo(x, y); }
      else { path.lineTo(x, y); fillPath.lineTo(x, y); }
    }
    fillPath.lineTo(points.last.dx, chartH);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);

    if (rataRata != null) {
      final yRata = chartH - ((rataRata! - minV) / range * chartH);
      final rataPaint = Paint()
        ..color = _Tema.teksAbu.withOpacity(0.5)
        ..strokeWidth = 1;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, yRata), Offset(math.min(x + 4, size.width), yRata), rataPaint);
        x += 7;
      }
    }

    _drawDashedPath(canvas, path, linePaint);

    if (indexAktif != null && indexAktif! < points.length) {
      final p = points[indexAktif!];
      canvas.drawCircle(p, 7, Paint()..color = _Tema.aksen.withOpacity(0.25));
      canvas.drawCircle(p, 5, Paint()..color = _Tema.aksen);
      canvas.drawCircle(p, 5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

    const styleN = TextStyle(color: _Tema.teksAbu, fontSize: 10);
    const styleA = TextStyle(color: _Tema.teksPutih, fontSize: 10, fontWeight: FontWeight.w700);
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];

    for (int i = 0; i < points.length; i++) {
      final aktif = i == indexAktif;
      if (!aktif) canvas.drawCircle(points[i], 3, dotPaint);
      final tp = TextPainter(
        text: TextSpan(text: "${data[i].tanggal.day} ${b[data[i].tanggal.month - 1]}", style: aktif ? styleA : styleN),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, chartH + 6));
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 5.0, dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PrediksiChartPainter old) =>
      old.data != data || old.target != target || old.indexAktif != indexAktif || old.rataRata != rataRata;
}