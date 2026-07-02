import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/users.dart';

// =========================================================
// WARNA TEMA (dark)
// =========================================================
class _Tema {
  static const bg         = Color(0xFF17171B);
  static const card       = Color(0xFF222226);
  static const cardBorder = Color(0xFF2E2E33);
  static const teksAbu    = Color(0xFF9A9AA2);
  static const teksPutih  = Color(0xFFF2F2F3);
}

// =========================================================
// SKALA AQI (US-EPA 0–500)
// =========================================================
class AqiKategori {
  final String label;
  final Color  warna;
  AqiKategori(this.label, this.warna);
}

AqiKategori kategoriDariAqi(int aqi) {
  if (aqi <= 50)  return AqiKategori("Baik",               const Color(0xFF4ADE80));
  if (aqi <= 100) return AqiKategori("Sedang",             const Color(0xFFFACC15));
  if (aqi <= 150) return AqiKategori("Tidak sehat (SG)",   const Color(0xFFFB923C));
  if (aqi <= 200) return AqiKategori("Tidak sehat",        const Color(0xFFF87171));
  if (aqi <= 300) return AqiKategori("Sangat tidak sehat", const Color(0xFFC084FC));
  return             AqiKategori("Berbahaya",               const Color(0xFF991B1B));
}

int _subIndex(double c, List<List<double>> bp) {
  for (final b in bp) {
    if (c >= b[0] && c <= b[1]) {
      return (((b[3] - b[2]) / (b[1] - b[0])) * (c - b[0]) + b[2]).round();
    }
  }
  return bp.last[3].round();
}

const _bpPm25 = [
  [0.0, 12.0, 0.0, 50.0],
  [12.1, 35.4, 51.0, 100.0],
  [35.5, 55.4, 101.0, 150.0],
  [55.5, 150.4, 151.0, 200.0],
  [150.5, 250.4, 201.0, 300.0],
  [250.5, 500.4, 301.0, 500.0],
];

const _bpPm10 = [
  [0.0, 54.0, 0.0, 50.0],
  [55.0, 154.0, 51.0, 100.0],
  [155.0, 254.0, 101.0, 150.0],
  [255.0, 354.0, 151.0, 200.0],
  [355.0, 424.0, 201.0, 300.0],
  [425.0, 604.0, 301.0, 500.0],
];

int hitungAqi(double pm25, double pm10) =>
    math.max(_subIndex(pm25, _bpPm25), _subIndex(pm10, _bpPm10));

// =========================================================
// EVALUASI PER-POLUTAN
// =========================================================
class _EvalPolutan {
  final String kategori;
  final Color  warna;
  _EvalPolutan(this.kategori, this.warna);
}

_EvalPolutan _evalSederhana(double v, List<double> batas) {
  if (v <= batas[0]) return _EvalPolutan("Baik",               const Color(0xFF4ADE80));
  if (v <= batas[1]) return _EvalPolutan("Sedang",             const Color(0xFFFACC15));
  if (v <= batas[2]) return _EvalPolutan("Tidak sehat (SG)",   const Color(0xFFFB923C));
  if (v <= batas[3]) return _EvalPolutan("Tidak sehat",        const Color(0xFFF87171));
  return                    _EvalPolutan("Sangat tidak sehat", const Color(0xFFC084FC));
}

_EvalPolutan evalPm25(double v) => _evalSederhana(v, [12, 35.4, 55.4, 150.4]);
_EvalPolutan evalPm10(double v) => _evalSederhana(v, [54, 154, 254, 354]);
_EvalPolutan evalO3(double v)   => _evalSederhana(v, [54, 70, 85, 105]);
_EvalPolutan evalNo2(double v)  => _evalSederhana(v, [53, 100, 360, 649]);
_EvalPolutan evalSo2(double v)  => _evalSederhana(v, [35, 75, 185, 304]);
_EvalPolutan evalCo(double v)   => _evalSederhana(v, [4.4, 9.4, 12.4, 15.4]);

