import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/session.dart';
import '../../services/users.dart';

// =========================================================
// TEMA -- selaras dengan gaya halaman Prediksi (flat, shadow
// lembut standar, card berbasis border + shadow tipis).
// =========================================================
class _T {
  static const bg         = Color(0xFFF5F5F5);
  static const card       = Colors.white;
  static const border     = Color(0xFFE0E0E0);
  static const abu        = Color(0xFF8A8A8E);
  static const hitam      = Color(0xFF1C1C1E);
  static const biru       = Color(0xFF2F80ED);

  // TAMBAHAN: shadow standar mengikuti gaya kartu di halaman
  // Prediksi, supaya kartu tidak terasa flat tapi tetap ringan.
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
// EXCEPTION khusus untuk error dari layer API, supaya pesan
// yang sampai ke UI selalu jelas & konsisten (bukan pesan
// mentah seperti FormatException / SocketException dsb).
// =========================================================
class _ApiException implements Exception {
  final String message;
  _ApiException(this.message);
  @override
  String toString() => message;
}

// =========================================================
// MODEL: 1 item favorit dari halaman Peta (data lengkap,
// karena favorit_list di user_peta.php JOIN ke tabel `lokasi`
// yang memang menyimpan nilai AQI/polutan terkini)
// =========================================================
class _FavoritPeta {
  final int    id; // lokasi.id
  final String nama;
  final double aqi;
  final double? pm25, pm10, co, no2, so2, o3;
  final String updateTerakhir;

  _FavoritPeta({
    required this.id,
    required this.nama,
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.co,
    required this.no2,
    required this.so2,
    required this.o3,
    required this.updateTerakhir,
  });

  factory _FavoritPeta.fromJson(Map<String, dynamic> j) {
    double? d(String k) => j[k] != null ? double.tryParse(j[k].toString()) : null;
    return _FavoritPeta(
      // DIUBAH: int.parse -> int.tryParse + fallback 0, supaya satu
      // baris data yang cacat (mis. id null/kosong dari server) tidak
      // menjatuhkan seluruh daftar favorit Peta.
      id: int.tryParse((j["id"] ?? "").toString()) ?? 0,
      nama: (j["nama"] ?? "").toString(),
      aqi: double.tryParse((j["aqi"] ?? "0").toString()) ?? 0,
      pm25: d("pm25"),
      pm10: d("pm10"),
      co:   d("co"),
      no2:  d("no2"),
      so2:  d("so2"),
      o3:   d("o3"),
      updateTerakhir: (j["update_terakhir"] ?? "-").toString(),
    );
  }
}

// =========================================================
// MODEL: 1 item favorit dari Histori / Prediksi (cuma nama
// lokasi + monitoring_id -- detail lengkapnya di-fetch belakangan
// saat kartu di-tap, lewat get_histori / get_prediksi)
// =========================================================
class _FavoritMonitoring {
  final int    monitoringId;
  final String namaLokasi;

  _FavoritMonitoring({required this.monitoringId, required this.namaLokasi});

  factory _FavoritMonitoring.fromJson(Map<String, dynamic> j) {
    return _FavoritMonitoring(
      monitoringId: int.tryParse((j["monitoring_id"] ?? "0").toString()) ?? 0,
      namaLokasi: (j["nama_lokasi"] ?? "").toString(),
    );
  }
}

// =========================================================
// SERVICE -- ambil & toggle favorit dari 3 endpoint yang
// terpisah (user_peta.php, user_history.php, user_prediksi.php),
// plus ambil detail on-demand saat kartu di-tap.
//
// DIUBAH: seluruh request sekarang lewat satu helper `_post`
// supaya: (1) status code HTTP ikut dicek -- sebelumnya server
// error 4xx/5xx tetap lolos ke jsonDecode dan gagal secara
// membingungkan; (2) body yang bukan JSON valid ditangkap rapi;
// (3) pesan error konsisten di semua endpoint. Ini juga
// menghapus duplikasi try/timeout/jsonDecode yang sebelumnya
// diulang di 8 method berbeda.
// =========================================================
class _TersimpanService {
  static const String _endpointPeta     = "${ApiService.baseUrl}/user/user_peta.php";
  static const String _endpointHistori  = "${ApiService.baseUrl}/user/user_history.php";
  static const String _endpointPrediksi = "${ApiService.baseUrl}/user/user_prediksi.php";

