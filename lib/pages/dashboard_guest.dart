import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' hide Path;
import 'package:latlong2/latlong.dart' hide Path;

import 'login_page/login_page.dart';
import 'package:pureair/pages/users_page/user_prediksi_page.dart' show PrediksiPage;
import 'users_page/user_peta_page.dart';
import 'users_page/user_polutan_page.dart';

// =========================================================
// SESUAIKAN PATH IMPORT INI dengan struktur project kamu.
// Asumsi: file ini ada di lib/pages/dashboard_guest.dart, sedangkan
// service ada di lib/services/modules/... (satu level naik dari
// pages/, beda dengan user_dashboard_page.dart yang naik dua level
// karena dia ada di lib/pages/user/).
// =========================================================
import '../services/modules/lokasi_service.dart';
import '../services/modules/prediksi_service.dart';

// =========================================================
// TEMA -- sengaja disamakan persis dengan _Tema di UserDashboardPage
// supaya dashboard guest & dashboard user terasa satu keluarga visual.
// Karena identifier diawali underscore (private per-file di Dart),
// class ini terpisah dari punya UserDashboardPage meski isinya sama.
// =========================================================
class _Tema {
  static const bg         = Color(0xFFF6F7FB);
  static const card       = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFEDEEF3);
  static const teksAbu    = Color(0xFF6B7280);
  static const teksUtama  = Color(0xFF111827);
  static const aksen      = Color(0xFF2F6FED);
  static const aksenSoft  = Color(0xFFEAF1FE);

  static const double radiusKartu = 20;
  static const double radiusKecil = 14;

  static List<BoxShadow> cardShadow({
    double opacity = 0.05,
    double blur = 16,
    Offset offset = const Offset(0, 6),
  }) => [
    BoxShadow(blurRadius: blur, offset: offset, color: Colors.black.withOpacity(opacity)),
  ];
}

const Map<String, Color> _warnaKategori = {
  "Baik":         Color(0xFF22C55E),
  "Cukup baik":   Color(0xFF84CC16),
  "Sedang":       Color(0xFFEAB308),
  "Buruk":        Color(0xFFF97316),
  "Sangat buruk": Color(0xFFEF4444),
};

const Map<String, List<Color>> _gradienKategori = {
  "Baik":         [Color(0xFF22C55E), Color(0xFF15803D)],
  "Cukup baik":   [Color(0xFF84CC16), Color(0xFF4D7C0F)],
  "Sedang":       [Color(0xFFF59E0B), Color(0xFFC2410C)],
  "Buruk":        [Color(0xFFF97316), Color(0xFFC2410C)],
  "Sangat buruk": [Color(0xFFEF4444), Color(0xFF991B1B)],
};

const List<Color> _warnaQuickAction = [
  Color(0xFFEF4444), // Laporkan
  Color(0xFFF59E0B), // Pengingat
  Color(0xFF22C55E), // Bagikan
];

// =========================================================
// DATA DUMMY -- HANYA UNTUK BAGIAN YANG MEMANG BELUM ADA
// ENDPOINT PUBLIKNYA (cuaca & artikel/edukasi). Semua dummy lain
// (AQI utama, tren mingguan, statistik, AQI per waktu) sudah
// dihapus. Kalau data asli belum tersedia, widget terkait
// menampilkan loading indicator atau kartu info kosong -- bukan
// angka palsu.
// "polutanDipantau" BUKAN dummy nilai, cuma daftar parameter yang
// dipantau sistem (nama + satuan + keterangan singkat), tanpa angka.
// =========================================================
class _DummyData {
  static const Map<String, Object> cuaca = {
    "suhu": 31,
    "kondisi": "Berawan",
    "kelembaban": 68,
    "anginKph": 12,
    "icon": Icons.cloud_outlined,
  };

  static const List<Map<String, String>> polutanDipantau = [
    {"label": "PM2.5", "satuan": "µg/m³", "keterangan": "Partikel halus < 2.5 mikron, paling berbahaya karena bisa masuk ke paru-paru"},
    {"label": "PM10",  "satuan": "µg/m³", "keterangan": "Partikel debu kasar < 10 mikron dari debu jalan & konstruksi"},
    {"label": "O3",    "satuan": "ppb",   "keterangan": "Ozon permukaan, terbentuk dari reaksi polutan dengan sinar matahari"},
    {"label": "NO2",   "satuan": "ppb",   "keterangan": "Nitrogen dioksida, umumnya berasal dari emisi kendaraan bermotor"},
    {"label": "SO2",   "satuan": "ppb",   "keterangan": "Sulfur dioksida, berasal dari pembakaran bahan bakar fosil & industri"},
    {"label": "CO",    "satuan": "ppm",   "keterangan": "Karbon monoksida, gas tidak berwarna dari pembakaran tidak sempurna"},
  ];

  // ===== ARTIKEL / EDUKASI ===== (masih dummy, belum ada endpoint
  // artikel -- fitur ini murni konten statis/edukasi).
  static const List<Map<String, String>> artikel = [
    {
      "judul": "Kenapa AQI Naik Saat Musim Kemarau?",
      "ringkasan": "Kurangnya hujan bikin partikel debu & asap lebih lama mengendap di udara.",
      "kategori": "Edukasi",
    },
    {
      "judul": "5 Tanaman yang Bantu Bersihkan Udara Rumah",
      "ringkasan": "Lidah mertua sampai sirih gading, ini tanaman yang terbukti efektif.",
      "kategori": "Tips",
    },
    {
      "judul": "Masker N95 vs Masker Kain, Mana yang Efektif?",
      "ringkasan": "Perbedaan filtrasi partikel PM2.5 antara jenis masker yang umum dipakai.",
      "kategori": "Kesehatan",
    },
    {
      "judul": "Dampak Polusi Udara pada Anak-anak",
      "ringkasan": "Kelompok usia ini lebih rentan karena sistem pernapasan masih berkembang.",
      "kategori": "Kesehatan",
    },
  ];
}

