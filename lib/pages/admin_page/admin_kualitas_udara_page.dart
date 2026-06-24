import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/users.dart';

/// =========================================================
/// WARNA TEMA (dark, meniru screenshot)
/// =========================================================
class _Tema {
  static const bg = Color(0xFF17171B);
  static const card = Color(0xFF222226);
  static const cardBorder = Color(0xFF2E2E33);
  static const teksAbu = Color(0xFF9A9AA2);
  static const teksPutih = Color(0xFFF2F2F3);
}

/// =========================================================
/// SKALA AQI (gaya US-EPA 0-500) -- supaya tampilannya
/// sama seperti screenshot ("151 Tidak sehat", dst), bukan
/// skala OpenWeatherMap (1-5).
/// =========================================================
class AqiKategori {
  final String label;
  final Color warna;
  AqiKategori(this.label, this.warna);
}

AqiKategori kategoriDariAqi(int aqi) {
  if (aqi <= 50) return AqiKategori("Baik", const Color(0xFF4ADE80));
  if (aqi <= 100) return AqiKategori("Sedang", const Color(0xFFFACC15));
  if (aqi <= 150) return AqiKategori("Tidak sehat (SG)", const Color(0xFFFB923C));
  if (aqi <= 200) return AqiKategori("Tidak sehat", const Color(0xFFF87171));
  if (aqi <= 300) return AqiKategori("Sangat tidak sehat", const Color(0xFFC084FC));
  return AqiKategori("Berbahaya", const Color(0xFF991B1B));
}

/// Konversi konsentrasi pollutant -> sub-index AQI (interpolasi linear
/// breakpoint EPA). Dipakai untuk PM2.5 & PM10 (yang punya tabel resmi).
int _subIndex(double c, List<List<double>> breakpoints) {
  for (final bp in breakpoints) {
    final cLow = bp[0], cHigh = bp[1], iLow = bp[2], iHigh = bp[3];
    if (c >= cLow && c <= cHigh) {
      final aqi = ((iHigh - iLow) / (cHigh - cLow)) * (c - cLow) + iLow;
      return aqi.round();
    }
  }
  return breakpoints.last[3].round();
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

/// AQI keseluruhan = nilai tertinggi dari sub-index PM2.5 & PM10
/// (kedua pollutant ini yang punya breakpoint resmi & paling dominan)
int hitungAqi(double pm25, double pm10) {
  final a = _subIndex(pm25, _bpPm25);
  final b = _subIndex(pm10, _bpPm10);
  return math.max(a, b);
}

/// Kategori per-pollutant sederhana (dipakai utk badge kartu polutan)
class _EvalPolutan {
  final String kategori;
  final Color warna;
  _EvalPolutan(this.kategori, this.warna);
}

_EvalPolutan _evalSederhana(double v, List<double> batas) {
  if (v <= batas[0]) return _EvalPolutan("Baik", const Color(0xFF4ADE80));
  if (v <= batas[1]) return _EvalPolutan("Sedang", const Color(0xFFFACC15));
  if (v <= batas[2]) return _EvalPolutan("Tidak sehat (SG)", const Color(0xFFFB923C));
  if (v <= batas[3]) return _EvalPolutan("Tidak sehat", const Color(0xFFF87171));
  return _EvalPolutan("Sangat tidak sehat", const Color(0xFFC084FC));
}

_EvalPolutan evalPm25(double v) => _evalSederhana(v, [12, 35.4, 55.4, 150.4]);
_EvalPolutan evalPm10(double v) => _evalSederhana(v, [54, 154, 254, 354]);
_EvalPolutan evalO3(double v) => _evalSederhana(v, [54, 70, 85, 105]);
_EvalPolutan evalNo2(double v) => _evalSederhana(v, [53, 100, 360, 649]);
_EvalPolutan evalSo2(double v) => _evalSederhana(v, [35, 75, 185, 304]);
_EvalPolutan evalCo(double v) => _evalSederhana(v, [4.4, 9.4, 12.4, 15.4]);

/// =========================================================
/// MODEL -- 1 baris data dari tabel `kualitas_udara`
/// =========================================================
class CatatanUdara {
  final int id;
  final String namaLokasi;
  final double latitude;
  final double longitude;
  final double pm25, pm10, co, no2, so2, o3;
  final String status;
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
      id: int.tryParse((j["id"] ?? "0").toString()) ?? 0,
      namaLokasi: (j["nama_lokasi"] ?? "-").toString(),
      latitude: d("latitude"),
      longitude: d("longitude"),
      pm25: d("pm25"),
      pm10: d("pm10"),
      co: d("co"),
      no2: d("no2"),
      so2: d("so2"),
      o3: d("o3"),
      status: (j["status"] ?? "-").toString(),
      waktu: DateTime.tryParse((j["created_at"] ?? "").toString()) ?? DateTime.now(),
    );
  }
}

