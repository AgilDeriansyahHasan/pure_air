import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/users.dart';

// =========================================================
// TEMA TERANG -- selaras dashboard user (PureAir)
// =========================================================
class _T {
  static const bg         = Color(0xFFF5F5F5);
  static const card       = Colors.white;
  static const border     = Color(0xFFE0E0E0);
  static const abu        = Color(0xFF8A8A8E);
  static const hitam      = Color(0xFF1C1C1E);
  static const biru       = Color(0xFF2F80ED);
}

// =========================================================
// KATEGORI AQI
// =========================================================
class _AqiInfo {
  final String label;
  final Color  warna;
  _AqiInfo(this.label, this.warna);
}

_AqiInfo _kategoriAqi(double aqi) {
  if (aqi <= 50)  return _AqiInfo("Baik",               const Color(0xFF34C759));
  if (aqi <= 100) return _AqiInfo("Sedang",             const Color(0xFFFFC107));
  if (aqi <= 150) return _AqiInfo("Tidak sehat (SG)",   const Color(0xFFFF9500));
  if (aqi <= 200) return _AqiInfo("Tidak sehat",        const Color(0xFFFF3B30));
  if (aqi <= 300) return _AqiInfo("Sangat tidak sehat", const Color(0xFFAF52DE));
  return             _AqiInfo("Berbahaya",               const Color(0xFF8B0000));
}

// =========================================================
// MODEL: 1 baris histori
// =========================================================
class _BariHistori {
  final String   waktu;
  final double   aqi, pm25, pm10, co, no2, so2, o3;

  _BariHistori({
    required this.waktu,
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.co,
    required this.no2,
    required this.so2,
    required this.o3,
  });

  factory _BariHistori.fromJson(Map<String, dynamic> j) {
    double d(String k) => double.tryParse((j[k] ?? "0").toString()) ?? 0;
    return _BariHistori(
      waktu: (j["waktu"] ?? "").toString(),
      aqi:   d("aqi"),
      pm25:  d("pm25"),
      pm10:  d("pm10"),
      co:    d("co"),
      no2:   d("no2"),
      so2:   d("so2"),
      o3:    d("o3"),
    );
  }
}

// =========================================================
// MODEL: ringkasan statistik dari PHP
// =========================================================
class _Ringkasan {
  final double aqiRata;
  final double aqiTertinggi;
  final double aqiTerendah;
  final String kondisiDominan;
  final int    jumlahData;

  _Ringkasan({
    required this.aqiRata,
    required this.aqiTertinggi,
    required this.aqiTerendah,
    required this.kondisiDominan,
    required this.jumlahData,
  });

  factory _Ringkasan.fromJson(Map<String, dynamic> j) {
    double d(String k) => double.tryParse((j[k] ?? "0").toString()) ?? 0;
    return _Ringkasan(
      aqiRata:        d("aqi_rata"),
      aqiTertinggi:   d("aqi_tertinggi"),
      aqiTerendah:    d("aqi_terendah"),
      kondisiDominan: (j["kondisi_dominan"] ?? "-").toString(),
      jumlahData:     int.tryParse((j["jumlah_data"] ?? "0").toString()) ?? 0,
    );
  }
}

// =========================================================
// SERVICE
// =========================================================
class _HistoriService {
  static const String _endpoint = "${ApiService.baseUrl}/user/user_history.php";

  static Future<List<String>> getDaftarLokasi() async {
    final res = await http
        .post(Uri.parse(_endpoint), body: {"action": "list_lokasi"})
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body);
    if (body["status"] != true) return [];
    final List data = body["data"] ?? [];
    return data
        .map((e) => (e["nama_lokasi"] ?? "").toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  static Future<({List<_BariHistori> data, _Ringkasan? ringkasan, String? pesan})>
  getHistori(
      String namaLokasi, {
        String? tanggalMulai,
        String? tanggalSelesai,
      }) async {
    final body = <String, String>{
      "action":      "get_histori",
      "nama_lokasi": namaLokasi,
    };
    if (tanggalMulai   != null) body["tanggal_mulai"]   = tanggalMulai;
    if (tanggalSelesai != null) body["tanggal_selesai"] = tanggalSelesai;

    final res = await http
        .post(Uri.parse(_endpoint), body: body)
        .timeout(const Duration(seconds: 20));

    final j = jsonDecode(res.body);
    if (j["status"] != true) throw Exception(j["message"] ?? "Gagal mengambil data");

    final List rawData = j["data"] ?? [];
    final list = rawData.map((e) => _BariHistori.fromJson(e)).toList();

    final ringkasanRaw = j["ringkasan"];
    final ringkasan = ringkasanRaw != null
        ? _Ringkasan.fromJson(Map<String, dynamic>.from(ringkasanRaw))
        : null;

    return (data: list, ringkasan: ringkasan, pesan: j["message"]?.toString());
  }
}

// =========================================================
// HALAMAN HISTORI USER
// =========================================================
class HistoriUserPage extends StatefulWidget {
  final String namaLokasi;
  const HistoriUserPage({super.key, this.namaLokasi = "Pilih Lokasi"});