// =========================================================
// MODEL: 1 BARIS dari tabel monitoring (1 slot jam)
// =========================================================
class CatatanUdara {
  final int      id;
  final String   namaLokasi;
  final double   latitude, longitude;
  final double   pm25, pm10, co, no2, so2, o3;
  final String   status;
  final DateTime waktu;

  CatatanUdara({
    required this.id,
    required this.namaLokasi,
    required this.latitude,
    required this.longitude,
    required this.pm25,
    required this.pm10,
    required this.co,
    required this.no2,
    required this.so2,
    required this.o3,
    required this.status,
    required this.waktu,
  });

  int get aqi => hitungAqi(pm25, pm10);

  factory CatatanUdara.fromJson(Map<String, dynamic> j) {
    double d(String k) => double.tryParse((j[k] ?? "0").toString()) ?? 0;
    return CatatanUdara(
      id:         int.tryParse((j["id"] ?? "0").toString()) ?? 0,
      namaLokasi: (j["nama_lokasi"] ?? "-").toString(),
      latitude:   d("latitude"),
      longitude:  d("longitude"),
      pm25:       d("pm25"),
      pm10:       d("pm10"),
      co:         d("co"),
      no2:        d("no2"),
      so2:        d("so2"),
      o3:         d("o3"),
      status:     (j["status"] ?? "-").toString(),
      waktu:      DateTime.tryParse((j["created_at"] ?? "").toString()) ?? DateTime.now(),
    );
  }
}

// =========================================================
// MODEL: RINGKASAN 1 HARI (titik grafik 7 hari)
// =========================================================
class RingkasanHarian {
  final DateTime tanggal;
  final List<CatatanUdara> jamJam;
  RingkasanHarian({required this.tanggal, required this.jamJam});

  int get aqiRataRata {
    if (jamJam.isEmpty) return 0;
    return (jamJam.fold<int>(0, (s, c) => s + c.aqi) / jamJam.length).round();
  }
}

List<RingkasanHarian> kelompokkanPerHari(List<CatatanUdara> data) {
  final Map<String, List<CatatanUdara>> grup = {};
  for (final c in data) {
    final key =
        "${c.waktu.year}-${c.waktu.month.toString().padLeft(2, '0')}-${c.waktu.day.toString().padLeft(2, '0')}";
    grup.putIfAbsent(key, () => []).add(c);
  }
  final hasil = grup.entries.map((e) {
    final jamJam = [...e.value]..sort((a, b) => a.waktu.compareTo(b.waktu));
    final tgl = jamJam.first.waktu;
    return RingkasanHarian(tanggal: DateTime(tgl.year, tgl.month, tgl.day), jamJam: jamJam);
  }).toList();
  hasil.sort((a, b) => a.tanggal.compareTo(b.tanggal));
  return hasil;
}

// =========================================================
// HASIL REFRESH
// =========================================================
class HasilRefresh {
  final bool   status;
  final bool   skipped;
  final String message;
  final List<CatatanUdara> data;
  HasilRefresh({required this.status, required this.skipped, required this.message, required this.data});
}

// =========================================================
// SERVICE
// =========================================================
class KualitasUdaraHistoryService {
  static const String _endpoint = "${ApiService.baseUrl}/admin/monitoring.php";