/// =========================================================
/// SERVICE -- mengambil histori dari monitoring.php (action=list)
/// lalu difilter per lokasi di sisi Dart.
/// =========================================================
class KualitasUdaraHistoryService {
  static const String _endpoint = "${ApiService.baseUrl}/monitoring.php";

  static Future<List<CatatanUdara>> getByLokasi(String namaLokasi) async {
    final res = await http
        .post(Uri.parse(_endpoint), body: {"action": "list"})
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body);
    if (body["status"] != true) {
      throw Exception(body["message"] ?? "Gagal mengambil histori");
    }

    final List data = body["data"] ?? [];
    final semua = data.map((e) => CatatanUdara.fromJson(e)).toList();

    final hasil = semua
        .where((c) => c.namaLokasi.toLowerCase().contains(namaLokasi.toLowerCase()))
        .toList()
      ..sort((a, b) => a.waktu.compareTo(b.waktu)); // ascending (lama -> baru)

    return hasil;
  }

  /// Daftar nama lokasi unik (untuk dropdown), diambil dari seluruh data.
  static Future<List<String>> getDaftarLokasi() async {
    final res = await http
        .post(Uri.parse(_endpoint), body: {"action": "list"})
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body);
    if (body["status"] != true) return [];

    final List data = body["data"] ?? [];
    final nama = data.map((e) => (e["nama_lokasi"] ?? "").toString()).where((s) => s.isNotEmpty).toSet().toList();
    nama.sort();
    return nama;
  }
}

/// =========================================================
/// HALAMAN DASHBOARD
/// =========================================================
class KualitasUdaraDashboardPage extends StatefulWidget {
  final String lokasiAwal;
  final String judul;
  const KualitasUdaraDashboardPage({
    super.key,
    this.lokasiAwal = "Pilih Lokasi",
    this.judul = "Validasi Data Kualitas Udara",
  });

  @override
  State<KualitasUdaraDashboardPage> createState() => _KualitasUdaraDashboardPageState();
}