  static Future<Map<String, dynamic>> _post(
      String url,
      Map<String, String> body, {
        int timeoutSeconds = 15,
      }) async {
    http.Response res;
    try {
      res = await http
          .post(Uri.parse(url), body: body)
          .timeout(Duration(seconds: timeoutSeconds));
    } on TimeoutException {
      throw _ApiException("Waktu tunggu habis, periksa koneksi internet kamu");
    } catch (_) {
      throw _ApiException("Gagal terhubung ke server");
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _ApiException("Server bermasalah (kode ${res.statusCode})");
    }

    Map<String, dynamic> decoded;
    try {
      decoded = Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (_) {
      throw _ApiException("Respons server tidak valid");
    }

    if (decoded["status"] != true) {
      throw _ApiException((decoded["message"] ?? "Terjadi kesalahan").toString());
    }
    return decoded;
  }

  static Future<List<_FavoritPeta>> listPeta({required int userId}) async {
    if (userId <= 0) return [];
    final body = await _post(_endpointPeta, {
      "action": "favorit_list",
      "user_id": userId.toString(),
    });
    final List data = body["data"] ?? [];
    return data.map((e) => _FavoritPeta.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<List<_FavoritMonitoring>> listHistori({required int userId}) async {
    if (userId <= 0) return [];
    final body = await _post(_endpointHistori, {
      "action": "favorit_list",
      "user_id": userId.toString(),
    });
    final List data = body["data"] ?? [];
    return data.map((e) => _FavoritMonitoring.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<List<_FavoritMonitoring>> listPrediksi({required int userId}) async {
    if (userId <= 0) return [];
    final body = await _post(_endpointPrediksi, {
      "action": "favorit_list",
      "user_id": userId.toString(),
    });
    final List data = body["data"] ?? [];
    return data.map((e) => _FavoritMonitoring.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> hapusFavoritPeta(int lokasiId, {required int userId}) {
    return _post(_endpointPeta, {
      "action": "favorit_hapus",
      "lokasi_id": lokasiId.toString(),
      "user_id": userId.toString(),
    });
  }

  static Future<void> hapusFavoritHistori(String namaLokasi, {required int userId}) {
    return _post(_endpointHistori, {
      "action": "toggle_favorit",
      "nama_lokasi": namaLokasi,
      "user_id": userId.toString(),
    });
  }

  static Future<void> hapusFavoritPrediksi(String namaLokasi, {required int userId}) {
    return _post(_endpointPrediksi, {
      "action": "toggle_favorit",
      "nama_lokasi": namaLokasi,
      "user_id": userId.toString(),
    });
  }

  // ---- Detail on-demand (dipanggil saat kartu Histori/Prediksi
  //      di-tap, supaya halaman Tersimpan tidak perlu bergantung
  //      pada halaman Histori/Prediksi sama sekali) ----

  static Future<Map<String, dynamic>> ambilRingkasanHistori(String namaLokasi) {
    return _post(
      _endpointHistori,
      {"action": "get_histori", "nama_lokasi": namaLokasi},
      timeoutSeconds: 20,
    );
  }

  static Future<Map<String, dynamic>> ambilRingkasanPrediksi(String namaLokasi) {
    return _post(
      _endpointPrediksi,
      {"action": "get_prediksi", "nama_lokasi": namaLokasi},
      timeoutSeconds: 20,
    );
  }
}

// =========================================================
// HALAMAN TERSIMPAN -- gabungan favorit Peta / Histori / Prediksi.
// Detail ditampilkan langsung di halaman ini (bottom sheet) saat
// kartu di-tap, tidak berpindah ke halaman lain.
//
// Detail Histori & Prediksi berupa GRAFIK AQI:
// - Histori  -> grafik 7 hari TERAKHIR (ke belakang dari hari ini)
// - Prediksi -> grafik 7 hari SETELAHNYA (ke depan dari sekarang)
// Data mentahnya sudah tersedia di response get_histori/get_prediksi
// (field "data"), jadi cukup diagregasi per-hari di sisi Flutter --
// tidak perlu endpoint baru di backend.
// =========================================================
class TersimpanPage extends StatefulWidget {
  const TersimpanPage({super.key});

  @override
  State<TersimpanPage> createState() => _TersimpanPageState();
}

class _TersimpanPageState extends State<TersimpanPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int _userId = 0;

  // TAMBAHAN: foto profil user, diambil dari Session supaya avatar
  // di header menampilkan foto asli, bukan placeholder.
  String? _fotoUrl;

  List<_FavoritPeta>        _peta     = [];
  List<_FavoritMonitoring>   _histori  = [];
  List<_FavoritMonitoring>   _prediksi = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final id   = await Session.getUserId();
    final foto = await Session.getFotoUrl();
    if (mounted) {
      setState(() {
        _userId  = id;
        _fotoUrl = foto;
      });
    }
    await _muatSemua();
  }

  Future<void> _muatSemua() async {
    if (_userId <= 0) {
      setState(() {
        _loading = false;
        _error = "Silakan login ulang untuk melihat data tersimpan";
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final hasil = await Future.wait([
        _TersimpanService.listPeta(userId: _userId),
        _TersimpanService.listHistori(userId: _userId),
        _TersimpanService.listPrediksi(userId: _userId),
      ]);
      if (!mounted) return;
      setState(() {
        _peta     = hasil[0] as List<_FavoritPeta>;
        _histori  = hasil[1] as List<_FavoritMonitoring>;
        _prediksi = hasil[2] as List<_FavoritMonitoring>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _hapusPeta(_FavoritPeta item) async {
    final salinan = List<_FavoritPeta>.from(_peta);
    setState(() => _peta.removeWhere((e) => e.id == item.id));
    try {
      await _TersimpanService.hapusFavoritPeta(item.id, userId: _userId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _peta = salinan); // rollback
      _tampilkanError(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _hapusHistori(_FavoritMonitoring item) async {
    final salinan = List<_FavoritMonitoring>.from(_histori);
    setState(() => _histori.removeWhere((e) => e.monitoringId == item.monitoringId));
    try {
      await _TersimpanService.hapusFavoritHistori(item.namaLokasi, userId: _userId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _histori = salinan); // rollback
      _tampilkanError(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _hapusPrediksi(_FavoritMonitoring item) async {
    final salinan = List<_FavoritMonitoring>.from(_prediksi);
    setState(() => _prediksi.removeWhere((e) => e.monitoringId == item.monitoringId));
    try {
      await _TersimpanService.hapusFavoritPrediksi(item.namaLokasi, userId: _userId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _prediksi = salinan); // rollback
      _tampilkanError(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  void _tampilkanError(String pesan) {
    if (!mounted) return;
    // DIUBAH: hideCurrentSnackBar() dulu supaya kalau user hapus
    // beberapa item berturut-turut dengan cepat, snackbar tidak
    // menumpuk di antrean dan menutupi konten.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  // TAMBAHAN: dialog konfirmasi kecil sebelum benar-benar menghapus
  // favorit -- supaya tap ikon hati yang tidak sengaja tidak langsung
  // menghilangkan data tersimpan pengguna.
  Future<bool> _konfirmasiHapus(String namaLokasi) async {
    final hasil = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus dari favorit?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          "\"$namaLokasi\" akan dihapus dari daftar tersimpan kamu.",
          style: const TextStyle(fontSize: 13.5, color: _T.abu),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal", style: TextStyle(color: _T.abu)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return hasil ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildJudul(),
          _buildTabBar(),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _T.biru))
                : _error != null
                ? _buildError()
                : RefreshIndicator(
              color: _T.biru,
              onRefresh: _muatSemua,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDaftarPeta(),
                  _buildDaftarHistori(),
                  _buildDaftarPrediksi(),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // -------------------------------------------------------
  // HEADER, JUDUL & TAB BAR -- mengikuti gaya halaman Prediksi:
  // back - logo - avatar di header, judul italic di bawahnya,
  // Container flat dengan shadow tipis, bukan kartu melayang.
  // -------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: _T.bg,
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
          child: const Icon(Icons.arrow_back, size: 22, color: _T.hitam),
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
              border: Border.all(color: _T.border),
              boxShadow: _T.shadowTipis,
            ),
            child: ClipOval(
              child: (_fotoUrl != null && _fotoUrl!.isNotEmpty)
                  ? Image.network(
                _fotoUrl!,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.person_outline, size: 18, color: _T.hitam),
              )
                  : const Icon(Icons.person_outline, size: 18, color: _T.hitam),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildJudul() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Center(
        child: Text(
          "Tersimpan",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: _T.hitam,
          ),
        ),
      ),
    );
  }

  // Indikator TabBar dibuat mengisi penuh tiap slot (bukan hanya
  // lebar teks) supaya rapi & konsisten, sama gaya pill di halaman
  // Prediksi -- hanya diberi shadow tipis supaya tidak flat.
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _T.border),
        boxShadow: _T.shadowTipis,
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          color: _T.biru,
          borderRadius: BorderRadius.circular(26),
        ),
        splashBorderRadius: BorderRadius.circular(26),
        labelColor: Colors.white,
        unselectedLabelColor: _T.abu,
        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        labelPadding: EdgeInsets.zero,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(height: 40, text: "Peta"),
          Tab(height: 40, text: "Histori"),
          Tab(height: 40, text: "Prediksi"),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 40, color: _T.abu),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _T.abu)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _muatSemua,
            style: ElevatedButton.styleFrom(
              backgroundColor: _T.biru,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Coba lagi"),
          ),
        ]),
      ),
    );
  }

  // -------------------------------------------------------
  // TAB: PETA
  // -------------------------------------------------------
  Widget _buildDaftarPeta() {
    if (_peta.isEmpty) {
      return _buildKosong("Belum ada lokasi favorit dari halaman Peta.");
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _peta.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = _peta[i];
        final info = _kategoriAqi(item.aqi);
        return _kartuFavorit(
          key: ValueKey('peta-${item.id}'),
          judul: "Sensor ${item.nama}",
          subjudul: "Update: ${item.updateTerakhir}",
          leadingBadge: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: info.warna, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(item.aqi.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          onHapus: () => _hapusPeta(item),
          onTap: () => _bukaDetailPeta(item),
        );
      },
    );
  }

  // Detail Peta -- data sudah lengkap dari favorit_list, jadi
  // langsung dirender tanpa perlu request tambahan.
  void _bukaDetailPeta(_FavoritPeta item) {
    final info = _kategoriAqi(item.aqi);
    _bukaSheet((ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.location_on, color: info.warna),
          const SizedBox(width: 8),
          Expanded(
            child: Text("Sensor ${item.nama}",
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _T.hitam)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: info.warna, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(item.aqi.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Text(info.label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: info.warna)),
        ]),
        const SizedBox(height: 4),
        Text("Update terakhir: ${item.updateTerakhir}",
            style: const TextStyle(fontSize: 12, color: _T.abu)),
        const SizedBox(height: 16),
        const Text("Parameter Polutan",
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _T.hitam)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: [
            _kotakParameter("PM2.5", item.pm25, "µg/m³"),
            _kotakParameter("PM10",  item.pm10, "µg/m³"),
            _kotakParameter("CO",    item.co,   "ppm"),
            _kotakParameter("NO2",   item.no2,  "ppb"),
            _kotakParameter("SO2",   item.so2,  "ppb"),
            _kotakParameter("O3",    item.o3,   "ppb"),
          ],
        ),
      ],
    ));
  }

  Widget _kotakParameter(String label, double? nilai, String satuan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _T.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _T.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: _T.abu)),
          const SizedBox(height: 2),
          Text(
            nilai != null ? "${nilai.toStringAsFixed(1)} $satuan" : "-",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _T.hitam),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // TAB: HISTORI
  // -------------------------------------------------------
  Widget _buildDaftarHistori() {
    if (_histori.isEmpty) {
      return _buildKosong("Belum ada lokasi favorit dari halaman Histori.");
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _histori.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = _histori[i];
        return _kartuFavorit(
          key: ValueKey('histori-${item.monitoringId}'),
          judul: item.namaLokasi,
          subjudul: "Ketuk untuk lihat grafik AQI 7 hari terakhir",
          leadingBadge: Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(color: _T.biru, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.bar_chart, size: 18, color: Colors.white),
          ),
          onHapus: () => _hapusHistori(item),
          onTap: () => _bukaDetailHistori(item),
        );
      },
    );
  }

  void _bukaDetailHistori(_FavoritMonitoring item) {
    _bukaDetailGrafik(
      judul: item.namaLokasi,
      subjudul: "Grafik AQI -- 7 hari terakhir",
      icon: Icons.bar_chart,
      future: _TersimpanService.ambilRingkasanHistori(item.namaLokasi),
      isiBuilder: _isiRingkasanHistori,
    );
  }

  // Memakai field "data" (baris mentah histori), diagregasi per-hari
  // lalu digambar sebagai grafik AQI 7 hari terakhir lewat _grafikTren.
  Widget _isiRingkasanHistori(Map<String, dynamic> body) {
    final List rows = body["data"] ?? [];
    if (rows.isEmpty) {
      return const Text(
        "Tidak ada data histori pada 7 hari terakhir untuk lokasi ini.",
        style: TextStyle(fontSize: 12.5, color: _T.abu),
      );
    }
    final titik = _bangunTitikHarian(
      rows: rows,
      kunciWaktu: "waktu",
      kunciNilai: "aqi",
      ambilTerbaru: true, // histori -> 7 hari TERAKHIR
    );
    return _grafikTren(titik, _T.biru);
  }

  // -------------------------------------------------------
  // TAB: PREDIKSI
  // -------------------------------------------------------
  Widget _buildDaftarPrediksi() {
    if (_prediksi.isEmpty) {
      return _buildKosong("Belum ada lokasi favorit dari halaman Prediksi.");
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _prediksi.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = _prediksi[i];
        return _kartuFavorit(
          key: ValueKey('prediksi-${item.monitoringId}'),
          judul: item.namaLokasi,
          subjudul: "Ketuk untuk lihat grafik AQI 7 hari ke depan",
          leadingBadge: Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(color: _T.biru, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.auto_graph, size: 18, color: Colors.white),
          ),
          onHapus: () => _hapusPrediksi(item),
          onTap: () => _bukaDetailPrediksi(item),
        );
      },
    );
  }