  /// Ambil histori dari DB untuk satu lokasi (action=list_riwayat)
  static Future<List<CatatanUdara>> getByLokasi(String namaLokasi) async {
    if (namaLokasi == "Pilih Lokasi") return [];
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action":      "list_riwayat",
      "nama_lokasi": namaLokasi,
    }).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body);
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal mengambil data");

    final List data = body["data"] ?? [];
    return data.map((e) => CatatanUdara.fromJson(e)).toList()
      ..sort((a, b) => a.waktu.compareTo(b.waktu));
  }

  /// Ambil histori 7 hari dari OpenWeather → simpan ke DB (action=ambil_historis)
  static Future<List<CatatanUdara>> ambilHistoris(String namaLokasi) async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action":      "ambil_historis",
      "nama_lokasi": namaLokasi,
    }).timeout(const Duration(seconds: 60));

    final body = jsonDecode(res.body);
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal mengambil histori");

    final List data = body["data"] ?? [];
    return data.map((e) => CatatanUdara.fromJson(e)).toList()
      ..sort((a, b) => a.waktu.compareTo(b.waktu));
  }

  /// Daftar nama lokasi unik untuk dropdown (action=list)
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

  /// Fetch OpenWeather current → simpan ke slot jam terdekat (action=refresh)
  static Future<HasilRefresh> refreshLokasi(String namaLokasi) async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action":      "refresh",
      "nama_lokasi": namaLokasi,
    }).timeout(const Duration(seconds: 20));

    final body = jsonDecode(res.body);
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal memperbarui data");

    final List data = body["data"] ?? [];
    return HasilRefresh(
      status:  true,
      skipped: body["skipped"] == true,
      message: (body["message"] ?? "").toString(),
      data:    data.map((e) => CatatanUdara.fromJson(e)).toList()
        ..sort((a, b) => a.waktu.compareTo(b.waktu)),
    );
  }
}

// =========================================================
// HALAMAN DASHBOARD
// =========================================================
class KualitasUdaraDashboardPage extends StatefulWidget {
  final String lokasiAwal;
  final String judul;
  const KualitasUdaraDashboardPage({
    super.key,
    this.lokasiAwal = "Pilih Lokasi",
    this.judul      = "Validasi Data Kualitas Udara",
  });

  @override
  State<KualitasUdaraDashboardPage> createState() => _KualitasUdaraDashboardPageState();
}

class _KualitasUdaraDashboardPageState extends State<KualitasUdaraDashboardPage> {
  late String        _lokasiAktif  = widget.lokasiAwal;
  List<String>       _daftarLokasi = [];
  List<CatatanUdara> _histori      = [];
  bool               _loading      = true;

  // Tombol "refresh data terkini" (action=refresh)
  bool               _mengambilHistori       = false;
  // Tombol "ambil histori 7 hari" (action=ambil_historis)
  bool               _mengambilHistoriManual = false;
  // Tombol "Export" (kirim ke laporan)
  bool               _mengekspor             = false;

  String?            _error;
  int?               _hariDipilih;
  bool               _cardJamTerbuka   = false;
  int?               _jamDetailTerbuka;

  @override
  void initState() {
    super.initState();
    _muatDaftarLokasi();
    _muatData();
  }

  Future<void> _muatDaftarLokasi() async {
    try {
      final daftar = await KualitasUdaraHistoryService.getDaftarLokasi();
      if (!mounted) return;
      setState(() => _daftarLokasi = daftar);
    } catch (_) {}
  }

  /// Load data dari DB. Kalau kosong & lokasi sudah dipilih,
  /// otomatis fetch 7 hari historis dari OpenWeather.
  Future<void> _muatData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final hasil = await KualitasUdaraHistoryService.getByLokasi(_lokasiAktif);
      if (!mounted) return;

      if (hasil.isEmpty && _lokasiAktif != "Pilih Lokasi") {
        // Data kosong → otomatis ambil historis dari OpenWeather
        await _ambilHistoriOtomatis();
        return; // _ambilHistoriOtomatis sudah atur _histori & _loading
      }