class _KualitasUdaraDashboardPageState extends State<KualitasUdaraDashboardPage> {
  late String _lokasiAktif = widget.lokasiAwal;
  List<String> _daftarLokasi = [];
  List<CatatanUdara> _histori = [];
  bool _loading = true;
  String? _error;

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
    } catch (_) {
      // diamkan, dropdown tetap pakai lokasi aktif saja kalau gagal
    }
  }

  Future<void> _muatData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasil = await KualitasUdaraHistoryService.getByLokasi(_lokasiAktif);
      if (!mounted) return;
      setState(() => _histori = hasil);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pilihLokasi() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _Tema.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final daftar = _daftarLokasi.isNotEmpty ? _daftarLokasi : [_lokasiAktif];
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: daftar.map((nama) {
            return ListTile(
              leading: const Icon(Icons.location_on_outlined, color: _Tema.teksAbu),
              title: Text(nama, style: const TextStyle(color: _Tema.teksPutih)),
              trailing: nama == _lokasiAktif ? const Icon(Icons.check, color: Color(0xFFF87171)) : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _lokasiAktif = nama);
                _muatData();
              },
            );
          }).toList(),
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
            // Header (tombol back + judul) -- STATIS, di luar RefreshIndicator
            // supaya tidak ikut tertarik saat pull-to-refresh.
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
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 120, left: 24, right: 24),
          child: Column(
            children: [
              const Icon(Icons.cloud_off, size: 40, color: _Tema.teksAbu),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _Tema.teksAbu)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _muatData, child: const Text("Coba lagi")),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKonten() {
    if (_histori.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _buildLokasiBar(),
          const SizedBox(height: 60),
          const Center(
            child: Text(
              "Belum ada data untuk lokasi ini",
              style: TextStyle(color: _Tema.teksAbu, fontSize: 13),
            ),
          ),
        ],
      );
    }

    final terbaru = _histori.last;
    final tujuhHari = _histori.length > 7 ? _histori.sublist(_histori.length - 7) : _histori;
    final aqiList = tujuhHari.map((c) => c.aqi).toList();
    final tertinggi = aqiList.reduce(math.max);
    final terendah = aqiList.reduce(math.min);
    final rataRata = (aqiList.reduce((a, b) => a + b) / aqiList.length).round();

    final kategori = kategoriDariAqi(terbaru.aqi);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _buildLokasiBar(),
        const SizedBox(height: 6),
        Text(_formatTanggal(terbaru.waktu), style: const TextStyle(fontSize: 12, color: _Tema.teksAbu)),
        const SizedBox(height: 14),

        // ===== KARTU GAUGE AQI =====
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _Tema.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _Tema.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: const [
                  Text("Indeks kualitas udara", style: TextStyle(fontSize: 13, color: _Tema.teksAbu)),
                  SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 13, color: _Tema.teksAbu),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 110,
                child: CustomPaint(
                  painter: _GaugePainter(aqi: terbaru.aqi),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: Column(
                        children: [
                          Text("${terbaru.aqi}",
                              style: TextStyle(fontSize: 38, fontWeight: FontWeight.w700, color: kategori.warna)),
                          Text(kategori.label,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kategori.warna)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (terbaru.aqi > 100) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A2E10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFFACC15)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Kelompok sensitif: anak-anak, lansia, dan penderita penyakit pernapasan "
                              "disarankan tetap di dalam ruangan.",
                          style: TextStyle(fontSize: 11.5, color: Colors.amber[100]),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (terbaru.aqi > 50) ...[
                const SizedBox(height: 6),
                const Text(
                  "Tidak sehat bagi kelompok sensitif. Hindari aktivitas luar ruangan terlalu lama.",
                  style: TextStyle(fontSize: 11.5, color: _Tema.teksAbu),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ===== TERTINGGI / TERENDAH / RATA-RATA =====
        Row(
          children: [
            Expanded(child: _statBox("Tertinggi", "$tertinggi")),
            const SizedBox(width: 8),
            Expanded(child: _statBox("Terendah", "$terendah")),
            const SizedBox(width: 8),
            Expanded(child: _statBox("Rata-rata", "$rataRata")),
          ],
        ),
        const SizedBox(height: 18),

        // ===== GRAFIK AQI 7 HARI =====
        const Text("Grafik AQI (7 hari terakhir)",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _Tema.teksPutih)),
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
            child: CustomPaint(painter: _LineChartPainter(tujuhHari), child: Container()),
          ),
        ),
        const SizedBox(height: 18),

        // ===== DETAIL POLUTAN =====
        const Text("Detail polutan",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _Tema.teksPutih)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.7,
          children: [
            _kartuPolutan("PM2.5", "${terbaru.pm25.toStringAsFixed(0)} µg/m³", evalPm25(terbaru.pm25)),
            _kartuPolutan("PM10", "${terbaru.pm10.toStringAsFixed(0)} µg/m³", evalPm10(terbaru.pm10)),
            _kartuPolutan("O3 (ozon)", "${terbaru.o3.toStringAsFixed(0)} ppb", evalO3(terbaru.o3)),
            _kartuPolutan("NO2", "${terbaru.no2.toStringAsFixed(0)} ppb", evalNo2(terbaru.no2)),
            _kartuPolutan("SO2", "${terbaru.so2.toStringAsFixed(0)} ppb", evalSo2(terbaru.so2)),
            _kartuPolutan("CO", "${terbaru.co.toStringAsFixed(1)} ppm", evalCo(terbaru.co)),
          ],
        ),
        const SizedBox(height: 18),

        // ===== INFORMASI LOKASI =====
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _Tema.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _Tema.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Informasi lokasi",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _Tema.teksPutih)),
              const SizedBox(height: 10),
              _baris("Koordinat", "${terbaru.latitude.toStringAsFixed(5)}, ${terbaru.longitude.toStringAsFixed(4)}"),
              _baris("Ketinggian", "-"),
              _baris("Sumber data", "OpenWeatherAQ"),
              _baris("Update terakhir", _formatJam(terbaru.waktu)),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Header statis: tombol back bulat (abu muda, ikon panah kiri) + judul,
  /// gaya disamakan dengan referensi screenshot yang dikirim.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE9E9EC), // abu muda, sesuai referensi (bukan dark card)
              ),
              child: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF222226)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.judul,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _Tema.teksPutih),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLokasiBar() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _pilihLokasi,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _Tema.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _Tema.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: _Tema.teksAbu),
                  const SizedBox(width: 8),
                  Text(_lokasiAktif,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _Tema.teksPutih)),
                  const Spacer(),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: _Tema.teksAbu),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _muatData,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _Tema.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _Tema.cardBorder),
            ),
            child: const Icon(Icons.refresh, size: 18, color: _Tema.teksPutih),
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _Tema.teksPutih)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: _Tema.teksAbu)),
        ],
      ),
    );
  }

  Widget _kartuPolutan(String label, String nilai, _EvalPolutan info) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _Tema.teksAbu)),
          const SizedBox(height: 4),
          Text(nilai, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _Tema.teksPutih)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: info.warna.withOpacity(0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(info.kategori, style: TextStyle(fontSize: 10, color: info.warna, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _baris(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: _Tema.teksAbu))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _Tema.teksPutih)),
        ],
      ),
    );
  }

  String _formatTanggal(DateTime t) {
    const bulan = [
      "Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"
    ];
    final jam = t.hour.toString().padLeft(2, '0');
    final menit = t.minute.toString().padLeft(2, '0');
    return "${t.day} ${bulan[t.month - 1]} ${t.year}, $jam:$menit WIB";
  }

  String _formatJam(DateTime t) {
    final jam = t.hour.toString().padLeft(2, '0');
    final menit = t.minute.toString().padLeft(2, '0');
    return "$jam:$menit WIB";
  }
}