const List<Map<String, Object>> _anchorWaktu = [
  {"label": "Pagi",  "jam": 6,  "icon": Icons.wb_twilight},
  {"label": "Siang", "jam": 12, "icon": Icons.wb_sunny_outlined},
  {"label": "Sore",  "jam": 18, "icon": Icons.wb_cloudy_outlined},
  {"label": "Malam", "jam": 21, "icon": Icons.nightlight_outlined},
];

const List<String> _namaHariSingkat = ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"];

String _tipsUntukKategori(String kategori) {
  switch (kategori) {
    case "Baik":
      return "Udara sedang bagus -- waktu yang pas buat olahraga atau jalan-jalan di luar ruangan.";
    case "Cukup baik":
      return "Kualitas udara cukup baik. Kelompok sensitif (anak-anak, lansia) tetap disarankan waspada.";
    case "Sedang":
      return "Kurangi aktivitas berat di luar ruangan terlalu lama, terutama untuk kelompok sensitif.";
    case "Buruk":
      return "Gunakan masker saat beraktivitas di luar dan batasi waktu di luar ruangan.";
    default:
      return "Hindari aktivitas luar ruangan dan gunakan masker N95 bila terpaksa harus keluar.";
  }
}

String _sapaanWaktu() {
  final jam = DateTime.now().hour;
  if (jam < 10) return "Selamat pagi";
  if (jam < 15) return "Selamat siang";
  if (jam < 18) return "Selamat sore";
  return "Selamat malam";
}

// ============================================================
// KONTROL ZOOM PETA -- dipakai oleh preview map di kartu "Peta lokasi"
// (_kartuPeta), supaya perilaku & tampilannya konsisten dengan
// dashboard user.
// ============================================================
void _zoomPeta(MapController controller, double delta, {double min = 2, double max = 18}) {
  final camera = controller.camera;
  final zoomBaru = (camera.zoom + delta).clamp(min, max);
  controller.move(camera.center, zoomBaru);
}

Widget _tombolZoomKecil({required IconData icon, required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: _Tema.cardShadow(opacity: 0.14, blur: 6, offset: const Offset(0, 2)),
      ),
      child: Icon(icon, size: 18, color: _Tema.teksUtama),
    ),
  );
}

Widget _kontrolZoomPeta(MapController controller, {double min = 2, double max = 18}) {
  return Positioned(
    right: 10,
    bottom: 10,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tombolZoomKecil(
          icon: Icons.add_rounded,
          onTap: () => _zoomPeta(controller, 1, min: min, max: max),
        ),
        const SizedBox(height: 8),
        _tombolZoomKecil(
          icon: Icons.remove_rounded,
          onTap: () => _zoomPeta(controller, -1, min: min, max: max),
        ),
      ],
    ),
  );
}

class DashboardGuest extends StatefulWidget {
  const DashboardGuest({super.key});

  @override
  State<DashboardGuest> createState() => _DashboardGuestState();
}

class _DashboardGuestState extends State<DashboardGuest> {
  bool isExpanded = false;
  bool _bannerDitutup = false;

  final MapController _previewMapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();

  // ============================================================
  // CAROUSEL: LOKASI TERPANTAU (maks 3 kartu) & ARTIKEL (maks 2
  // kartu) -- ditampilkan sebagai carousel satu-kartu-per-layar yang
  // bisa di-swipe kiri/kanan ATAU pakai tombol panah kiri/kanan,
  // lengkap dengan titik indikator di bawahnya. Disamakan persis
  // dengan pola carousel di UserDashboardPage.
  // ============================================================
  final PageController _lokasiPageController = PageController(viewportFraction: 0.92);
  int _lokasiPageIndex = 0;

  final PageController _artikelPageController = PageController(viewportFraction: 0.92);
  int _artikelPageIndex = 0;

  // ============================================================
  // DATA DARI API (user_peta.php action=list) -- endpoint ini memang
  // publik/read-only, jadi guest tetap bisa lihat semua lokasi aktif
  // TANPA login. Yang tidak dipakai di sini: favorit_list,
  // favorit_tambah, favorit_hapus -- semua itu butuh user_id/login.
  // ============================================================
  List<LokasiModel> _lokasiTerpantau = [];
  bool _loadingLokasi = true;
  String? _errorLokasi;

  // ============================================================
  // PREDIKSI -- tetap ditampilkan untuk lokasi utama (lokasi pertama
  // dari daftar terpantau, karena guest tidak punya favorit). Toggle
  // favorit prediksi TIDAK dipakai di sini (butuh login). Data ini
  // juga dipakai ulang untuk kartu "Statistik minggu ini" dan "Tren
  // kualitas udara" (lihat _trenPrediksiMingguan).
  // ============================================================
  List<PrediksiModel> _prediksiHariIni = [];
  bool _loadingPrediksi = true;
  String? _errorPrediksi;

  // Guest tidak punya favorit, jadi lokasi utama = lokasi pertama
  // dari daftar terpantau saja.
  LokasiModel? get _lokasiUtama =>
      _lokasiTerpantau.isNotEmpty ? _lokasiTerpantau.first : null;