      setState(() {
        _histori          = hasil;
        _hariDipilih      = null;
        _cardJamTerbuka   = false;
        _jamDetailTerbuka = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Dipanggil otomatis oleh _muatData() saat data DB kosong.
  /// Fetch 7 hari historis dari OpenWeather lewat action=ambil_historis.
  Future<void> _ambilHistoriOtomatis() async {
    try {
      final hasil = await KualitasUdaraHistoryService.ambilHistoris(_lokasiAktif);
      if (!mounted) return;
      setState(() {
        _histori          = hasil;
        _hariDipilih      = null;
        _cardJamTerbuka   = false;
        _jamDetailTerbuka = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Tombol "refresh" (ikon download) di area grafik: fetch data TERKINI
  /// dari OpenWeather (current) lewat action=refresh, simpan ke slot jam
  /// terdekat. TIDAK menarik histori 7 hari -- cuma 1 titik data baru.
  Future<void> _ambilDataHistori() async {
    if (_lokasiAktif == "Pilih Lokasi") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih lokasi terlebih dahulu")),
      );
      return;
    }
    if (_mengambilHistori) return;

    setState(() => _mengambilHistori = true);
    try {
      final hasil = await KualitasUdaraHistoryService.refreshLokasi(_lokasiAktif);
      if (!mounted) return;
      setState(() {
        _histori          = hasil.data;
        _hariDipilih      = null;
        _cardJamTerbuka   = false;
        _jamDetailTerbuka = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(hasil.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))));
    } finally {
      if (mounted) setState(() => _mengambilHistori = false);
    }
  }

  /// Tombol BARU "ambil histori" (ikon jam mundur) di area grafik:
  /// fetch HISTORI 7 HARI dari OpenWeather Historical API lewat
  /// action=ambil_historis. Bisa dipencet kapan saja sebagai
  /// retry/refresh manual, terlepas dari auto-fetch saat lokasi baru
  /// pertama kali dibuat di validasi.php.
  Future<void> _ambilHistoriManual() async {
    if (_lokasiAktif == "Pilih Lokasi") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih lokasi terlebih dahulu")),
      );
      return;
    }
    if (_mengambilHistoriManual) return;

    setState(() => _mengambilHistoriManual = true);
    try {
      final hasil = await KualitasUdaraHistoryService.ambilHistoris(_lokasiAktif);
      if (!mounted) return;
      setState(() {
        _histori          = hasil;
        _hariDipilih      = null;
        _cardJamTerbuka   = false;
        _jamDetailTerbuka = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Histori 7 hari berhasil diperbarui")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _mengambilHistoriManual = false);
    }
  }

  /// Tombol "Export" -> kirim kategori "kualitas_udara" ke laporan,
  /// khusus untuk lokasi yang sedang aktif di dashboard ini.
  Future<void> _kirimKeLaporan() async {
    if (_lokasiAktif == "Pilih Lokasi") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih lokasi terlebih dahulu")),
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
          "kategori": "kualitas_udara",
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
                ? "Data kualitas udara ($_lokasiAktif) dikirim ke laporan"
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
                ? const Icon(Icons.check, color: Color(0xFFF87171))
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

  Widget _buildError() {
    return ListView(children: [
      Padding(
        padding: const EdgeInsets.only(top: 120, left: 24, right: 24),
        child: Column(children: [
          const Icon(Icons.cloud_off, size: 40, color: _Tema.teksAbu),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: _Tema.teksAbu)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _muatData, child: const Text("Coba lagi")),
        ]),
      ),
    ]);
  }

  Widget _buildKonten() {
    if (_lokasiAktif == "Pilih Lokasi" || _histori.isEmpty) {
      return ListView(padding: const EdgeInsets.all(14), children: [
        _buildLokasiBar(),
        const SizedBox(height: 60),
        Center(
          child: Text(
            _lokasiAktif == "Pilih Lokasi"
                ? "Pilih lokasi terlebih dahulu"
                : "Belum ada data untuk lokasi ini",
            textAlign: TextAlign.center,
            style: const TextStyle(color: _Tema.teksAbu, fontSize: 13),
          ),
        ),
      ]);
    }

    final semuaHari = kelompokkanPerHari(_histori);
    final tujuhHari = semuaHari.length > 7
        ? semuaHari.sublist(semuaHari.length - 7)
        : semuaHari;

    final aqiList   = tujuhHari.map((h) => h.aqiRataRata).toList();
    final tertinggi = aqiList.reduce(math.max);
    final terendah  = aqiList.reduce(math.min);
    final rataRata  = (aqiList.reduce((a, b) => a + b) / aqiList.length).round();

    final int indexAktif = (_hariDipilih != null && _hariDipilih! < tujuhHari.length)
        ? _hariDipilih!
        : tujuhHari.length - 1;
    final hariAktif    = tujuhHari[indexAktif];
    final kategoriAktif = kategoriDariAqi(hariAktif.aqiRataRata);

    return ListView(padding: const EdgeInsets.all(14), children: [
      _buildLokasiBar(),
      const SizedBox(height: 6),
      Text(_formatTanggalLengkap(hariAktif.tanggal),
          style: const TextStyle(fontSize: 12, color: _Tema.teksAbu)),
      const SizedBox(height: 14),

      // ===== GAUGE AQI =====
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Tema.cardBorder),
        ),
        child: Column(children: [
          Row(children: const [
            Text("Indeks kualitas udara (rata-rata harian)",
                style: TextStyle(fontSize: 13, color: _Tema.teksAbu)),
            SizedBox(width: 4),
            Icon(Icons.info_outline, size: 13, color: _Tema.teksAbu),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 110,
            child: CustomPaint(
              painter: _GaugePainter(aqi: hariAktif.aqiRataRata),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(children: [
                    Text("${hariAktif.aqiRataRata}",
                        style: TextStyle(fontSize: 38,
                            fontWeight: FontWeight.w700, color: kategoriAktif.warna)),
                    Text(kategoriAktif.label,
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600, color: kategoriAktif.warna)),
                  ]),
                ),
              ),
            ),
          ),
          if (hariAktif.aqiRataRata > 100) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3A2E10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFFACC15)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  "Kelompok sensitif: anak-anak, lansia, dan penderita penyakit "
                      "pernapasan disarankan tetap di dalam ruangan.",
                  style: TextStyle(fontSize: 11.5, color: Colors.amber[100]),
                )),
              ]),
            ),
          ] else if (hariAktif.aqiRataRata > 50) ...[
            const SizedBox(height: 6),
            const Text(
              "Tidak sehat bagi kelompok sensitif. Hindari aktivitas luar ruangan terlalu lama.",
              style: TextStyle(fontSize: 11.5, color: _Tema.teksAbu),
              textAlign: TextAlign.center,
            ),
          ],
        ]),
      ),
      const SizedBox(height: 12),

      // ===== STAT BOXES =====
      Row(children: [
        Expanded(child: _statBox("Tertinggi", "$tertinggi")),
        const SizedBox(width: 8),
        Expanded(child: _statBox("Terendah",  "$terendah")),
        const SizedBox(width: 8),
        Expanded(child: _statBox("Rata-rata", "$rataRata")),
      ]),
      const SizedBox(height: 12),

      // ===== TOMBOL EXPORT (kirim ke laporan) =====
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _mengekspor ? null : _kirimKeLaporan,
          icon: _mengekspor
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.ios_share, size: 16),
          label: Text(_mengekspor ? "Mengirim..." : "Export ke Laporan"),
          style: OutlinedButton.styleFrom(
            foregroundColor: _Tema.teksPutih,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: _Tema.cardBorder),
          ),
        ),
      ),
      const SizedBox(height: 18),

      // ===== GRAFIK 7 HARI =====
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Grafik AQI (7 hari terakhir)",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _Tema.teksPutih)),
        Row(children: [
          const Text("Ketuk untuk detail", style: TextStyle(fontSize: 11, color: _Tema.teksAbu)),
          const SizedBox(width: 8),

          // TOMBOL BARU: ambil histori 7 hari dari OpenWeather Historical
          // (action=ambil_historis). Bisa dipakai sebagai retry manual
          // kapan saja, terlepas dari auto-fetch saat lokasi baru dibuat.
          Tooltip(
            message: "Ambil histori 7 hari dari OpenWeather",
            child: InkWell(
              onTap: _mengambilHistoriManual ? null : _ambilHistoriManual,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 28, height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _Tema.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _Tema.cardBorder),
                ),
                child: _mengambilHistoriManual
                    ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFFFB7155)),
                    ),
                  ),
                )
                    : const Icon(Icons.history, size: 16, color: Color(0xFFFB7155)),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Tombol lama: refresh data TERKINI (action=refresh)
          Tooltip(
            message: "Ambil data terkini",
            child: InkWell(
              onTap: _mengambilHistori ? null : _ambilDataHistori,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 28, height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _Tema.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _Tema.cardBorder),
                ),
                child: _mengambilHistori
                    ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFFFB7155)),
                    ),
                  ),
                )
                    : const Icon(Icons.download_rounded, size: 16, color: Color(0xFFFB7155)),
              ),
            ),
          ),
        ]),
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
              onTapDown: (d) => _pilihHariTerdekat(d.localPosition, size, tujuhHari.length),
              onPanUpdate: (d) => _pilihHariTerdekat(d.localPosition, size, tujuhHari.length),
              child: CustomPaint(
                painter: _LineChartPainter(tujuhHari, indexAktif: indexAktif),
                child: Container(),
              ),
            );
          }),
        ),
      ),
      const SizedBox(height: 14),

      // ===== BREAKDOWN PER-JAM (accordion) =====
      _buildCardBreakdownJam(hariAktif),
      const SizedBox(height: 18),

      // ===== INFO LOKASI =====
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Tema.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Informasi lokasi",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _Tema.teksPutih)),
          const SizedBox(height: 10),
          _baris("Koordinat",
              "${hariAktif.jamJam.last.latitude.toStringAsFixed(5)}, ${hariAktif.jamJam.last.longitude.toStringAsFixed(4)}"),
          _baris("Sumber data",     "OpenWeatherMap"),
          _baris("Update terakhir", _formatJam(_histori.last.waktu)),
        ]),
      ),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildCardBreakdownJam(RingkasanHarian hari) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFB7155)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() {
            _cardJamTerbuka = !_cardJamTerbuka;
            if (!_cardJamTerbuka) _jamDetailTerbuka = null;
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.schedule, size: 16, color: Color(0xFFFB7155)),
              const SizedBox(width: 8),
              Expanded(child: Text(
                "Detail per jam • ${_formatTanggalSingkat(hari.tanggal)}",
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _Tema.teksPutih),
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFB7155).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text("${hari.jamJam.length} data",
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFFB7155))),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _cardJamTerbuka ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down, size: 20, color: _Tema.teksAbu),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _cardJamTerbuka
              ? Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(children: hari.jamJam.map(_barisJam).toList()),
          )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ]),
    );
  }

  Widget _barisJam(CatatanUdara c) {
    final terbuka  = _jamDetailTerbuka == c.id;
    final kategori = kategoriDariAqi(c.aqi);
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
          onTap: () => setState(() => _jamDetailTerbuka = terbuka ? null : c.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              SizedBox(width: 52,
                  child: Text(_formatJam(c.waktu),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _Tema.teksPutih))),
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: kategori.warna, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(kategori.label,
                  style: TextStyle(fontSize: 11.5, color: kategori.warna, fontWeight: FontWeight.w500))),
              Text("AQI ${c.aqi}",
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
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.0,
              children: [
                _kartuPolutanKecil("PM2.5",     "${c.pm25.toStringAsFixed(0)} µg/m³", evalPm25(c.pm25)),
                _kartuPolutanKecil("PM10",      "${c.pm10.toStringAsFixed(0)} µg/m³", evalPm10(c.pm10)),
                _kartuPolutanKecil("O3 (ozon)", "${c.o3.toStringAsFixed(0)} ppb",     evalO3(c.o3)),
                _kartuPolutanKecil("NO2",       "${c.no2.toStringAsFixed(0)} ppb",    evalNo2(c.no2)),
                _kartuPolutanKecil("SO2",       "${c.so2.toStringAsFixed(0)} ppb",    evalSo2(c.so2)),
                _kartuPolutanKecil("CO",        "${c.co.toStringAsFixed(1)} ppm",     evalCo(c.co)),
              ],
            ),
          )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ]),
    );
  }

  void _pilihHariTerdekat(Offset pos, Size size, int jumlah) {
    if (jumlah <= 0) return;
    final stepX = jumlah > 1 ? size.width / (jumlah - 1) : size.width;
    final index = (pos.dx / stepX).round().clamp(0, jumlah - 1);
    if (_hariDipilih != index) {
      setState(() { _hariDipilih = index; _jamDetailTerbuka = null; });
    }
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
        Expanded(child: Text(widget.judul,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _Tema.teksPutih),
            overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _buildLokasiBar() {
    return Row(children: [
      Expanded(child: InkWell(
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
      )),
      const SizedBox(width: 8),
      // Refresh: cuma reload dari DB (tidak hit OpenWeather)
      InkWell(
        onTap: _muatData,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: _Tema.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _Tema.cardBorder),
          ),
          child: const Icon(Icons.refresh, size: 18, color: _Tema.teksPutih),
        ),
      ),
    ]);
  }

  Widget _statBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _Tema.teksPutih)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: _Tema.teksAbu)),
      ]),
    );
  }

  Widget _kartuPolutanKecil(String label, String nilai, _EvalPolutan info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: _Tema.teksAbu)),
            Text(nilai, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _Tema.teksPutih)),
          ],
        )),
        Container(width: 7, height: 7,
            decoration: BoxDecoration(color: info.warna, shape: BoxShape.circle)),
      ]),
    );
  }

  Widget _baris(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: _Tema.teksAbu))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _Tema.teksPutih)),
      ]),
    );
  }

  String _formatTanggalLengkap(DateTime t) {
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    return "${t.day} ${b[t.month - 1]} ${t.year}";
  }

  String _formatTanggalSingkat(DateTime t) {
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    return "${t.day} ${b[t.month - 1]}";
  }

  String _formatJam(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
}