/// =========================================================
/// GAUGE SETENGAH LINGKARAN (gradasi hijau -> kuning -> oranye -> merah)
/// =========================================================
class _GaugePainter extends CustomPainter {
  final int aqi; // skala 0-500, ditampilkan sampai 200 lalu mengisi penuh
  _GaugePainter({required this.aqi});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 4);
    final radius = math.min(size.width / 2, size.height) - 10;
    const strokeWidth = 14.0;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2E2E33);

    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: math.pi,
        endAngle: 2 * math.pi,
        colors: [
          Color(0xFF4ADE80),
          Color(0xFFFACC15),
          Color(0xFFFB923C),
          Color(0xFFF87171),
          Color(0xFF991B1B),
        ],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(rect);

    final progress = (aqi / 200).clamp(0.0, 1.0); // full arc tercapai di AQI 200
    canvas.drawArc(rect, math.pi, math.pi * progress, false, gradientPaint);

    // jarum penunjuk
    final sudut = math.pi + (math.pi * progress);
    final ujung = Offset(
      center.dx + (radius) * math.cos(sudut),
      center.dy + (radius) * math.sin(sudut),
    );
    final jarumPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(ujung, 5, jarumPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.aqi != aqi;
}

/// =========================================================
/// GRAFIK GARIS AQI 7 HARI (dark theme)
/// =========================================================
class _LineChartPainter extends CustomPainter {
  final List<CatatanUdara> data;
  _LineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final nilai = data.map((e) => e.aqi.toDouble()).toList();
    final maxV = nilai.reduce(math.max);
    final minV = nilai.reduce(math.min);
    final range = (maxV - minV).clamp(1, double.infinity);

    const paddingBottom = 22.0;
    final chartHeight = size.height - paddingBottom;
    final stepX = data.length > 1 ? size.width / (data.length - 1) : size.width;

    final linePaint = Paint()
      ..color = const Color(0xFFFB7155)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFFB7155).withOpacity(0.25), const Color(0xFFFB7155).withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));

    final dotPaint = Paint()..color = const Color(0xFFFB7155);

    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalized = (nilai[i] - minV) / range;
      final y = chartHeight - (normalized * chartHeight);
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final labelStyle = const TextStyle(color: _Tema.teksAbu, fontSize: 10);

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 3, dotPaint);

      final tp = TextPainter(
        text: TextSpan(text: _labelTanggal(data[i].waktu), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, chartHeight + 6));
    }
  }

  String _labelTanggal(DateTime t) {
    const bulan = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    return "${t.day} ${bulan[t.month - 1]}";
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}