  void _bukaDetailPrediksi(_FavoritMonitoring item) {
    _bukaDetailGrafik(
      judul: item.namaLokasi,
      subjudul: "Grafik AQI -- 7 hari ke depan",
      icon: Icons.auto_graph,
      future: _TersimpanService.ambilRingkasanPrediksi(item.namaLokasi),
      isiBuilder: _isiRingkasanPrediksi,
    );
  }

  // Memakai SELURUH baris "data" (slot per jam hasil prediksi),
  // diagregasi per-hari, lalu digambar sebagai grafik AQI 7 hari ke
  // depan lewat _grafikTren.
  Widget _isiRingkasanPrediksi(Map<String, dynamic> body) {
    final List rows = body["data"] ?? [];
    if (rows.isEmpty) {
      return const Text(
        "Belum ada hasil prediksi untuk lokasi ini saat ini.",
        style: TextStyle(fontSize: 12.5, color: _T.abu),
      );
    }
    final titik = _bangunTitikHarian(
      rows: rows,
      kunciWaktu: "tanggal",
      kunciNilai: "aqi_prediksi",
      ambilTerbaru: false, // prediksi -> 7 hari SETELAHNYA
    );
    return _grafikTren(titik, _T.biru);
  }

  // -------------------------------------------------------
  // TAMBAHAN: pembungkus bersama untuk detail berbasis grafik
  // (Histori & Prediksi). Sebelumnya `_bukaDetailHistori` dan
  // `_bukaDetailPrediksi` masing-masing punya blok FutureBuilder
  // + header yang isinya nyaris sama persis -- sekarang disatukan
  // di sini supaya kalau ada perubahan tampilan/loading/error,
  // cukup diubah di satu tempat.
  // -------------------------------------------------------
  void _bukaDetailGrafik({
    required String judul,
    required String subjudul,
    required IconData icon,
    required Future<Map<String, dynamic>> future,
    required Widget Function(Map<String, dynamic> body) isiBuilder,
  }) {
    _bukaSheet((ctx) => FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (ctx, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: _T.biru),
              const SizedBox(width: 8),
              Expanded(
                child: Text(judul,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _T.hitam)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(subjudul, style: const TextStyle(fontSize: 12, color: _T.abu)),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: _T.biru),
              ))
            else if (snapshot.hasError)
              Text(
                snapshot.error.toString().replaceFirst("Exception: ", ""),
                style: const TextStyle(color: _T.abu, fontSize: 12.5),
              )
            else
              isiBuilder(snapshot.data!),
          ],
        );
      },
    ));
  }

  // -------------------------------------------------------
  // BOTTOM SHEET DETAIL -- pembungkus umum dipakai oleh Peta,
  // Histori, dan Prediksi. Scrollable + ada drag handle, supaya
  // konten yang panjang (grafik + teks) tidak overflow di layar
  // kecil.
  // -------------------------------------------------------
  void _bukaSheet(WidgetBuilder isiBuilder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _T.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20, 12, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _sheetHandle()),
                const SizedBox(height: 8),
                isiBuilder(ctx),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: _T.border,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // -------------------------------------------------------
  // GRAFIK AQI -- helper agregasi & widget pembungkus, dipakai
  // bersama oleh detail Histori & Prediksi.
  // -------------------------------------------------------

  // Kelompokkan baris data (histori/prediksi) per HARI, ambil
  // rata-rata nilainya, lalu pilih 7 hari sesuai arah waktu:
  // - histori  -> 7 hari TERAKHIR (paling dekat ke hari ini)
  // - prediksi -> 7 hari PERTAMA sejak sekarang (ke depan)
  List<_TitikTren> _bangunTitikHarian({
    required List rows,
    required String kunciWaktu,
    required String kunciNilai,
    required bool ambilTerbaru,
    int maksHari = 7,
  }) {
    final Map<String, List<double>> perHari = {};
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row);
      final waktu = DateTime.tryParse((map[kunciWaktu] ?? "").toString());
      if (waktu == null) continue;
      final key =
          "${waktu.year.toString().padLeft(4, '0')}-${waktu.month.toString().padLeft(2, '0')}-${waktu.day.toString().padLeft(2, '0')}";
      final nilai = double.tryParse((map[kunciNilai] ?? "0").toString()) ?? 0;
      perHari.putIfAbsent(key, () => []).add(nilai);
    }

    var keys = perHari.keys.toList()..sort();
    if (ambilTerbaru) {
      if (keys.length > maksHari) keys = keys.sublist(keys.length - maksHari);
    } else {
      if (keys.length > maksHari) keys = keys.sublist(0, maksHari);
    }

    return keys.map((k) {
      final nilaiList = perHari[k]!;
      final rata = nilaiList.reduce((a, b) => a + b) / nilaiList.length;
      final tanggal = DateTime.parse(k);
      final dd = tanggal.day.toString().padLeft(2, '0');
      final mm = tanggal.month.toString().padLeft(2, '0');
      return _TitikTren(label: "$dd/$mm", nilai: rata);
    }).toList();
  }

  // Widget pembungkus grafik -- dipakai oleh histori & prediksi.
  Widget _grafikTren(List<_TitikTren> titik, Color warna) {
    if (titik.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text("Data tidak cukup untuk ditampilkan sebagai grafik",
              style: TextStyle(fontSize: 12.5, color: _T.abu)),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
      decoration: BoxDecoration(
        color: _T.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
      ),
      child: SizedBox(
        height: 170,
        child: CustomPaint(
          size: Size.infinite,
          painter: _GrafikTrenPainter(titik, warna),
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // KARTU FAVORIT (dipakai di ketiga tab) -- mengikuti gaya kartu
  // di halaman Prediksi: Container putih dengan border tipis +
  // shadow lembut standar, bukan Material elevation.
  // -------------------------------------------------------
  Widget _kartuFavorit({
    Key? key,
    required String judul,
    required String subjudul,
    required Widget leadingBadge,
    required VoidCallback onHapus,
    required VoidCallback onTap,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
        boxShadow: _T.shadowKartu,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              leadingBadge,
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(judul,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _T.hitam),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subjudul,
                      style: const TextStyle(fontSize: 11, color: _T.abu),
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
              IconButton(
                onPressed: () async {
                  final konfirmasi = await _konfirmasiHapus(judul);
                  if (konfirmasi) onHapus();
                },
                icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                tooltip: "Hapus dari favorit",
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildKosong(String pesan) {
    return ListView(children: [
      Padding(
        padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
        child: Column(children: [
          Icon(Icons.favorite_border, size: 40, color: _T.abu.withOpacity(0.6)),
          const SizedBox(height: 10),
          Text(pesan, textAlign: TextAlign.center, style: const TextStyle(color: _T.abu, fontSize: 13)),
        ]),
      ),
    ]);
  }
}

// =========================================================
// GRAFIK AQI SEDERHANA -- dipakai di bottom sheet detail
// Histori (7 hari terakhir) dan Prediksi (7 hari ke depan).
// Model titik data + painter line chart, mirip gaya _TrenPainter
// yang dipakai di dashboard user.
// =========================================================
class _TitikTren {
  final String label;
  final double nilai;
  _TitikTren({required this.label, required this.nilai});
}

class _GrafikTrenPainter extends CustomPainter {
  final List<_TitikTren> data;
  final Color warna;
  _GrafikTrenPainter(this.data, this.warna);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const paddingBottom = 20.0;
    const paddingTop = 18.0;
    final chartH = size.height - paddingBottom - paddingTop;
    final nilai  = data.map((e) => e.nilai).toList();
    final maxV   = nilai.reduce(math.max);
    final minV   = nilai.reduce(math.min);
    final rangeV = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    final styleLabel = TextStyle(color: _T.abu, fontSize: 10, fontWeight: FontWeight.w600);
    final styleNilai = TextStyle(color: warna, fontSize: 10, fontWeight: FontWeight.w800);

    final paintGrid = Paint()
      ..color = _T.border
      ..strokeWidth = 1;
    for (int g = 0; g <= 2; g++) {
      final y = paddingTop + chartH * (g / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    final n = data.length;
    double yUntuk(int i) {
      final t = (nilai[i] - minV) / rangeV;
      return paddingTop + chartH * (1 - t);
    }

    final titikTitik = n == 1
        ? [Offset(size.width / 2, yUntuk(0))]
        : List.generate(n, (i) => Offset(size.width * (i / (n - 1)), yUntuk(i)));

    final path = Path();
    for (int i = 0; i < titikTitik.length; i++) {
      if (i == 0) {
        path.moveTo(titikTitik[i].dx, titikTitik[i].dy);
      } else {
        final prev = titikTitik[i - 1];
        final curr = titikTitik[i];
        final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
        if (i == titikTitik.length - 1) path.lineTo(curr.dx, curr.dy);
      }
    }

    final pathArea = Path.from(path)
      ..lineTo(titikTitik.last.dx, paddingTop + chartH)
      ..lineTo(titikTitik.first.dx, paddingTop + chartH)
      ..close();
    final paintArea = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [warna.withOpacity(0.22), warna.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, paddingTop, size.width, chartH));
    canvas.drawPath(pathArea, paintArea);

    final paintGaris = Paint()
      ..color = warna
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paintGaris);

    int idxMax = 0, idxMin = 0;
    for (int i = 1; i < nilai.length; i++) {
      if (nilai[i] > nilai[idxMax]) idxMax = i;
      if (nilai[i] < nilai[idxMin]) idxMin = i;
    }

    for (int i = 0; i < titikTitik.length; i++) {
      final p = titikTitik[i];
      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, Paint()
        ..color = warna
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      canvas.drawCircle(p, 2, Paint()..color = warna);

      final tpHari = TextPainter(
        text: TextSpan(text: data[i].label, style: styleLabel),
        textDirection: TextDirection.ltr,
      )..layout();
      tpHari.paint(canvas, Offset(p.dx - tpHari.width / 2, paddingTop + chartH + 6));

      if (i == idxMax || i == idxMin) {
        final tpNilai = TextPainter(
          text: TextSpan(text: nilai[i].toStringAsFixed(0), style: styleNilai),
          textDirection: TextDirection.ltr,
        )..layout();
        final naik = i == idxMax;
        tpNilai.paint(canvas, Offset(
          p.dx - tpNilai.width / 2,
          naik ? p.dy - tpNilai.height - 8 : p.dy + 8,
        ));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GrafikTrenPainter old) =>
      old.data != data || old.warna != warna;
}