// =========================================================
// GAUGE
// =========================================================
class _GaugePainter extends CustomPainter {
  final int aqi;
  _GaugePainter({required this.aqi});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 4);
    final radius = math.min(size.width / 2, size.height) - 10;
    const sw = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, math.pi, math.pi, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = sw
          ..strokeCap = StrokeCap.round..color = const Color(0xFF2E2E33));

    final progress = (aqi / 200).clamp(0.0, 1.0);
    canvas.drawArc(rect, math.pi, math.pi * progress, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = sw
          ..strokeCap = StrokeCap.round
          ..shader = const SweepGradient(
            startAngle: math.pi, endAngle: 2 * math.pi,
            colors: [Color(0xFF4ADE80),Color(0xFFFACC15),Color(0xFFFB923C),Color(0xFFF87171),Color(0xFF991B1B)],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ).createShader(rect));

    final sudut = math.pi + (math.pi * progress);
    canvas.drawCircle(
        Offset(center.dx + radius * math.cos(sudut), center.dy + radius * math.sin(sudut)),
        5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.aqi != aqi;
}

// =========================================================
// GRAFIK GARIS 7 HARI
// =========================================================
class _LineChartPainter extends CustomPainter {
  final List<RingkasanHarian> data;
  final int? indexAktif;
  _LineChartPainter(this.data, {this.indexAktif});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final nilai  = data.map((e) => e.aqiRataRata.toDouble()).toList();
    final maxV   = nilai.reduce(math.max);
    final minV   = nilai.reduce(math.min);
    final range  = (maxV - minV).clamp(1, double.infinity);

    const paddingBottom = 22.0;
    final chartH = size.height - paddingBottom;
    final stepX  = data.length > 1 ? size.width / (data.length - 1) : size.width;

    final linePaint = Paint()..color = const Color(0xFFFB7155)..strokeWidth = 2.2..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFFFB7155).withOpacity(0.25), const Color(0xFFFB7155).withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartH));
    final dotPaint = Paint()..color = const Color(0xFFFB7155);

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
    canvas.drawPath(path, linePaint);

    if (indexAktif != null && indexAktif! < points.length) {
      final p = points[indexAktif!];
      final dashP = Paint()..color = const Color(0xFFFB7155).withOpacity(0.45)..strokeWidth = 1;
      double y = 0;
      while (y < chartH) {
        canvas.drawLine(Offset(p.dx, y), Offset(p.dx, math.min(y + 4, chartH)), dashP);
        y += 7;
      }
      canvas.drawCircle(p, 7, Paint()..color = const Color(0xFFFB7155).withOpacity(0.25));
      canvas.drawCircle(p, 5, Paint()..color = const Color(0xFFFB7155));
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

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.data != data || old.indexAktif != indexAktif;
}