  @override
  State<HistoriUserPage> createState() => _HistoriUserPageState();
}

class _HistoriUserPageState extends State<HistoriUserPage> {
  late String          _lokasi       = widget.namaLokasi;
  List<String>         _daftarLokasi = [];
  List<_BariHistori>   _data         = [];
  _Ringkasan?          _ringkasan;

  DateTime? _tglMulai;
  DateTime? _tglSelesai;

  bool    _loading = true;
  String? _error;

  final _cariCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _muatDaftarLokasi();
    _muatData();
  }

  @override
  void dispose() {
    _cariCtrl.dispose();
    super.dispose();
  }

  Future<void> _muatDaftarLokasi() async {
    try {
      final daftar = await _HistoriService.getDaftarLokasi();
      if (!mounted) return;
      setState(() => _daftarLokasi = daftar);
    } catch (_) {}
  }

  String _fmt(DateTime t) =>
      "${t.year}-${t.month.toString().padLeft(2,'0')}-${t.day.toString().padLeft(2,'0')}";

  Future<void> _muatData() async {
    if (_lokasi == "Pilih Lokasi") {
      setState(() { _loading = false; _data = []; _ringkasan = null; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final hasil = await _HistoriService.getHistori(
        _lokasi,
        tanggalMulai:   _tglMulai   != null ? _fmt(_tglMulai!)   : null,
        tanggalSelesai: _tglSelesai != null ? _fmt(_tglSelesai!) : null,
      );
      if (!mounted) return;
      setState(() {
        _data      = hasil.data;
        _ringkasan = hasil.ringkasan;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pilihLokasi() {
    _cariCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _T.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final cari   = _cariCtrl.text.toLowerCase();
          final daftar = _daftarLokasi
              .where((n) => n.toLowerCase().contains(cari))
              .toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: 360,
              child: Column(children: [
                const SizedBox(height: 12),
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: _T.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _cariCtrl,
                    onChanged: (_) => setModal(() {}),
                    decoration: InputDecoration(
                      hintText: "Cari lokasi...",
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _T.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: daftar.map((nama) => ListTile(
                      leading: const Icon(Icons.location_on_outlined, color: _T.abu),
                      title: Text(nama, style: const TextStyle(color: _T.hitam)),
                      trailing: nama == _lokasi
                          ? const Icon(Icons.check, color: _T.biru)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _lokasi = nama);
                        _muatData();
                      },
                    )).toList(),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pilihRentangTanggal() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _tglMulai   ?? now.subtract(const Duration(days: 6)),
        end:   _tglSelesai ?? now,
      ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _T.biru),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _tglMulai   = range.start;
        _tglSelesai = range.end;
      });
      _muatData();
    }
  }

  String _labelTanggalFilter() {
    if (_tglMulai == null && _tglSelesai == null) return "Cari Tanggal";
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    String f(DateTime t) => "${t.day} ${b[t.month - 1]}";
    if (_tglMulai != null && _tglSelesai != null) return "${f(_tglMulai!)} – ${f(_tglSelesai!)}";
    if (_tglMulai != null) return "Dari ${f(_tglMulai!)}";
    return "s/d ${f(_tglSelesai!)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _muatData,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [

        // ======== HEADER ========
        Row(children: [
          // TOMBOL BACK
          InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36, height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.08)),
                ],
              ),
              child: const Icon(Icons.arrow_back, size: 18, color: _T.hitam),
            ),
          ),
          const Spacer(),
          // LOGO TENGAH
          const Icon(Icons.air, color: _T.biru, size: 28),
          const SizedBox(width: 6),
          const Text(
            "PureAir",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _T.biru),
          ),
          const Spacer(),
          // ICON PROFIL
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.08)),
              ],
            ),
            child: IconButton(
              onPressed: () {
                // TODO: arahkan ke halaman profil
              },
              icon: const Icon(Icons.person_outline, size: 24),
            ),
          ),
        ]),

        const SizedBox(height: 20),
        const Center(
          child: Text(
            "Histori Kualitas Udara",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: _T.hitam,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ======== SEARCH + TANGGAL ========
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: _pilihLokasi,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _T.border),
                ),
                child: Row(children: [
                  const Icon(Icons.search, size: 18, color: _T.abu),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lokasi == "Pilih Lokasi" ? "Cari Lokasi" : _lokasi,
                      style: TextStyle(
                        fontSize: 14,
                        color: _lokasi == "Pilih Lokasi" ? _T.abu : _T.hitam,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _pilihRentangTanggal,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _tglMulai != null ? _T.biru : _T.border,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: _tglMulai != null ? _T.biru : _T.abu),
                const SizedBox(width: 6),
                Text(
                  _labelTanggalFilter(),
                  style: TextStyle(
                    fontSize: 12,
                    color: _tglMulai != null ? _T.biru : _T.abu,
                  ),
                ),
              ]),
            ),
          ),
        ]),

        const SizedBox(height: 20),

        if (_error != null)
          _buildError()
        else if (_lokasi == "Pilih Lokasi")
          _buildBelumPilih()
        else if (_data.isEmpty)
            _buildKosong()
          else ...[

              // ======== GRAFIK ========
              _buildGrafik(),
              const SizedBox(height: 16),

              // ======== RINGKASAN STATISTIK ========
              _buildRingkasan(),
              const SizedBox(height: 16),

              // ======== TABEL DATA POLUTAN ========
              _buildTabel(),
              const SizedBox(height: 20),

              // ======== DOWNLOAD DATA ========
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // TODO: implementasi export CSV/PDF dari _data
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: const BorderSide(color: _T.biru),
                  ),
                  child: const Text(
                    "Download Data",
                    style: TextStyle(
                      color: _T.biru,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],

      ],
    );
  }

  // ======================================================
  // SECTION: GRAFIK GARIS AQI
  // ======================================================
  Widget _buildGrafik() {
    final Map<String, List<double>> perHari = {};
    for (final row in _data) {
      final dt = DateTime.tryParse(row.waktu);
      if (dt == null) continue;
      final key = "${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}";
      perHari.putIfAbsent(key, () => []).add(row.aqi);
    }
    final tanggalUrut = perHari.keys.toList()..sort();
    final points = tanggalUrut.map((k) {
      final aqiList = perHari[k]!;
      return _TitikGrafik(
        label: _labelHariDariKey(k),
        nilai: aqiList.reduce((a, b) => a + b) / aqiList.length,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          "Grafik Historis Kualitas Udara",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: _T.hitam,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 200,
          child: CustomPaint(
            painter: _GrafikPainter(points),
            child: Container(),
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 18, height: 2, color: _T.biru),
          const SizedBox(width: 6),
          const Text("AQI", style: TextStyle(fontSize: 12, color: _T.abu)),
        ]),
      ]),
    );
  }

  String _labelHariDariKey(String key) {
    final dt = DateTime.tryParse(key);
    if (dt == null) return key;
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    return "${dt.day.toString().padLeft(2,'0')} ${b[dt.month - 1]}";
  }

  // ======================================================
  // SECTION: RINGKASAN STATISTIK (4 kotak)
  // ======================================================
  Widget _buildRingkasan() {
    final r = _ringkasan;
    if (r == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          "Ringkasan Statistik",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: _T.hitam,
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _kotakStat("${r.aqiRata.toStringAsFixed(0)}", "Rata rata AQI")),
          const SizedBox(width: 8),
          Expanded(child: _kotakStat("${r.aqiTertinggi.toStringAsFixed(0)}", "AQI Tertinggi")),
          const SizedBox(width: 8),
          Expanded(child: _kotakStat("${r.aqiTerendah.toStringAsFixed(0)}", "AQI Terendah")),
          const SizedBox(width: 8),
          Expanded(child: _kotakStat(
            r.kondisiDominan.length > 7
                ? r.kondisiDominan.split(" ").first
                : r.kondisiDominan,
            "Kondisi Dominan",
          )),
        ]),
      ]),
    );
  }

  Widget _kotakStat(String nilai, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
      ),
      child: Column(children: [
        Text(
          nilai,
          style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: _T.hitam,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: _T.abu),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  // ======================================================
  // SECTION: TABEL DATA POLUTAN
  // ======================================================
  Widget _buildTabel() {
    final Map<String, List<_BariHistori>> perHari = {};
    for (final row in _data) {
      final dt = DateTime.tryParse(row.waktu);
      if (dt == null) continue;
      final key = "${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}";
      perHari.putIfAbsent(key, () => []).add(row);
    }
    final tanggalUrut = perHari.keys.toList()..sort();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          "Data Historis Polutan",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: _T.hitam,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          "Ketuk tanggal untuk lihat detail per jam",
          style: TextStyle(fontSize: 10, color: _T.abu),
        ),
        const SizedBox(height: 10),
        _barisHeader(),
        const Divider(color: _T.border, height: 1),
        ...tanggalUrut.map((key) {
          final list = perHari[key]!
            ..sort((a, b) => a.waktu.compareTo(b.waktu));
          double rata(double Function(_BariHistori) f) =>
              list.map(f).reduce((a, b) => a + b) / list.length;

          return _barisTabelHari(
            tanggal: _labelHariDariKey(key),
            aqi:  rata((e) => e.aqi),
            pm25: rata((e) => e.pm25),
            co:   rata((e) => e.co),
            o3:   rata((e) => e.o3),
            so2:  rata((e) => e.so2),
            pm10: rata((e) => e.pm10),
            jamList: list,
          );
        }),
      ]),
    );
  }

  Widget _barisHeader() {
    const s = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _T.abu);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: const [
        Expanded(flex: 3, child: Text("Tanggal", style: s)),
        Expanded(flex: 2, child: Text("AQI",   style: s, textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text("PM2.5", style: s, textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text("CO",    style: s, textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text("O3",    style: s, textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text("SO",    style: s, textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text("PM10",  style: s, textAlign: TextAlign.center)),
        SizedBox(width: 20),
      ]),
    );
  }

  // Baris tanggal yang bisa diketuk untuk membuka detail per jam
  Widget _barisTabelHari({
    required String tanggal,
    required double aqi,
    required double pm25,
    required double co,
    required double o3,
    required double so2,
    required double pm10,
    required List<_BariHistori> jamList,
  }) {
    final info = _kategoriAqi(aqi);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        collapsedIconColor: _T.abu,
        iconColor: _T.biru,
        title: Row(children: [
          Expanded(flex: 3,
              child: Text(tanggal,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _T.hitam))),
          Expanded(flex: 2,
              child: Text(aqi.toStringAsFixed(0),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: info.warna),
                  textAlign: TextAlign.center)),
          Expanded(flex: 2,
              child: Text(pm25.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 11, color: _T.hitam),
                  textAlign: TextAlign.center)),
          Expanded(flex: 2,
              child: Text(co.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 11, color: _T.hitam),
                  textAlign: TextAlign.center)),
          Expanded(flex: 2,
              child: Text(o3.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 11, color: _T.hitam),
                  textAlign: TextAlign.center)),
          Expanded(flex: 2,
              child: Text(so2.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 11, color: _T.hitam),
                  textAlign: TextAlign.center)),
          Expanded(flex: 2,
              child: Text(pm10.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 11, color: _T.hitam),
                  textAlign: TextAlign.center)),
        ]),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            decoration: const BoxDecoration(color: Color(0xFFFAFAFA)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: const [
                  Expanded(flex: 3, child: Text("Jam",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _T.abu))),
                  Expanded(flex: 2, child: Text("AQI",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _T.abu),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("PM2.5",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _T.abu),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("CO",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _T.abu),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("O3",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _T.abu),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("SO",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _T.abu),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("PM10",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _T.abu),
                      textAlign: TextAlign.center)),
                ]),
              ),
              const Divider(color: _T.border, height: 1),
              ...jamList.map((row) => _barisJam(row)),
            ]),
          ),
        ],
      ),
    );
  }

  // Baris detail per jam (muncul saat tanggal diketuk/expand)
  Widget _barisJam(_BariHistori row) {
    final dt  = DateTime.tryParse(row.waktu);
    final jam = dt != null
        ? "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}"
        : "-";
    final info = _kategoriAqi(row.aqi);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 3,
            child: Text(jam, style: const TextStyle(fontSize: 11, color: _T.hitam))),
        Expanded(flex: 2,
            child: Text(row.aqi.toStringAsFixed(0),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: info.warna),
                textAlign: TextAlign.center)),
        Expanded(flex: 2,
            child: Text(row.pm25.toStringAsFixed(1),
                style: const TextStyle(fontSize: 11, color: _T.hitam),
                textAlign: TextAlign.center)),
        Expanded(flex: 2,
            child: Text(row.co.toStringAsFixed(1),
                style: const TextStyle(fontSize: 11, color: _T.hitam),
                textAlign: TextAlign.center)),
        Expanded(flex: 2,
            child: Text(row.o3.toStringAsFixed(0),
                style: const TextStyle(fontSize: 11, color: _T.hitam),
                textAlign: TextAlign.center)),
        Expanded(flex: 2,
            child: Text(row.so2.toStringAsFixed(0),
                style: const TextStyle(fontSize: 11, color: _T.hitam),
                textAlign: TextAlign.center)),
        Expanded(flex: 2,
            child: Text(row.pm10.toStringAsFixed(0),
                style: const TextStyle(fontSize: 11, color: _T.hitam),
                textAlign: TextAlign.center)),
      ]),
    );
  }

  // ======================================================
  // STATE KOSONG / ERROR
  // ======================================================
  Widget _buildBelumPilih() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
      ),
      child: const Text(
        "Pilih lokasi untuk melihat histori",
        style: TextStyle(color: _T.abu, fontSize: 13),
      ),
    );
  }

  Widget _buildKosong() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
      ),
      child: Column(children: [
        const Icon(Icons.bar_chart, size: 40, color: _T.abu),
        const SizedBox(height: 8),
        const Text(
          "Tidak ada data pada rentang tanggal ini",
          style: TextStyle(color: _T.abu, fontSize: 13),
        ),
        if (_tglMulai != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() { _tglMulai = null; _tglSelesai = null; });
              _muatData();
            },
            child: const Text("Reset filter tanggal"),
          ),
        ],
      ]),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.border),
      ),
      child: Column(children: [
        const Icon(Icons.cloud_off, size: 36, color: _T.abu),
        const SizedBox(height: 8),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _T.abu, fontSize: 13),
        ),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _muatData, child: const Text("Coba lagi")),
      ]),
    );
  }
}

