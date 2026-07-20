import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/session.dart';
import '../../services/users.dart';

// =========================================================
// WARNA TEMA (terang) -- DISAMAKAN dengan gaya halaman Prediksi
// (_Tema) supaya seluruh halaman user (Peta/Histori/Prediksi)
// punya identitas visual yang konsisten.
// =========================================================
class _Tema {
  static const bg         = Color(0xFFF5F5F5);
  static const card       = Colors.white;
  static const cardBorder = Color(0xFFE0E0E0);
  static const teksAbu    = Color(0xFF8A8A8E);
  static const teksHitam  = Color(0xFF1C1C1E);
  static const aksen      = Color(0xFF2F80ED); // biru, selaras "PureAir"
  static const kuning     = Color(0xFFFFC107);

  static List<BoxShadow> shadowKartu = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> shadowTipis = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 5,
      offset: const Offset(0, 2),
    ),
  ];
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

  // ---- Favorit KHUSUS histori: tabel `favorit_histori` di server,
  //      terpisah dari `favorit_lokasi` yang dipakai halaman Peta ----

  static Future<({bool isFavorit, int? monitoringId})> cekFavorit(
      String namaLokasi, {
        required int userId,
      }) async {
    if (userId <= 0) return (isFavorit: false, monitoringId: null);
    final res = await http
        .post(Uri.parse(_endpoint), body: {
      "action": "cek_favorit",
      "nama_lokasi": namaLokasi,
      "user_id": userId.toString(),
    })
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body);
    if (body["status"] != true) return (isFavorit: false, monitoringId: null);
    return (
    isFavorit: body["is_favorit"] == true,
    monitoringId: body["monitoring_id"] != null
        ? int.tryParse(body["monitoring_id"].toString())
        : null,
    );
  }

  static Future<bool> toggleFavorit(
      String namaLokasi, {
        required int userId,
      }) async {
    final res = await http
        .post(Uri.parse(_endpoint), body: {
      "action": "toggle_favorit",
      "nama_lokasi": namaLokasi,
      "user_id": userId.toString(),
    })
        .timeout(const Duration(seconds: 15));
    final body = jsonDecode(res.body);
    if (body["status"] != true) {
      throw Exception(body["message"] ?? "Gagal mengubah status favorit");
    }
    return body["is_favorit"] == true;
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

  // TAMBAHAN: state untuk tombol favorit (mirip halaman Peta/Prediksi)
  int  _userId        = 0; // 0 = belum login
  bool _isFavorit      = false;
  bool _favoritLoading = false;

  // TAMBAHAN: foto profil user, diambil dari Session supaya
  // avatar di header menampilkan foto asli, bukan placeholder.
  String? _fotoUrl;

  final _cariCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _muatUserId();
    await _muatDaftarLokasi();
    await _muatData();
  }

  Future<void> _muatUserId() async {
    final id   = await Session.getUserId();
    final foto = await Session.getFotoUrl();
    if (mounted) {
      setState(() {
        _userId  = id;
        _fotoUrl = foto;
      });
    }
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
      setState(() {
        _loading = false;
        _data = [];
        _ringkasan = null;
        _isFavorit = false;
      });
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
      _cekFavoritStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // TAMBAHAN: cek status favorit lokasi yang sedang dipilih,
  // dipanggil tiap kali lokasi berganti / data berhasil dimuat.
  Future<void> _cekFavoritStatus() async {
    if (_userId <= 0 || _lokasi == "Pilih Lokasi") {
      if (mounted) setState(() => _isFavorit = false);
      return;
    }
    try {
      final hasil = await _HistoriService.cekFavorit(_lokasi, userId: _userId);
      if (!mounted) return;
      setState(() => _isFavorit = hasil.isFavorit);
    } catch (_) {
      // Diamkan -- jangan ganggu tampilan histori kalau cek favorit gagal
    }
  }

  // TAMBAHAN: toggle favorit dengan optimistic update, sama polanya
  // dengan halaman Peta & Prediksi.
  Future<void> _toggleFavorit() async {
    if (_userId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan login ulang untuk memakai fitur favorit")),
      );
      return;
    }
    if (_lokasi == "Pilih Lokasi" || _favoritLoading) return;

    final sebelum = _isFavorit;
    setState(() {
      _isFavorit = !_isFavorit;
      _favoritLoading = true;
    });
    try {
      final hasilBaru = await _HistoriService.toggleFavorit(_lokasi, userId: _userId);
      if (!mounted) return;
      setState(() => _isFavorit = hasilBaru);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFavorit = sebelum); // rollback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _favoritLoading = false);
    }
  }

  void _pilihLokasi() {
    _cariCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _Tema.card,
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
              height: 380,
              child: Column(children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _Tema.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Pilih Lokasi",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _Tema.teksHitam),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _Tema.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _Tema.cardBorder),
                    ),
                    child: TextField(
                      controller: _cariCtrl,
                      onChanged: (_) => setModal(() {}),
                      cursorColor: _Tema.aksen,
                      decoration: const InputDecoration(
                        hintText: "Cari lokasi...",
                        prefixIcon: Icon(Icons.search, size: 18, color: _Tema.teksAbu),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: daftar.isEmpty
                      ? const Center(
                    child: Text("Lokasi tidak ditemukan",
                        style: TextStyle(color: _Tema.teksAbu, fontSize: 12.5)),
                  )
                      : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: daftar.map((nama) {
                      final aktif = nama == _lokasi;
                      return ListTile(
                        leading: Icon(Icons.location_on_outlined,
                            color: aktif ? _Tema.aksen : _Tema.teksAbu),
                        title: Text(nama,
                            style: TextStyle(
                              color: _Tema.teksHitam,
                              fontWeight: aktif ? FontWeight.w700 : FontWeight.w400,
                            )),
                        trailing: aktif
                            ? const Icon(Icons.check_circle, color: _Tema.aksen, size: 20)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _lokasi = nama);
                          _muatData();
                        },
                      );
                    }).toList(),
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
          colorScheme: const ColorScheme.light(
            primary: _Tema.aksen,
            onPrimary: Colors.white,
            onSurface: _Tema.teksHitam,
          ),
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
      backgroundColor: _Tema.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildJudul(),
            Expanded(
              child: RefreshIndicator(
                color: _Tema.aksen,
                onRefresh: _muatData,
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: _Tema.aksen))
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

  // -------------------------------------------------------
  // HEADER & JUDUL -- gaya disamakan dengan halaman Prediksi
  // -------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: _Tema.bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(20),
          child: const Icon(Icons.arrow_back, size: 22, color: _Tema.teksHitam),
        ),
        const Spacer(),
        // Logo asli PureAir (icon + text)
        Row(children: [
          Image.asset(
            'assets/logo/pureair_logo_icon.png',
            width: 28,
            height: 28,
          ),
          const SizedBox(width: 6),
          Image.asset(
            'assets/logo/pureair_logo_text.png',
            height: 18,
            fit: BoxFit.fitHeight,
          ),
        ]),
        const Spacer(),
        // Avatar -- menampilkan foto profil asli user (dari Session),
        // fallback ke ikon polos kalau belum ada foto / gagal dimuat.
        GestureDetector(
          onTap: () {
            // TODO: arahkan ke halaman profil
          },
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _Tema.cardBorder),
              boxShadow: _Tema.shadowTipis,
            ),
            child: ClipOval(
              child: (_fotoUrl != null && _fotoUrl!.isNotEmpty)
                  ? Image.network(
                _fotoUrl!,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.person_outline, size: 18, color: _Tema.teksHitam),
              )
                  : const Icon(Icons.person_outline, size: 18, color: _Tema.teksHitam),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildJudul() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Center(
        child: Text(
          "Histori Kualitas Udara",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: _Tema.teksHitam,
          ),
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
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _Tema.teksAbu)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _muatData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _Tema.aksen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Coba lagi"),
          ),
        ]),
      ),
    ]);
  }

  // -------------------------------------------------------
  // KONTEN UTAMA
  // -------------------------------------------------------
  Widget _buildKonten() {
    return ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
      _buildBarisPencarian(),
      const SizedBox(height: 14),
      if (_lokasi == "Pilih Lokasi")
        _buildBelumPilih()
      else if (_data.isEmpty)
        _buildKosong()
      else ...[
          _buildGrafik(),
          const SizedBox(height: 14),
          _buildRingkasan(),
          const SizedBox(height: 14),
          _buildTabel(),
          const SizedBox(height: 14),
          _buildTombolUnduh(),
        ],
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildBarisPencarian() {
    return Row(children: [
      Expanded(
        child: InkWell(
          onTap: _pilihLokasi,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: _Tema.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _Tema.cardBorder),
              boxShadow: _Tema.shadowTipis,
            ),
            child: Row(children: [
              const Icon(Icons.search, size: 16, color: _Tema.teksAbu),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _lokasi == "Pilih Lokasi" ? "Cari Lokasi" : _lokasi,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _lokasi == "Pilih Lokasi" ? _Tema.teksAbu : _Tema.teksHitam,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: InkWell(
          onTap: _pilihRentangTanggal,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: _Tema.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _Tema.cardBorder),
              boxShadow: _Tema.shadowTipis,
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 15, color: _Tema.teksAbu),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _labelTanggalFilter(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _tglMulai == null ? _Tema.teksAbu : _Tema.teksHitam,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
      // TAMBAHAN: tombol favorit, cuma muncul kalau lokasi sudah dipilih
      // -- gaya disamakan dengan halaman Prediksi.
      if (_lokasi != "Pilih Lokasi") ...[
        const SizedBox(width: 10),
        _buildFavoritButton(),
      ],
    ]);
  }

  // TAMBAHAN: tombol bulat ikon hati, gaya AnimatedContainer sama
  // seperti halaman Prediksi.
  Widget _buildFavoritButton() {
    return GestureDetector(
      onTap: _favoritLoading ? null : _toggleFavorit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _Tema.card,
          shape: BoxShape.circle,
          border: Border.all(
            color: _isFavorit ? Colors.redAccent : _Tema.cardBorder,
            width: _isFavorit ? 1.4 : 1,
          ),
          boxShadow: _Tema.shadowTipis,
        ),
        child: _favoritLoading
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: _Tema.aksen),
        )
            : Icon(
          _isFavorit ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: _isFavorit ? Colors.redAccent : _Tema.teksAbu,
        ),
      ),
    );
  }

  Widget _buildBelumPilih() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.cardBorder),
        boxShadow: _Tema.shadowKartu,
      ),
      child: Column(children: [
        Icon(Icons.location_searching, size: 34, color: _Tema.teksAbu.withOpacity(0.6)),
        const SizedBox(height: 10),
        const Text(
          "Pilih lokasi terlebih dahulu untuk\nmelihat histori kualitas udara.",
          textAlign: TextAlign.center,
          style: TextStyle(color: _Tema.teksAbu, fontSize: 13),
        ),
      ]),
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
        boxShadow: _Tema.shadowKartu,
      ),
      child: Column(children: [
        Icon(Icons.inbox_outlined, size: 34, color: _Tema.teksAbu.withOpacity(0.6)),
        const SizedBox(height: 10),
        const Text(
          "Tidak ada data pada rentang\ntanggal ini.",
          textAlign: TextAlign.center,
          style: TextStyle(color: _Tema.teksAbu, fontSize: 13),
        ),
        if (_tglMulai != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() { _tglMulai = null; _tglSelesai = null; });
              _muatData();
            },
            style: TextButton.styleFrom(foregroundColor: _Tema.aksen),
            child: const Text("Reset filter tanggal", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.cardBorder),
        boxShadow: _Tema.shadowKartu,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Grafik Historis Kualitas Udara",
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: CustomPaint(
            painter: _GrafikPainter(points),
            child: Container(),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 10, height: 10,
              decoration: const BoxDecoration(color: _Tema.aksen, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text("AQI",
              style: TextStyle(fontSize: 11, color: _Tema.teksAbu, fontWeight: FontWeight.w500)),
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

    final infoRata = _kategoriAqi(r.aqiRata);
    final infoTinggi = _kategoriAqi(r.aqiTertinggi);
    final infoRendah = _kategoriAqi(r.aqiTerendah);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.cardBorder),
        boxShadow: _Tema.shadowKartu,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Ringkasan Statistik",
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _kotakStat("${r.aqiRata.toStringAsFixed(0)}", "Rata rata AQI", warna: infoRata.warna)),
          const SizedBox(width: 8),
          Expanded(child: _kotakStat("${r.aqiTertinggi.toStringAsFixed(0)}", "AQI Tertinggi", warna: infoTinggi.warna)),
          const SizedBox(width: 8),
          Expanded(child: _kotakStat("${r.aqiTerendah.toStringAsFixed(0)}", "AQI Terendah", warna: infoRendah.warna)),
          const SizedBox(width: 8),
          Expanded(child: _kotakStat(
            r.kondisiDominan.length > 7
                ? r.kondisiDominan.split(" ").first
                : r.kondisiDominan,
            "Kondisi Dominan",
            warna: _Tema.aksen,
          )),
        ]),
      ]),
    );
  }

  Widget _kotakStat(String nilai, String label, {required Color warna}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: _Tema.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(children: [
        Text(
          nilai,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: warna),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: _Tema.teksAbu, fontWeight: FontWeight.w600),
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.cardBorder),
        boxShadow: _Tema.shadowKartu,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Data Historis Polutan",
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
        const SizedBox(height: 2),
        const Text(
          "Ketuk tanggal untuk lihat detail per jam",
          style: TextStyle(fontSize: 10, color: _Tema.teksAbu),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _Tema.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _barisHeader(),
        ),
        const SizedBox(height: 4),
        ...List.generate(tanggalUrut.length, (i) {
          final key = tanggalUrut[i];
          final list = perHari[key]!
            ..sort((a, b) => a.waktu.compareTo(b.waktu));
          double rata(double Function(_BariHistori) f) =>
              list.map(f).reduce((a, b) => a + b) / list.length;

          return Container(
            decoration: BoxDecoration(
              color: i.isEven ? Colors.transparent : _Tema.bg.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.only(bottom: 2),
            child: _barisTabelHari(
              tanggal: _labelHariDariKey(key),
              aqi:  rata((e) => e.aqi),
              pm25: rata((e) => e.pm25),
              co:   rata((e) => e.co),
              o3:   rata((e) => e.o3),
              so2:  rata((e) => e.so2),
              pm10: rata((e) => e.pm10),
              jamList: list,
            ),
          );
        }),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _barisHeader() {
    const s = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _Tema.teksAbu);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
        tilePadding: const EdgeInsets.symmetric(horizontal: 6),
        childrenPadding: EdgeInsets.zero,
        collapsedIconColor: _Tema.teksAbu,
        iconColor: _Tema.aksen,
        title: Row(children: [
          Expanded(flex: 3,
              child: Row(children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: info.warna),
                ),
                Flexible(
                  child: Text(tanggal,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _Tema.teksHitam)),
                ),
              ])),
          Expanded(flex: 2,
              child: Text(aqi.toStringAsFixed(0),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: info.warna),
                  textAlign: TextAlign.center)),
          Expanded(flex: 2,
              child: Text(pm25.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 11, color: _Tema.teksHitam),
                  textAlign: TextAlign.center)),
          Expanded(flex: 2,
              child: Text(co.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 11, color: _Tema.teksHitam),
                  textAlign: TextAlign.center)),
          Expanded(flex: 2,
              child: Text(o3.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 11, color: _Tema.teksHitam),
                  textAlign: TextAlign.center)),
          Expanded(flex: 2,
              child: Text(so2.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 11, color: _Tema.teksHitam),
                  textAlign: TextAlign.center)),
          Expanded(flex: 2,
              child: Text(pm10.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 11, color: _Tema.teksHitam),
                  textAlign: TextAlign.center)),
        ]),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: _Tema.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: const [
                  Expanded(flex: 3, child: Text("Jam",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _Tema.teksAbu))),
                  Expanded(flex: 2, child: Text("AQI",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _Tema.teksAbu),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("PM2.5",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _Tema.teksAbu),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("CO",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _Tema.teksAbu),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("O3",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _Tema.teksAbu),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("SO",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _Tema.teksAbu),
                      textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text("PM10",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _Tema.teksAbu),
                      textAlign: TextAlign.center)),
                ]),
              ),
              Divider(color: _Tema.cardBorder, height: 1),
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
            child: Text(jam, style: const TextStyle(fontSize: 11, color: _Tema.teksHitam))),
        Expanded(flex: 2,
            child: Text(row.aqi.toStringAsFixed(0),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: info.warna),
                textAlign: TextAlign.center)),
        Expanded(flex: 2,
            child: Text(row.pm25.toStringAsFixed(1),
                style: const TextStyle(fontSize: 11, color: _Tema.teksHitam),
                textAlign: TextAlign.center)),
        Expanded(flex: 2,
            child: Text(row.co.toStringAsFixed(1),
                style: const TextStyle(fontSize: 11, color: _Tema.teksHitam),
                textAlign: TextAlign.center)),
        Expanded(flex: 2,
            child: Text(row.o3.toStringAsFixed(0),
                style: const TextStyle(fontSize: 11, color: _Tema.teksHitam),
                textAlign: TextAlign.center)),
        Expanded(flex: 2,
            child: Text(row.so2.toStringAsFixed(0),
                style: const TextStyle(fontSize: 11, color: _Tema.teksHitam),
                textAlign: TextAlign.center)),
        Expanded(flex: 2,
            child: Text(row.pm10.toStringAsFixed(0),
                style: const TextStyle(fontSize: 11, color: _Tema.teksHitam),
                textAlign: TextAlign.center)),
      ]),
    );
  }

  // ======================================================
  // TOMBOL UNDUH -- gaya OutlinedButton disamakan dgn Prediksi
  // ======================================================
  Widget _buildTombolUnduh() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          // TODO: implementasi export CSV/PDF dari _data
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: _Tema.card,
          side: const BorderSide(color: _Tema.aksen, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_rounded, size: 17, color: _Tema.aksen),
            SizedBox(width: 8),
            Text(
              "Download Data",
              style: TextStyle(color: _Tema.aksen, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
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
      ..color = _Tema.cardBorder
      ..strokeWidth = 1;
    const labelStyleY = TextStyle(color: _Tema.teksAbu, fontSize: 9);

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
      ..color = _Tema.aksen
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_Tema.aksen.withOpacity(0.22), _Tema.aksen.withOpacity(0.0)],
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
    final dotPaint  = Paint()..color = _Tema.aksen;
    const styleVal  = TextStyle(color: _Tema.aksen, fontSize: 9, fontWeight: FontWeight.w700);
    const styleTgl  = TextStyle(color: _Tema.teksAbu,  fontSize: 9);

    for (int i = 0; i < offsets.length; i++) {
      final p = offsets[i];

      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, Paint()
        ..color = _Tema.aksen
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