  // ============================================================
  // TREN DARI DATA PREDIKSI -- dikelompokkan per tanggal (maks 7
  // hari ke depan), lalu AQI-nya dirata-rata per hari. Dipakai
  // bareng oleh kartu "Statistik minggu ini" dan "Tren kualitas
  // udara". Null kalau data prediksi belum ada / masih kosong.
  // ============================================================
  List<Map<String, Object>>? get _trenPrediksiMingguan {
    if (_prediksiHariIni.isEmpty) return null;

    final Map<DateTime, List<double>> perTanggal = {};
    for (final p in _prediksiHariIni) {
      final tgl = DateTime(p.tanggal.year, p.tanggal.month, p.tanggal.day);
      perTanggal.putIfAbsent(tgl, () => []).add(p.aqi);
    }
    if (perTanggal.isEmpty) return null;

    final tanggalList = perTanggal.keys.toList()..sort();
    final dipakai = tanggalList.take(7).toList();

    return dipakai.map((tgl) {
      final nilaiList = perTanggal[tgl]!;
      final rata = nilaiList.reduce((a, b) => a + b) / nilaiList.length;
      final hari = _namaHariSingkat[tgl.weekday - 1];
      return {"hari": hari, "nilai": rata};
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _muatSemuaAwal();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _lokasiPageController.dispose();
    _artikelPageController.dispose();
    super.dispose();
  }

  Future<void> _muatSemuaAwal() async {
    await _loadLokasiTerpantau();
    await _loadPrediksiHariIni();
  }

  Future<void> _loadLokasiTerpantau({String search = ""}) async {
    setState(() {
      _loadingLokasi = true;
      _errorLokasi = null;
    });

    try {
      final data = await LokasiService.list(search: search);
      if (!mounted) return;
      setState(() {
        _lokasiTerpantau = data;
        _loadingLokasi = false;
        _lokasiPageIndex = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitPreviewMap());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLokasi = false;
        _errorLokasi = "Gagal memuat lokasi";
      });
    }
  }

  Future<void> _loadPrediksiHariIni() async {
    final namaUtama = _lokasiUtama?.nama;
    if (namaUtama == null) {
      if (!mounted) return;
      setState(() {
        _loadingPrediksi = false;
        _prediksiHariIni = [];
      });
      return;
    }

    setState(() {
      _loadingPrediksi = true;
      _errorPrediksi = null;
    });

    try {
      final hasil = await PrediksiService.getPrediksi(namaUtama);
      if (!mounted) return;
      setState(() {
        _prediksiHariIni = hasil?.data ?? [];
        _loadingPrediksi = false;
        // hasil == null artinya get_prediksi gagal (status:false dari
        // PHP, atau responsnya bukan JSON valid) -- alasan pastinya
        // sudah disimpan PrediksiService di lastError, jadi tinggal
        // dibaca di sini alih-alih ditampilkan sebagai pesan generik.
        _errorPrediksi = hasil == null ? PrediksiService.lastError : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPrediksi = false;
        _errorPrediksi = "Gagal memuat prediksi: $e";
      });
    }
  }

  Future<void> _muatUlang() async {
    await _loadLokasiTerpantau(search: _searchCtrl.text.trim());
    await _loadPrediksiHariIni();
  }

  // ============================================================
  // CARI LOKASI -- dipanggil saat user menekan enter di kolom
  // pencarian (atau menekan tombol "x" utk reset). Bukan cuma
  // memfilter daftar lokasi terpantau, tapi juga ikut me-refresh
  // kartu prediksi (_loadPrediksiHariIni), karena _lokasiUtama
  // otomatis berubah jadi hasil pencarian pertama begitu
  // _lokasiTerpantau ke-update. Jadi kalau nama yang dicari cocok
  // dengan salah satu lokasi, data prediksi dari user_prediksi.php
  // (action=get_prediksi) langsung ikut tampil untuk lokasi itu.
  // ============================================================
  Future<void> _cariLokasi(String query) async {
    await _loadLokasiTerpantau(search: query);
    await _loadPrediksiHariIni();
  }

  void _fitPreviewMap() {
    if (_lokasiTerpantau.isEmpty) return;
    final titik = _lokasiTerpantau.map((l) => LatLng(l.latitude, l.longitude)).toList();
    try {
      final bounds = LatLngBounds.fromPoints(titik);
      _previewMapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(30)),
      );
    } catch (_) {
      // controller belum siap ke-attach -- aman diabaikan.
    }
  }

  // ============================================================
  // NAVIGASI KE LOGIN + AJAKAN LOGIN
  // ============================================================
  void _kePageLogin() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _fiturButuhLogin(String namaFitur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$namaFitur perlu login dulu"),
        action: SnackBarAction(
          label: "Login",
          onPressed: _kePageLogin,
        ),
      ),
    );
  }

  // ============================================================
  // MENU SIDEBAR
  // ============================================================
  void _onMenuTap(String menu) {
    setState(() => isExpanded = false);

    switch (menu) {
      case "Dashboard":
        break;
      case "Prediksi":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PrediksiPage()));
        break;
      case "Map":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MapAirQualityUserPage()));
        break;
      case "Polutan":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InfoPolutanPage()));
        break;
      case "Tentang":
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text("Tentang PureAir", style: TextStyle(fontWeight: FontWeight.w700)),
            content: const Text(
              "PureAir membantu memantau kualitas udara di sekitarmu secara real-time. "
                  "Login untuk menyimpan lokasi favorit dan mendapatkan pengingat kualitas udara.",
              style: TextStyle(fontSize: 13, color: _Tema.teksAbu, height: 1.4),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tutup")),
            ],
          ),
        );
        break;
    }
  }

  Widget menuItem(IconData icon, String title) {
    return InkWell(
      onTap: () => _onMenuTap(title),
      borderRadius: BorderRadius.circular(_Tema.radiusKecil),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: _Tema.bg,
            borderRadius: BorderRadius.circular(_Tema.radiusKecil),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21, color: _Tema.aksen),
              const SizedBox(width: 14),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600, color: _Tema.teksUtama)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOMBOL BULAT GENERIK
  // ============================================================
  Widget _tombolBulat({
    required IconData icon,
    required VoidCallback onTap,
    double size = 44,
    double iconSize = 21,
    Color iconColor = _Tema.teksUtama,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: _Tema.cardShadow(opacity: 0.07, blur: 10, offset: const Offset(0, 3)),
        ),
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }

  // Tombol Login di header -- pill button, gantinya avatar/dropdown
  // profil yang ada di dashboard user. Ini SATU-SATUNYA pintu login
  // yang tampil di navbar guest (sesuai keputusan: guest tidak punya
  // fitur yang butuh akun, cukup satu tombol Login yang konsisten).
  Widget _tombolLoginHeader() {
    return InkWell(
      onTap: _kePageLogin,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _Tema.aksen,
          borderRadius: BorderRadius.circular(30),
          boxShadow: _Tema.cardShadow(opacity: 0.15, blur: 10, offset: const Offset(0, 3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.login_rounded, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text("Login", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BANNER PERINGATAN
  // ============================================================
  Widget? _bannerPeringatan() {
    final utama = _lokasiUtama;
    if (utama == null) return null;

    final kategori = kategoriDariAqi(utama.aqi);
    final namaLokasi = utama.nama;
    final perluWaspada = kategori == "Buruk" || kategori == "Sangat buruk";
    if (!perluWaspada || _bannerDitutup) return null;

    final warna = _warnaKategori[kategori] ?? _Tema.aksen;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warna.withOpacity(.1),
        borderRadius: BorderRadius.circular(_Tema.radiusKartu),
        border: Border.all(color: warna.withOpacity(.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: warna, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Kualitas udara $kategori di $namaLokasi",
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: warna)),
                const SizedBox(height: 3),
                Text(_tipsUntukKategori(kategori),
                    style: const TextStyle(fontSize: 11.5, color: _Tema.teksUtama, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _bannerDitutup = true),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 18, color: _Tema.teksAbu),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Tema.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  // HEADER -- logo disamakan dengan dashboard user (pakai
                  // gambar, bukan Icon+Text lagi), tapi sisi kanan tetap
                  // tombol "Login" (bukan avatar/notifikasi) karena guest
                  // memang belum punya akun.
                  Row(
                    children: [
                      _tombolBulat(
                        icon: Icons.menu_rounded,
                        onTap: () => setState(() => isExpanded = true),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/logo/pureair_logo_icon.png',
                            width: 72,
                            height: 72,
                          ),
                          const SizedBox(width: 8),
                          Image.asset(
                            'assets/logo/pureair_logo_text.png',
                            height: 36,
                            fit: BoxFit.fitHeight,
                          ),
                        ],
                      ),
                      const Spacer(),
                      _tombolLoginHeader(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // KONTEN
                  Expanded(
                    child: RefreshIndicator(
                      color: _Tema.aksen,
                      onRefresh: _muatUlang,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${_sapaanWaktu()} 👋",
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w600, color: _Tema.teksAbu)),
                            const SizedBox(height: 4),
                            const Text("Guest User",
                                style: TextStyle(
                                    fontSize: 25, fontWeight: FontWeight.w800, color: _Tema.teksUtama, letterSpacing: 0.1)),
                            const SizedBox(height: 18),

                            if (_bannerPeringatan() != null) _bannerPeringatan()!,

                            // SEARCH
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: _Tema.cardBorder),
                                boxShadow: _Tema.cardShadow(opacity: 0.04, blur: 12, offset: const Offset(0, 4)),
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                onSubmitted: (val) => _cariLokasi(val.trim()),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: const Icon(Icons.search_rounded, color: _Tema.teksAbu),
                                  suffixIcon: _searchCtrl.text.isEmpty
                                      ? null
                                      : IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18, color: _Tema.teksAbu),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _cariLokasi("");
                                      setState(() {});
                                    },
                                  ),
                                  hintText: "Cari lokasi",
                                  hintStyle: const TextStyle(color: _Tema.teksAbu),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),

                            _kartuAqiUtama(),
                            const SizedBox(height: 16),

                            _kartuQuickActions(),
                            const SizedBox(height: 24),

                            _judulSeksi("Cuaca saat ini", icon: Icons.wb_sunny_outlined),
                            const SizedBox(height: 10),
                            _kartuCuaca(),
                            const SizedBox(height: 24),

                            _judulSeksi("Peta lokasi", icon: Icons.map_rounded),
                            const SizedBox(height: 10),
                            _kartuPeta(),
                            const SizedBox(height: 24),

                            _judulSeksi("Lokasi terpantau", icon: Icons.location_on_rounded),
                            const SizedBox(height: 10),
                            _kartuLokasiTerpantau(),
                            const SizedBox(height: 24),

                            // -----------------------------------------------
                            // URUTAN DI BAWAH INI SUDAH DISESUAIKAN:
                            // grafik AQI minggu ini -> statistik -> polutan
                            // yang dipantau -> AQI sepanjang hari -> dst.
                            // Semua kartu ini otomatis ganti isi begitu user
                            // mencari lokasi lain di kolom pencarian, karena
                            // semuanya dibaca dari _prediksiHariIni /
                            // _trenPrediksiMingguan, yang di-refresh oleh
                            // _cariLokasi() -> _loadPrediksiHariIni()
                            // (action=get_prediksi di user_prediksi.php).
                            // -----------------------------------------------
                            _judulSeksi("Tren kualitas udara (prediksi 7 hari)", icon: Icons.show_chart_rounded),
                            const SizedBox(height: 10),
                            _kartuTrenMingguan(),
                            const SizedBox(height: 24),

                            _judulSeksi("Statistik minggu ini (prediksi)", icon: Icons.query_stats_rounded),
                            const SizedBox(height: 10),
                            _kartuStatistik(),
                            const SizedBox(height: 24),

                            _judulSeksi("Polutan yang dipantau", icon: Icons.blur_on_rounded),
                            const SizedBox(height: 10),
                            _kartuPolutan(),
                            const SizedBox(height: 24),

                            _judulSeksi("AQI sepanjang hari (prediksi)", icon: Icons.schedule_rounded),
                            const SizedBox(height: 10),
                            _kartuAqiPerWaktu(),
                            const SizedBox(height: 24),

                            _judulSeksi("Lokasi favorit", icon: Icons.star_rounded),
                            const SizedBox(height: 10),
                            _kartuAjakanFavorit(),
                            const SizedBox(height: 24),

                            _judulSeksi("Perbandingan lokasi", icon: Icons.bar_chart_rounded),
                            const SizedBox(height: 10),
                            _kartuPerbandinganLokasi(),
                            const SizedBox(height: 24),

                            _judulSeksi("Tips hari ini", icon: Icons.lightbulb_rounded),
                            const SizedBox(height: 10),
                            _kartuTips(),
                            const SizedBox(height: 24),

                            _judulSeksi("Artikel & edukasi", icon: Icons.menu_book_rounded),
                            const SizedBox(height: 10),
                            _kartuArtikel(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // OVERLAY
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isExpanded ? 1 : 0,
            child: isExpanded
                ? GestureDetector(
              onTap: () => setState(() => isExpanded = false),
              child: Container(color: Colors.black.withOpacity(0.4)),
            )
                : const SizedBox(),
          ),

          // SIDEBAR
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: isExpanded ? 0 : -300,
            top: 0,
            bottom: 0,
            child: Container(
              width: 270,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: _Tema.bg,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: IconButton(
                              onPressed: () => setState(() => isExpanded = false),
                              icon: const Icon(Icons.close_rounded, size: 24),
                            ),
                          ),
                          const Spacer(),
                          Image.asset(
                            'assets/logo/pureair_logo_icon.png',
                            width: 30,
                            height: 30,
                          ),
                          const SizedBox(width: 6),
                          Image.asset(
                            'assets/logo/pureair_logo_text.png',
                            height: 20,
                            fit: BoxFit.fitHeight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // SNAPSHOT GUEST (pengganti snapshot profil)
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(color: _Tema.aksen, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: const Icon(Icons.person_outline, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Guest User",
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _Tema.teksUtama)),
                                SizedBox(height: 2),
                                Text("Belum login",
                                    style: TextStyle(fontSize: 11.5, color: _Tema.teksAbu)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: _Tema.cardBorder, height: 1),
                      const SizedBox(height: 18),

                      menuItem(Icons.dashboard_rounded, "Dashboard"),
                      menuItem(Icons.auto_graph_rounded, "Prediksi"),
                      menuItem(Icons.map_rounded, "Map"),
                      menuItem(Icons.blur_on_rounded, "Polutan"),
                      menuItem(Icons.info_outline_rounded, "Tentang"),

                      const Spacer(),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _kePageLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _Tema.aksen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text("Login", style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------
  // WIDGET UMUM
  // ------------------------------------------------------
  Widget _judulSeksi(String teks, {IconData? icon}) => Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 16, color: _Tema.aksen),
        const SizedBox(width: 6),
      ],
      Text(teks,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _Tema.teksUtama, letterSpacing: 0.1)),
    ],
  );

  BoxDecoration _dekorasiKartu() => BoxDecoration(
    color: _Tema.card,
    borderRadius: BorderRadius.circular(_Tema.radiusKartu),
    border: Border.all(color: _Tema.cardBorder),
    boxShadow: _Tema.cardShadow(opacity: 0.04),
  );

  Widget _kartuInfoKecil(String teks, {IconData icon = Icons.info_outline}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: _dekorasiKartu(),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 22, color: _Tema.teksAbu),
            const SizedBox(height: 8),
            Text(teks, style: const TextStyle(fontSize: 12, color: _Tema.teksAbu)),
          ],
        ),
      ),
    );
  }

  Widget _kartuLoading(double height) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: _Tema.aksen)),
    );
  }

  // Titik indikator carousel -- dipakai di kartu "Lokasi terpantau"
  // dan "Artikel & edukasi" supaya user tahu sedang ada di kartu ke
  // berapa & masih ada berapa kartu lagi untuk di-swipe.
  Widget _dotIndicator(int count, int activeIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final aktif = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: aktif ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: aktif ? _Tema.aksen : _Tema.cardBorder,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // Tombol panah kiri/kanan untuk carousel (Lokasi terpantau &
  // Artikel) -- diletakkan menumpuk di atas PageView lewat Stack.
  // `aktif` dipakai untuk menonaktifkan tombol saat sudah di ujung
  // (kartu pertama/terakhir) supaya user tidak nge-tap sia-sia.
  Widget _tombolPanahCarousel({
    required IconData icon,
    required bool aktif,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: aktif ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: _Tema.cardShadow(opacity: 0.14, blur: 8, offset: const Offset(0, 2)),
        ),
        child: Icon(icon, size: 18, color: aktif ? _Tema.teksUtama : _Tema.cardBorder),
      ),
    );
  }

  // 1. KARTU AQI UTAMA -- loading / kosong / data asli, tanpa fallback dummy.
  Widget _kartuAqiUtama() {
    if (_loadingLokasi) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: _dekorasiKartu(),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: _Tema.aksen)),
      );
    }

    final utama = _lokasiUtama;
    if (utama == null) {
      return _kartuInfoKecil("Belum ada lokasi aktif untuk ditampilkan", icon: Icons.location_off_outlined);
    }

    final int aqiNilai = utama.aqi;
    final String kategori = kategoriDariAqi(utama.aqi);
    final String namaLokasi = utama.nama;
    final gradien = _gradienKategori[kategori] ?? [_Tema.aksen, _Tema.aksen];
    final progres = (aqiNilai / 300).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradien),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(blurRadius: 24, offset: const Offset(0, 12), color: gradien.first.withOpacity(0.35)),
        ],
      ),
      child: Column(
        children: [
          Row(children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(namaLokasi,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
          ]),
          const SizedBox(height: 20),
          const Text("Indeks Kualitas Udara (AQI)",
              style: TextStyle(color: Colors.white, fontSize: 13.5, letterSpacing: 0.2)),
          const SizedBox(height: 18),
          SizedBox(
            width: 156,
            height: 156,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 156,
                  height: 156,
                  child: CircularProgressIndicator(
                    value: progres,
                    strokeWidth: 11,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("$aqiNilai",
                        style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w800, height: 1)),
                    Text("AQI",
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(30)),
            child: Text(kategori, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // 2. POLUTAN YANG DIPANTAU -- daftar parameter (nama + satuan +
  // keterangan singkat) saja, tanpa nilai dummy, karena belum ada
  // endpoint nilai polutan asli. Ditampilkan sebagai list vertikal
  // supaya keterangan tiap parameter kebaca jelas.
  Widget _kartuPolutan() {
    return Column(
      children: _DummyData.polutanDipantau.map((p) {
        final isLast = p == _DummyData.polutanDipantau.last;
        return Container(
          margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
          padding: const EdgeInsets.all(14),
          decoration: _dekorasiKartu(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _Tema.aksenSoft, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.blur_on_rounded, size: 19, color: _Tema.aksen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(p["label"]!,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Tema.teksUtama)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _Tema.bg, borderRadius: BorderRadius.circular(20)),
                          child: Text(p["satuan"]!, style: const TextStyle(fontSize: 9.5, color: _Tema.teksAbu, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(p["keterangan"]!,
                        style: const TextStyle(fontSize: 11, color: _Tema.teksAbu, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 3. TREN KUALITAS UDARA -- data prediksi asli, dengan loading &
  // kartu kosong kalau data belum tersedia.
  Widget _kartuTrenMingguan() {
    if (_loadingPrediksi) {
      return _kartuLoading(140);
    }
    final data = _trenPrediksiMingguan;
    if (data == null || data.isEmpty) {
      return _kartuInfoKecil(_errorPrediksi ?? "Belum ada data prediksi untuk ditampilkan", icon: Icons.show_chart_rounded);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      decoration: _dekorasiKartu(),
      child: SizedBox(
        height: 140,
        child: CustomPaint(size: Size.infinite, painter: _TrenPainter(data)),
      ),
    );
  }

  // 4. LOKASI TERPANTAU -- DIBATASI MAKS 3 LOKASI, ditampilkan sebagai
  // carousel satu-kartu-per-layar (PageView) yang bisa di-swipe kiri/
  // kanan ATAU pakai TOMBOL PANAH kiri/kanan, lengkap dengan titik
  // indikator di bawahnya -- disamakan persis dengan pola carousel di
  // UserDashboardPage. Sumber datanya tetap dari LokasiService.list().
  Widget _kartuLokasiTerpantau() {
    if (_loadingLokasi) {
      return _kartuLoading(112);
    }
    if (_errorLokasi != null) {
      return _kartuInfoKecil(_errorLokasi!, icon: Icons.cloud_off_outlined);
    }
    if (_lokasiTerpantau.isEmpty) {
      return _kartuInfoKecil("Belum ada lokasi aktif");
    }

    final daftar = _lokasiTerpantau.take(3).toList();

    return Column(
      children: [
        SizedBox(
          height: 112,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _lokasiPageController,
                itemCount: daftar.length,
                onPageChanged: (i) => setState(() => _lokasiPageIndex = i),
                itemBuilder: (context, i) {
                  final l = daftar[i];
                  final kategori = kategoriDariAqi(l.aqi);
                  final warna = _warnaKategori[kategori] ?? _Tema.teksAbu;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _dekorasiKartu(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Icon(Icons.location_on_rounded, size: 14, color: warna),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(l.nama,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Tema.teksUtama),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                          Text("${l.aqi}",
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: warna)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: warna.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
                            child: Text(kategori,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: warna)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // TOMBOL PANAH KIRI/KANAN -- alternatif selain swipe.
              if (daftar.length > 1) ...[
                Positioned(
                  left: -6,
                  child: _tombolPanahCarousel(
                    icon: Icons.chevron_left_rounded,
                    aktif: _lokasiPageIndex > 0,
                    onTap: () => _lokasiPageController.previousPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
                Positioned(
                  right: -6,
                  child: _tombolPanahCarousel(
                    icon: Icons.chevron_right_rounded,
                    aktif: _lokasiPageIndex < daftar.length - 1,
                    onTap: () => _lokasiPageController.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (daftar.length > 1) ...[
          const SizedBox(height: 8),
          _dotIndicator(daftar.length, _lokasiPageIndex),
        ],
      ],
    );
  }

  // 5. TIPS HARI INI -- tanpa fallback dummy.
  Widget _kartuTips() {
    final utama = _lokasiUtama;
    if (utama == null) {
      return _kartuInfoKecil("Tips akan muncul setelah data lokasi tersedia", icon: Icons.lightbulb_outline);
    }
    final kategori = kategoriDariAqi(utama.aqi);
    final warna = _warnaKategori[kategori] ?? _Tema.aksen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warna.withOpacity(.08),
        borderRadius: BorderRadius.circular(_Tema.radiusKartu),
        border: Border.all(color: warna.withOpacity(.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: warna.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.lightbulb_rounded, size: 18, color: warna),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_tipsUntukKategori(kategori),
                style: const TextStyle(fontSize: 12.5, color: _Tema.teksUtama, height: 1.4)),
          ),
        ],
      ),
    );
  }

  // 6. PETA LOKASI -- preview map, tap "buka penuh" -> langsung ke
  // halaman Map asli (MapAirQualityUserPage), sama seperti menu
  // sidebar "Map". Halaman itu tidak butuh login, jadi guest tetap
  // bisa mengaksesnya secara penuh.
  Widget _kartuPeta() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _dekorasiKartu(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Text("Sebaran lokasi & kualitas udara",
                style: TextStyle(fontSize: 12.5, color: _Tema.teksAbu, fontWeight: FontWeight.w500)),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapAirQualityUserPage()),
            ),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.open_in_full_rounded, size: 14, color: _Tema.teksAbu),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 320,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: const Color(0xFFEAECEF)),
                FlutterMap(
                  mapController: _previewMapController,
                  options: const MapOptions(
                    initialCenter: LatLng(-6.9, 108.5),
                    initialZoom: 5,
                    minZoom: 2,
                    maxZoom: 18,
                    interactionOptions: InteractionOptions(
                      flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.flingAnimation,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png",
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: "com.pureair.app",
                      errorTileCallback: (tile, error, stackTrace) {
                        debugPrint("Gagal memuat tile peta: $error");
                      },
                    ),
                    MarkerLayer(
                      markers: _lokasiTerpantau.map((l) {
                        final warna = _warnaKategori[kategoriDariAqi(l.aqi)] ?? _Tema.teksAbu;
                        return Marker(
                          point: LatLng(l.latitude, l.longitude),
                          width: 36, height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              color: warna,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black.withOpacity(0.18))],
                            ),
                            alignment: Alignment.center,
                            child: Text("${l.aqi}",
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                _kontrolZoomPeta(_previewMapController, min: 2, max: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: _warnaKategori.entries.map((e) {
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: e.value, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(e.key, style: const TextStyle(fontSize: 10.5, color: _Tema.teksAbu)),
            ]);
          }).toList(),
        ),
      ]),
    );
  }

  // 7. QUICK ACTIONS -- "Bagikan" bebas dipakai tanpa login, sisanya
  // munculin ajakan login.
  Widget _kartuQuickActions() {
    final aksi = [
      {"icon": Icons.report_gmailerrorred_outlined, "label": "Laporkan", "butuhLogin": true},
      {"icon": Icons.notifications_active_outlined, "label": "Pengingat", "butuhLogin": true},
      {"icon": Icons.ios_share_rounded, "label": "Bagikan", "butuhLogin": false},
    ];
    return Row(
      children: List.generate(aksi.length, (i) {
        final a = aksi[i];
        final warna = _warnaQuickAction[i % _warnaQuickAction.length];
        final butuhLogin = a["butuhLogin"] as bool;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () {
                if (butuhLogin) {
                  _fiturButuhLogin(a["label"] as String);
                }
                // TODO: aksi "Bagikan" bisa langsung dipasang share_plus dsb.
              },
              borderRadius: BorderRadius.circular(_Tema.radiusKecil),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: _dekorasiKartu(),
                child: Column(
                  children: [
                    Container(
                      width: 38, height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: warna.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(a["icon"] as IconData, size: 19, color: warna),
                    ),
                    const SizedBox(height: 8),
                    Text(a["label"] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _Tema.teksUtama)),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // 8. CUACA -- SATU-SATUNYA dummy yang tetap dipertahankan, karena
  // belum ada endpoint publiknya.
  Widget _kartuCuaca() {
    final c = _DummyData.cuaca;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF60A5FA), Color(0xFF2F6FED)]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: _Tema.aksen.withOpacity(0.28))],
      ),
      child: Row(
        children: [
          Container(
            width: 58, height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), shape: BoxShape.circle),
            child: Icon(c["icon"] as IconData, size: 30, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${c["suhu"]}°C", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                Text(c["kondisi"] as String, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _barisCuacaKecil(Icons.water_drop_outlined, "${c["kelembaban"]}%"),
              const SizedBox(height: 6),
              _barisCuacaKecil(Icons.air_rounded, "${c["anginKph"]} km/j"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barisCuacaKecil(IconData icon, String teks) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.9)),
        const SizedBox(width: 4),
        Text(teks, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // 9. STATISTIK MINGGUAN -- dihitung dari data prediksi asli, dengan
  // loading & kartu kosong kalau data belum tersedia.
  Widget _kartuStatistik() {
    if (_loadingPrediksi) {
      return _kartuLoading(96);
    }
    final data = _trenPrediksiMingguan;
    if (data == null || data.isEmpty) {
      return _kartuInfoKecil(_errorPrediksi ?? "Belum ada data prediksi untuk ditampilkan", icon: Icons.query_stats_rounded);
    }

    final nilai = data.map((e) => e["nilai"] as double).toList();
    final rata = nilai.reduce((a, b) => a + b) / nilai.length;

    int idxMax = 0, idxMin = 0;
    for (int i = 1; i < nilai.length; i++) {
      if (nilai[i] > nilai[idxMax]) idxMax = i;
      if (nilai[i] < nilai[idxMin]) idxMin = i;
    }
    final naik = nilai.last > nilai.first;

    final hariTerbaik = data[idxMin]["hari"] as String;
    final hariTerburuk = data[idxMax]["hari"] as String;

    return Row(
      children: [
        Expanded(child: _kotakStatistik("Rata-rata", rata.toStringAsFixed(0), Icons.equalizer_rounded, _Tema.aksen)),
        const SizedBox(width: 10),
        Expanded(child: _kotakStatistik("Terbaik ($hariTerbaik)", nilai[idxMin].toStringAsFixed(0), Icons.thumb_up_alt_outlined, const Color(0xFF22C55E))),
        const SizedBox(width: 10),
        Expanded(child: _kotakStatistik("Terburuk ($hariTerburuk)", nilai[idxMax].toStringAsFixed(0), naik ? Icons.trending_up_rounded : Icons.trending_down_rounded, const Color(0xFFEF4444))),
      ],
    );
  }

  Widget _kotakStatistik(String label, String nilai, IconData icon, Color warna) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: _dekorasiKartu(),
      child: Column(
        children: [
          Container(
            width: 34, height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: warna.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: warna),
          ),
          const SizedBox(height: 8),
          Text(nilai, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: warna)),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: _Tema.teksAbu, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // 10. AQI SEPANJANG HARI -- data prediksi asli, tanpa fallback dummy
  // dan tanpa tombol bookmark (toggle favorit prediksi butuh login).
  PrediksiModel? _cariPrediksiTerdekat(int jamAnchor) {
    if (_prediksiHariIni.isEmpty) return null;
    final sekarang = DateTime.now();
    PrediksiModel? terdekat;
    int? selisihTerkecil;
    for (final p in _prediksiHariIni) {
      if (p.tanggal.year != sekarang.year || p.tanggal.month != sekarang.month || p.tanggal.day != sekarang.day) {
        continue;
      }
      final selisih = (p.tanggal.hour - jamAnchor).abs();
      if (selisihTerkecil == null || selisih < selisihTerkecil) {
        selisihTerkecil = selisih;
        terdekat = p;
      }
    }
    return terdekat;
  }

  Widget _kartuAqiPerWaktu() {
    if (_loadingPrediksi) {
      return _kartuLoading(130);
    }

    if (_prediksiHariIni.isEmpty) {
      return _kartuInfoKecil(_errorPrediksi ?? "Belum ada data prediksi untuk hari ini", icon: Icons.schedule_rounded);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: _dekorasiKartu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: _anchorWaktu.map((a) {
              final jam = a["jam"] as int;
              final label = a["label"] as String;
              final icon = a["icon"] as IconData;
              final p = _cariPrediksiTerdekat(jam);
              final nilai = p?.aqi.round() ?? 0;
              final jamTampil = p != null ? "${p.tanggal.hour.toString().padLeft(2, '0')}:00" : "--:--";
              final warna = p != null ? (_warnaKategori[kategoriDariAqi(nilai)] ?? _Tema.teksAbu) : _Tema.teksAbu;
              return _slotAqiPerWaktu(jam: jamTampil, label: label, icon: icon, nilai: nilai, warna: warna, kosong: p == null);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _slotAqiPerWaktu({
    required String jam,
    required String label,
    required IconData icon,
    required int nilai,
    required Color warna,
    required bool kosong,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: warna.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(jam, style: const TextStyle(fontSize: 10, color: _Tema.teksAbu)),
            const SizedBox(height: 6),
            Icon(icon, size: 20, color: warna),
            const SizedBox(height: 6),
            Text(kosong ? "-" : "$nilai", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: warna)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: _Tema.teksAbu)),
          ],
        ),
      ),
    );
  }

  // 10b. PERBANDINGAN LOKASI
  Widget _kartuPerbandinganLokasi() {
    if (_loadingLokasi) {
      return _kartuLoading(80);
    }
    if (_lokasiTerpantau.isEmpty) {
      return _kartuInfoKecil("Belum ada lokasi untuk dibandingkan");
    }

    final namaUtama = _lokasiUtama?.nama;
    final list = List<LokasiModel>.from(_lokasiTerpantau)..sort((a, b) => a.aqi.compareTo(b.aqi));
    final maxAqi = list.map((l) => l.aqi).reduce(math.max).clamp(1, 999999);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _dekorasiKartu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list.map((l) {
          final kategori = kategoriDariAqi(l.aqi);
          final warna = _warnaKategori[kategori] ?? _Tema.teksAbu;
          final isUtama = namaUtama != null && l.nama == namaUtama;
          final rasio = (l.aqi / maxAqi).clamp(0.05, 1.0);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isUtama) ...[
                      const Icon(Icons.my_location_rounded, size: 12, color: _Tema.aksen),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(l.nama,
                          style: TextStyle(fontSize: 12, fontWeight: isUtama ? FontWeight.w800 : FontWeight.w600, color: isUtama ? _Tema.aksen : _Tema.teksUtama)),
                    ),
                    Text("${l.aqi}", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: warna)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(height: 8, width: constraints.maxWidth, color: _Tema.cardBorder),
                          Container(height: 8, width: constraints.maxWidth * rasio, color: warna),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 11. AJAKAN LOGIN untuk favorit -- guest tidak punya data favorit
  // (butuh user_id/session), jadi ini kartu CTA, bukan list favorit asli.
  Widget _kartuAjakanFavorit() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Tema.aksenSoft,
        borderRadius: BorderRadius.circular(_Tema.radiusKartu),
        border: Border.all(color: _Tema.aksen.withOpacity(.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _Tema.aksen.withOpacity(.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.star_rounded, color: _Tema.aksen, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Login untuk menyimpan lokasi favorit dan memantaunya lebih cepat lain kali.",
              style: TextStyle(fontSize: 12, color: _Tema.teksUtama, height: 1.4),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _kePageLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _Tema.aksen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Login", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // 12. ARTIKEL / EDUKASI -- DIBATASI MAKS 2 ARTIKEL, ditampilkan
  // sebagai carousel satu-kartu-per-layar (PageView) yang bisa
  // di-swipe kiri/kanan ATAU pakai TOMBOL PANAH kiri/kanan, lengkap
  // dengan titik indikator di bawahnya. Masih dummy (belum ada
  // endpoint artikel).
  Widget _kartuArtikel() {
    final daftar = _DummyData.artikel.take(2).toList();

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _artikelPageController,
                itemCount: daftar.length,
                onPageChanged: (i) => setState(() => _artikelPageIndex = i),
                itemBuilder: (context, i) {
                  final a = daftar[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _dekorasiKartu(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _Tema.aksen.withOpacity(.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(a["kategori"]!,
                                style: const TextStyle(fontSize: 9.5, color: _Tema.aksen, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 8),
                          Text(a["judul"]!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _Tema.teksUtama)),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(a["ringkasan"]!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10.5, color: _Tema.teksAbu, height: 1.35)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // TOMBOL PANAH KIRI/KANAN -- alternatif selain swipe.
              if (daftar.length > 1) ...[
                Positioned(
                  left: -6,
                  child: _tombolPanahCarousel(
                    icon: Icons.chevron_left_rounded,
                    aktif: _artikelPageIndex > 0,
                    onTap: () => _artikelPageController.previousPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
                Positioned(
                  right: -6,
                  child: _tombolPanahCarousel(
                    icon: Icons.chevron_right_rounded,
                    aktif: _artikelPageIndex < daftar.length - 1,
                    onTap: () => _artikelPageController.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (daftar.length > 1) ...[
          const SizedBox(height: 8),
          _dotIndicator(daftar.length, _artikelPageIndex),
        ],
      ],
    );
  }
}

// =========================================================
// LINE CHART SEDERHANA -- sama dengan versi UserDashboardPage.
// =========================================================
class _TrenPainter extends CustomPainter {
  final List<Map<String, Object>> data;
  _TrenPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const paddingBottom = 20.0;
    const paddingTop = 18.0;
    final chartH = size.height - paddingBottom - paddingTop;
    final nilai  = data.map((e) => e["nilai"] as double).toList();
    final maxV   = nilai.reduce(math.max);
    final minV   = nilai.reduce(math.min);
    final rangeV = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    const styleLabel = TextStyle(color: _Tema.teksAbu, fontSize: 10, fontWeight: FontWeight.w600);
    const styleNilai = TextStyle(color: _Tema.aksen, fontSize: 10, fontWeight: FontWeight.w800);

    final paintGrid = Paint()
      ..color = _Tema.cardBorder
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
        colors: [_Tema.aksen.withOpacity(0.22), _Tema.aksen.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, paddingTop, size.width, chartH));
    canvas.drawPath(pathArea, paintArea);

    final paintGaris = Paint()
      ..color = _Tema.aksen
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
      canvas.drawCircle(p, 4, Paint()..color = _Tema.aksen..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(p, 2, Paint()..color = _Tema.aksen);

      final tpHari = TextPainter(
        text: TextSpan(text: data[i]["hari"] as String, style: styleLabel),
        textDirection: TextDirection.ltr,
      )..layout();
      tpHari.paint(canvas, Offset(p.dx - tpHari.width / 2, paddingTop + chartH + 6));

      if (i == idxMax || i == idxMin) {
        final tpNilai = TextPainter(
          text: TextSpan(text: nilai[i].toStringAsFixed(0), style: styleNilai),
          textDirection: TextDirection.ltr,
        )..layout();
        final naik = i == idxMax;
        tpNilai.paint(canvas, Offset(p.dx - tpNilai.width / 2, naik ? p.dy - tpNilai.height - 8 : p.dy + 8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrenPainter old) => old.data != data;
}