// =========================================================
// DATA TITIK GRAFIK
// =========================================================
class _TitikGrafik {
  final String label;
  final double nilai;
  _TitikGrafik({required this.label, required this.nilai});
}

// =========================================================
// CUSTOM PAINTER -- GRAFIK GARIS AQI
// =========================================================
class _GrafikPainter extends CustomPainter {
  final List<_TitikGrafik> points;
  _GrafikPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final nilai  = points.map((e) => e.nilai).toList();
    final maxV   = (nilai.reduce(math.max) * 1.15).ceilToDouble();
    const minV   = 0.0;
    final range  = (maxV - minV).clamp(1, double.infinity);

    const paddingLeft   = 32.0;
    const paddingBottom = 24.0;
    const paddingTop    = 12.0;

    final chartW = size.width  - paddingLeft;
    final chartH = size.height - paddingBottom - paddingTop;
    final stepX  = points.length > 1 ? chartW / (points.length - 1) : chartW;

    // ---- Sumbu Y: garis putus-putus + label ----
    final gridPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1;
    const labelStyleY = TextStyle(color: _T.abu, fontSize: 9);

    for (int i = 0; i <= 3; i++) {
      final v = (maxV * i / 3).round();
      final y = paddingTop + chartH - (v / range * chartH);
      double x = paddingLeft;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width), y),
          gridPaint,
        );
        x += 7;
      }
      final tp = TextPainter(
        text: TextSpan(text: "$v", style: labelStyleY),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // ---- Path garis + fill ----
    final linePaint = Paint()
      ..color = _T.biru
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_T.biru.withOpacity(0.2), _T.biru.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(paddingLeft, paddingTop, chartW, chartH));

    final path = Path(), fillPath = Path();
    final offsets = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final x = paddingLeft + i * stepX;
      final y = paddingTop + chartH - ((nilai[i] - minV) / range * chartH);
      offsets.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, paddingTop + chartH);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(offsets.last.dx, paddingTop + chartH);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // ---- Titik + nilai di atas titik + label tanggal ----
    final dotPaint  = Paint()..color = _T.biru;
    const styleVal  = TextStyle(color: _T.biru, fontSize: 9, fontWeight: FontWeight.w700);
    const styleTgl  = TextStyle(color: _T.abu,  fontSize: 9);

    for (int i = 0; i < offsets.length; i++) {
      final p = offsets[i];

      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, Paint()
        ..color = _T.biru
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      canvas.drawCircle(p, 2.5, dotPaint);

      final tvAqi = TextPainter(
        text: TextSpan(text: "${nilai[i].round()}", style: styleVal),
        textDirection: TextDirection.ltr,
      )..layout();
      tvAqi.paint(canvas, Offset(p.dx - tvAqi.width / 2, p.dy - tvAqi.height - 4));

      final tvTgl = TextPainter(
        text: TextSpan(text: points[i].label, style: styleTgl),
        textDirection: TextDirection.ltr,
      )..layout();
      tvTgl.paint(canvas, Offset(p.dx - tvTgl.width / 2, paddingTop + chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _GrafikPainter old) => old.points != points;
}