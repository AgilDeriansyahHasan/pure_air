import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' hide Path;
import 'package:latlong2/latlong.dart' hide Path;
import '../dashboard_guest.dart';
import '../../services/session.dart';
import '../../services/modules/lokasi_service.dart';
import '../../services/modules/prediksi_service.dart';
import 'user_profile_page.dart';
import 'user_prediksi_page.dart' hide kategoriDariAqi, PrediksiService;
import 'user_history_page.dart';
import 'user_peta_page.dart';
import 'user_polutan_page.dart';
import 'user_saved_page.dart';

// =========================================================
// WARNA & KONSTANTA TEMA -- dipakai konsisten di seluruh dashboard
// user. Sengaja beda aksen dari dashboard admin (biru vs oranye)
// supaya kedua sisi aplikasi terasa berbeda tapi tetap rapi.
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

// Warna kategori AQI -- sama skemanya dengan dashboard guest supaya
// konsisten di seluruh aplikasi.
const Map<String, Color> _warnaKategori = {
  "Baik":         Color(0xFF22C55E),
  "Cukup baik":   Color(0xFF84CC16),
  "Sedang":       Color(0xFFEAB308),
  "Buruk":        Color(0xFFF97316),
  "Sangat buruk": Color(0xFFEF4444),
};

// Pasangan warna gradient untuk kartu AQI utama, per kategori.
const Map<String, List<Color>> _gradienKategori = {
  "Baik":         [Color(0xFF22C55E), Color(0xFF15803D)],
  "Cukup baik":   [Color(0xFF84CC16), Color(0xFF4D7C0F)],
  "Sedang":       [Color(0xFFF59E0B), Color(0xFFC2410C)],
  "Buruk":        [Color(0xFFF97316), Color(0xFFC2410C)],
  "Sangat buruk": [Color(0xFFEF4444), Color(0xFF991B1B)],
};

// Daftar hari singkat -- dipakai untuk mengelompokkan data prediksi
// per tanggal jadi label "Sen, Sel, Rab, ..." di grafik tren mingguan
// dan kartu statistik. Sama persis dengan yang dipakai di dashboard
// guest supaya labelnya konsisten di seluruh aplikasi.
const List<String> _namaHariSingkat = ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"];

// =========================================================
// DATA DUMMY -- SEKARANG HANYA dipakai untuk bagian yang MEMANG BELUM
// ADA endpoint publiknya (cuaca & artikel/edukasi). Ini menyamakan
// logika dengan dashboard guest: "kalau data asli belum tersedia,
// widget terkait menampilkan loading indicator atau kartu info kosong
// -- bukan angka palsu".
//
// `aqiNilai`/`aqiKategori`/`lokasiUtama`, `trenMingguan`,
// `statistikMingguan`, `aqiPerWaktu`, dan `polutan` (dengan nilai
// angka) SUDAH TIDAK DIPAKAI LAGI sebagai fallback oleh widget
// manapun -- kartu-kartu terkait sekarang menampilkan loading/kartu
// info kosong kalau data asli belum ada, PERSIS seperti dashboard
// guest. Isinya tetap disimpan di sini (tidak dihapus) sebagai
// referensi/cadangan kalau suatu saat dibutuhkan lagi.
//
// `polutanDipantau` BUKAN dummy nilai -- sama seperti di dashboard
// guest, ini cuma daftar parameter yang dipantau sistem (nama +
// satuan + keterangan singkat), tanpa angka palsu. Inilah yang
// sekarang dipakai oleh _kartuPolutan.
// =========================================================
class _DummyData {
  static const int aqiNilai        = 75;
  static const String aqiKategori  = "Sedang";
  static const String lokasiUtama  = "Jakarta Pusat";
  static const String waktuUpdate  = "Baru saja diperbarui";

  // Sudah tidak dipakai sebagai fallback lagi (lihat _kartuPolutan),
  // tetap disimpan sebagai referensi.
  static const List<Map<String, String>> polutan = [
    {"label": "PM2.5", "nilai": "34", "satuan": "µg/m³"},
    {"label": "PM10",  "nilai": "58", "satuan": "µg/m³"},
    {"label": "O3",    "nilai": "21", "satuan": "ppb"},
    {"label": "NO2",   "nilai": "12", "satuan": "ppb"},
    {"label": "SO2",   "nilai": "6",  "satuan": "ppb"},
    {"label": "CO",    "nilai": "0.8","satuan": "ppm"},
  ];

  // DIPAKAI oleh _kartuPolutan -- daftar parameter yang dipantau,
  // sama persis dengan dashboard guest (tanpa nilai angka palsu).
  static const List<Map<String, String>> polutanDipantau = [
    {"label": "PM2.5", "satuan": "µg/m³", "keterangan": "Partikel halus < 2.5 mikron, paling berbahaya karena bisa masuk ke paru-paru"},
    {"label": "PM10",  "satuan": "µg/m³", "keterangan": "Partikel debu kasar < 10 mikron dari debu jalan & konstruksi"},
    {"label": "O3",    "satuan": "ppb",   "keterangan": "Ozon permukaan, terbentuk dari reaksi polutan dengan sinar matahari"},
    {"label": "NO2",   "satuan": "ppb",   "keterangan": "Nitrogen dioksida, umumnya berasal dari emisi kendaraan bermotor"},
    {"label": "SO2",   "satuan": "ppb",   "keterangan": "Sulfur dioksida, berasal dari pembakaran bahan bakar fosil & industri"},
    {"label": "CO",    "satuan": "ppm",   "keterangan": "Karbon monoksida, gas tidak berwarna dari pembakaran tidak sempurna"},
  ];

  static const List<Map<String, Object>> trenMingguan = [
    {"hari": "Sen", "nilai": 62.0},
    {"hari": "Sel", "nilai": 70.0},
    {"hari": "Rab", "nilai": 85.0},
    {"hari": "Kam", "nilai": 78.0},
    {"hari": "Jum", "nilai": 90.0},
    {"hari": "Sab", "nilai": 75.0},
    {"hari": "Min", "nilai": 68.0},
  ];

  // ===== CUACA SAAT INI ===== (SATU-SATUNYA dummy yang tetap jadi
  // sumber utama, sama seperti dashboard guest, karena belum ada
  // endpoint publiknya).
  static const Map<String, Object> cuaca = {
    "suhu": 31,
    "kondisi": "Berawan",
    "kelembaban": 68,
    "anginKph": 12,
    "icon": Icons.cloud_outlined,
  };

  // Sudah tidak dipakai sebagai fallback lagi (lihat _kartuStatistik),
  // tetap disimpan sebagai referensi.
  static Map<String, Object> get statistikMingguan {
    final nilai = trenMingguan.map((e) => e["nilai"] as double).toList();
    final rata = nilai.reduce((a, b) => a + b) / nilai.length;
    int idxMax = 0, idxMin = 0;
    for (int i = 1; i < nilai.length; i++) {
      if (nilai[i] > nilai[idxMax]) idxMax = i;
      if (nilai[i] < nilai[idxMin]) idxMin = i;
    }
    final naik = nilai.last > nilai.first;
    return {
      "rata": rata,
      "hariTerbaik": trenMingguan[idxMin]["hari"]!,
      "nilaiTerbaik": nilai[idxMin],
      "hariTerburuk": trenMingguan[idxMax]["hari"]!,
      "nilaiTerburuk": nilai[idxMax],
      "tren": naik ? "naik" : "turun",
      "selisih": (nilai.last - nilai.first).abs(),
    };
  }

  // ===== ARTIKEL / EDUKASI ===== (masih dummy, belum ada endpoint
  // artikel -- ini fitur khusus dashboard user, tidak ada di guest).
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

  // Sudah tidak dipakai sebagai fallback lagi (lihat _kartuAqiPerWaktu),
  // tetap disimpan sebagai referensi.
  static const List<Map<String, Object>> aqiPerWaktu = [
    {"label": "Pagi",  "jam": "06:00", "nilai": 52, "icon": Icons.wb_twilight},
    {"label": "Siang", "jam": "12:00", "nilai": 88, "icon": Icons.wb_sunny_outlined},
    {"label": "Sore",  "jam": "18:00", "nilai": 75, "icon": Icons.wb_cloudy_outlined},
    {"label": "Malam", "jam": "21:00", "nilai": 60, "icon": Icons.nightlight_outlined},
  ];
}

// Anchor jam buat bucket "AQI sepanjang hari" -- dipakai untuk mencari
// baris prediksi (PrediksiModel) yang jamnya paling dekat ke tiap slot.
const List<Map<String, Object>> _anchorWaktu = [
  {"label": "Pagi",  "jam": 6,  "icon": Icons.wb_twilight},
  {"label": "Siang", "jam": 12, "icon": Icons.wb_sunny_outlined},
  {"label": "Sore",  "jam": 18, "icon": Icons.wb_cloudy_outlined},
  {"label": "Malam", "jam": 21, "icon": Icons.nightlight_outlined},
];

// Warna aksen berbeda untuk tiap tombol quick action, biar tidak
// monoton semua biru -- murni polesan visual, tidak mengubah fungsi.
const List<Color> _warnaQuickAction = [
  Color(0xFFEF4444), // Laporkan
  Color(0xFFF59E0B), // Pengingat
  Color(0xFF22C55E), // Bagikan
  Color(0xFF2F6FED), // Unduh data
];

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
// KONTROL ZOOM PETA -- SAMA PERSIS dengan yang dipakai di dashboard
// guest, dipakai oleh preview map di kartu "Peta lokasi" supaya
// perilaku & tampilannya konsisten di seluruh aplikasi.
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

class UserDashboardPage extends StatefulWidget {
  final String username;
  final String email;

  const UserDashboardPage({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  bool isExpanded = false;
  bool _bannerDitutup = false; // ← status banner peringatan AQI ditutup atau belum
  String? _fotoUrl; // ← simpan URL foto profil

  // Dipakai buat preview mini-map di kartu "Peta lokasi".
  final MapController _previewMapController = MapController();

  // Dipakai untuk search bar -- supaya nilainya tidak hilang & bisa
  // dikosongkan lagi (reset ke daftar penuh) tanpa perlu widget uncontrolled.
  final TextEditingController _searchCtrl = TextEditingController();

  // ============================================================
  // CAROUSEL: LOKASI TERPANTAU (maks 3 kartu) & ARTIKEL (maks 2
  // kartu) -- ditampilkan sebagai carousel satu-kartu-per-layar yang
  // bisa di-swipe kiri/kanan ATAU pakai tombol panah kiri/kanan,
  // lengkap dengan titik indikator di bawahnya.
  // ============================================================
  final PageController _lokasiPageController = PageController(viewportFraction: 0.92);
  int _lokasiPageIndex = 0;

  final PageController _artikelPageController = PageController(viewportFraction: 0.92);
  int _artikelPageIndex = 0;

  // ============================================================
  // DATA DARI API (user_peta.php lewat LokasiService) -- menggantikan
  // _DummyData.lokasiTerpantau dan _DummyData.lokasiFavorit yang
  // sebelumnya hardcode.
  // ============================================================
  List<LokasiModel> _lokasiTerpantau = [];
  List<LokasiModel> _lokasiFavorit = [];
  bool _loadingLokasi = true;
  bool _loadingFavorit = true;
  String? _errorLokasi;

  // ============================================================
  // DATA DARI API (user_prediksi.php lewat PrediksiService) -- dipakai
  // untuk kartu "AQI sepanjang hari", "Tren kualitas udara (7 hari)",
  // dan "Statistik minggu ini". Kalau data asli belum/gagal dimuat,
  // kartu-kartu terkait menampilkan loading atau kartu info kosong --
  // PERSIS pola yang dipakai di dashboard guest, BUKAN fallback ke
  // angka dummy lagi. Juga menyimpan status favorit prediksi (tabel
  // `favorit_prediksi`, terpisah dari favorit Peta) untuk lokasi
  // utama yang sedang tampil.
  // ============================================================
  List<PrediksiModel> _prediksiHariIni = [];
  bool _loadingPrediksi = true;
  String? _errorPrediksi;
  bool? _isFavoritPrediksi; // null = belum dicek / tidak ada lokasi utama
  bool _togglingFavoritPrediksi = false;

  // "lokasi utama" dipakai untuk kartu AQI utama, banner peringatan,
  // tips, peta, tren, statistik, dan AQI per waktu. DIUBAH supaya
  // MURNI ikut _lokasiTerpantau (lokasi pertama dari daftar/hasil
  // pencarian) -- SAMA PERSIS dengan dashboard guest. Sebelumnya
  // sempat prioritas ke lokasi favorit dulu, tapi itu bikin lokasi
  // utama "nyangkut" di favorit dan tidak ikut berubah saat user
  // mencari lokasi lain di search bar. Sekarang begitu user mencari
  // lokasi baru (_loadLokasiTerpantau(search: ...)), lokasi utama
  // otomatis ikut berubah ke hasil pencarian tsb. Kalau daftar lokasi
  // masih kosong (belum dimuat / gagal), widget terkait menampilkan
  // loading/kartu info kosong (bukan fallback dummy) -- lihat
  // _kartuAqiUtama/_bannerPeringatan/_kartuTips.
  LokasiModel? get _lokasiUtama =>
      _lokasiTerpantau.isNotEmpty ? _lokasiTerpantau.first : null;

  // ============================================================
  // TREN DARI DATA PREDIKSI ASLI -- dikelompokkan per tanggal (maks 7
  // hari ke depan), lalu AQI-nya dirata-rata per hari. SAMA PERSIS
  // dengan getter _trenPrediksiMingguan di dashboard guest. Dipakai
  // bareng oleh kartu "Statistik minggu ini" dan "Tren kualitas udara
  // (7 hari)". Null kalau data prediksi belum ada / masih kosong --
  // pemanggilnya lalu menampilkan kartu info kosong (bukan dummy).
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
    _loadFotoProfil(); // ← load foto saat halaman dibuka
    _muatSemuaAwal();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _lokasiPageController.dispose();
    _artikelPageController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD FOTO DARI SESSION
  // ============================================================
  Future<void> _loadFotoProfil() async {
    final foto = await Session.getFotoUrl();
    if (mounted) {
      setState(() => _fotoUrl = foto);
    }
  }

  // Load awal: lokasi terpantau + favorit dulu (supaya _lokasiUtama
  // ketemu), BARU load prediksi untuk lokasi utama tsb -- karena
  // prediksi butuh nama lokasi utama yang baru tersedia setelah dua
  // request lokasi itu selesai.
  Future<void> _muatSemuaAwal() async {
    await Future.wait([
      _loadLokasiTerpantau(),
      _loadLokasiFavorit(),
    ]);
    await _loadPrediksiHariIni();
  }

  // ============================================================
  // LOAD LOKASI TERPANTAU -- ambil lokasi aktif dari action "list" di
  // user_peta.php, opsional dengan kata kunci pencarian.
  // ============================================================
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
      // Peta preview baru bisa di-fit setelah data lokasi datang,
      // dan setelah frame ini selesai dirender.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitPreviewMap());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLokasi = false;
        _errorLokasi = "Gagal memuat lokasi";
      });
    }
  }

  // ============================================================
  // LOAD LOKASI FAVORIT -- action "favorit_list", user_id
  // diambil otomatis dari Session di dalam LokasiService.
  // ============================================================
  Future<void> _loadLokasiFavorit() async {
    setState(() => _loadingFavorit = true);
    try {
      final data = await LokasiService.favoritList();
      if (!mounted) return;
      setState(() {
        _lokasiFavorit = data;
        _loadingFavorit = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFavorit = false);
    }
  }

  // ============================================================
  // LOAD PREDIKSI HARI INI -- action "get_prediksi" untuk lokasi
  // utama (_lokasiUtama), dipakai di kartu "AQI sepanjang hari",
  // "Tren kualitas udara (7 hari)", dan "Statistik minggu ini". Kalau
  // _lokasiUtama masih null (belum ada lokasi terpantau/favorit sama
  // sekali), kartu-kartu itu otomatis menampilkan kartu info kosong --
  // lihat _kartuAqiPerWaktu / _kartuTrenMingguan / _kartuStatistik.
  //
  // Sekaligus cek status favorit prediksi (favorit_prediksi) untuk
  // lokasi utama tsb, supaya ikon bookmark di header section langsung
  // benar tanpa perlu tap dulu.
  // ============================================================
  Future<void> _loadPrediksiHariIni() async {
    final namaUtama = _lokasiUtama?.nama;
    if (namaUtama == null) {
      if (!mounted) return;
      setState(() {
        _loadingPrediksi = false;
        _prediksiHariIni = [];
        _isFavoritPrediksi = null;
      });
      return;
    }

    setState(() {
      _loadingPrediksi = true;
      _errorPrediksi = null;
    });

    try {
      final hasil = await PrediksiService.getPrediksi(namaUtama);
      final favorit = await PrediksiService.cekFavorit(namaUtama);
      if (!mounted) return;
      setState(() {
        _prediksiHariIni = hasil?.data ?? [];
        _isFavoritPrediksi = favorit;
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

  // Toggle favorit prediksi untuk lokasi utama yang sedang tampil.
  Future<void> _toggleFavoritPrediksi() async {
    final namaUtama = _lokasiUtama?.nama;
    if (namaUtama == null || _togglingFavoritPrediksi) return;

    setState(() => _togglingFavoritPrediksi = true);
    try {
      final baru = await PrediksiService.toggleFavorit(namaUtama);
      if (!mounted) return;
      setState(() {
        _isFavoritPrediksi = baru;
        _togglingFavoritPrediksi = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(baru
            ? "$namaUtama ditambahkan ke favorit prediksi"
            : "$namaUtama dihapus dari favorit prediksi")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _togglingFavoritPrediksi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal mengubah favorit prediksi: $e")),
      );
    }
  }

  // Tarik untuk refresh -- memuat ulang data asli dari API (lokasi
  // terpantau + favorit + prediksi). Search yang sedang diketik ikut
  // dipertahankan.
  Future<void> _muatUlang() async {
    await Future.wait([
      _loadLokasiTerpantau(search: _searchCtrl.text.trim()),
      _loadLokasiFavorit(),
    ]);
    await _loadPrediksiHariIni();
  }

  // ============================================================
  // CARI LOKASI -- dipanggil saat user menekan enter di search bar
  // (atau menekan tombol "x" untuk reset). SAMA POLA dengan
  // dashboard guest: bukan cuma memfilter daftar lokasi terpantau,
  // tapi juga langsung ikut me-refresh kartu AQI utama, tren,
  // statistik, & AQI per waktu -- karena _lokasiUtama sekarang MURNI
  // ikut lokasi pertama dari _lokasiTerpantau, jadi begitu daftar itu
  // ke-update hasil pencarian, semua kartu berbasis prediksi otomatis
  // ikut pindah ke lokasi yang dicari (bukan diam di lokasi favorit).
  // ============================================================
  Future<void> _cariLokasi(String query) async {
    await _loadLokasiTerpantau(search: query);
    await _loadPrediksiHariIni();
  }

  void _fitPreviewMap() {
    if (_lokasiTerpantau.isEmpty) return;
    final titik = _lokasiTerpantau
        .map((l) => LatLng(l.latitude, l.longitude))
        .toList();
    try {
      final bounds = LatLngBounds.fromPoints(titik);
      _previewMapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(30)));
    } catch (_) {
      // controller belum siap ke-attach -- aman diabaikan.
    }
  }

  // ============================================================
  // NAVIGASI MENU SIDEBAR
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
      case "Historis":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HistoriUserPage()));
        break;
      case "Map":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MapAirQualityUserPage()));
        break;
      case "Polutan":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InfoPolutanPage()));
        break;
      case "Tersimpan":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TersimpanPage()));
        break;
    }
  }

  Widget menuItem(IconData icon, String title, {bool destructive = false}) {
    final warnaIkonTeks = destructive ? const Color(0xFFEF4444) : _Tema.teksUtama;
    final warnaIkon = destructive ? const Color(0xFFEF4444) : _Tema.aksen;
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
              Icon(icon, size: 21, color: warnaIkon),
              const SizedBox(width: 14),
              Text(title,
                  style: TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600, color: warnaIkonTeks)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT DIALOG
  // ============================================================
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          "Apakah kamu yakin ingin keluar?",
          style: TextStyle(fontSize: 13, color: _Tema.teksAbu),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: _Tema.teksAbu),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Session.hapus();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const DashboardGuest()),
                    (route) => false,
              );
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AVATAR WIDGET — tampilkan foto atau fallback icon
  // ============================================================
  Widget _avatarWidget({double radius = 22}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _Tema.aksen,
      backgroundImage:
      (_fotoUrl != null && _fotoUrl!.isNotEmpty)
          ? NetworkImage(_fotoUrl!)
          : null,
      child: (_fotoUrl == null || _fotoUrl!.isEmpty)
          ? Icon(Icons.person, color: Colors.white, size: radius)
          : null,
    );
  }

  // ============================================================
  // PROFILE AVATAR + DROPDOWN MENU
  // ============================================================
  Widget _profileMenuButton() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        switch (value) {
          case 'edit_profile':
            Session.getUserId().then((userId) async {
              if (!mounted) return;
              // ← tunggu hasil dari EditProfileScreen
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(userId: userId),
                ),
              );
              // ← reload foto setelah kembali dari edit profile
              if (updated == true) _loadFotoProfil();
            });
            break;
          case 'logout':
            _showLogoutDialog();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'header',
          enabled: false,
          child: Row(
            children: [
              _avatarWidget(radius: 20), // ← foto di header popup
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.username,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black)),
                    Text(widget.email,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'edit_profile',
          child: Row(children: [
            Icon(Icons.person_outline, size: 20, color: Colors.black87),
            SizedBox(width: 12),
            Text("Edit Profile"),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout, size: 20, color: Colors.red),
            SizedBox(width: 12),
            Text("Logout", style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: _Tema.cardShadow(opacity: 0.08, blur: 8, offset: const Offset(0, 2)),
        ),
        child: _avatarWidget(radius: 22), // ← foto di tombol avatar
      ),
    );
  }

  // ============================================================
  // BANNER PERINGATAN -- muncul otomatis di atas konten kalau AQI
  // lokasi utama sedang masuk kategori "Buruk" atau "Sangat buruk".
  // User bisa nutup manual; balik muncul lagi kalau halaman dibuka ulang.
  //
  // DISAMAKAN DENGAN GUEST: kalau _lokasiUtama masih null (data belum
  // ada), banner tidak ditampilkan sama sekali -- tidak ada lagi
  // fallback ke _DummyData.aqiKategori.
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
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 18, color: _Tema.teksAbu),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOMBOL BULAT GENERIK -- dipakai untuk tombol menu (hamburger),
  // saved/markah, dan notifikasi di header, supaya gaya & shadow-nya
  // konsisten satu sama lain (dulu tiap tombol nulis dekorasi sendiri).
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

  // ============================================================
  // NOTIFIKASI ICON
  // ============================================================
  Widget _notificationButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _tombolBulat(icon: Icons.notifications_none_rounded, onTap: () {}),
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
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
                  // HEADER -- tetap di atas, tidak ikut ke-scroll.
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
                      _notificationButton(),
                      _profileMenuButton(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // KONTEN -- bisa di-scroll & ditarik untuk refresh.
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
                            Text(widget.username,
                                style: const TextStyle(
                                    fontSize: 25, fontWeight: FontWeight.w800, color: _Tema.teksUtama, letterSpacing: 0.1)),
                            const SizedBox(height: 18),

                            // BANNER PERINGATAN -- hanya tampil kalau AQI sedang buruk.
                            if (_bannerPeringatan() != null) _bannerPeringatan()!,

                            // SEARCH BAR -- ketik lalu tekan enter/submit untuk
                            // cari lokasi lewat action "list" + parameter search.
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
                                onChanged: (_) => setState(() {}), // biar suffixIcon muncul/hilang
                              ),
                            ),
                            const SizedBox(height: 22),

                            // KARTU AQI UTAMA
                            _kartuAqiUtama(),
                            const SizedBox(height: 16),

                            // QUICK ACTIONS
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
                            // URUTAN DI BAWAH INI MENGIKUTI URUTAN DASHBOARD
                            // GUEST: grafik AQI minggu ini -> statistik ->
                            // polutan yang dipantau -> AQI sepanjang hari ->
                            // dst. Kartu tren, statistik, & AQI per waktu
                            // sekarang MURNI dari _prediksiHariIni (data asli
                            // user_prediksi.php action=get_prediksi) -- kalau
                            // belum ada datanya, tampil loading/kartu info
                            // kosong, PERSIS seperti dashboard guest.
                            // -----------------------------------------------
                            _judulSeksi("Tren kualitas udara (7 hari)", icon: Icons.show_chart_rounded),
                            const SizedBox(height: 10),
                            _kartuTrenMingguan(),
                            const SizedBox(height: 24),

                            _judulSeksi("Statistik minggu ini", icon: Icons.query_stats_rounded),
                            const SizedBox(height: 10),
                            _kartuStatistik(),
                            const SizedBox(height: 24),

                            _judulSeksi("Polutan yang dipantau", icon: Icons.blur_on_rounded),
                            const SizedBox(height: 10),
                            _kartuPolutan(),
                            const SizedBox(height: 24),

                            _judulSeksiAqiPerWaktu(),
                            const SizedBox(height: 10),
                            _kartuAqiPerWaktu(),
                            const SizedBox(height: 24),

                            _judulSeksi("Lokasi favorit", icon: Icons.star_rounded),
                            const SizedBox(height: 10),
                            _kartuLokasiFavorit(),
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

          // OVERLAY GELAP
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isExpanded ? 1 : 0,
            child: isExpanded
                ? GestureDetector(
              onTap: () => setState(() => isExpanded = false),
              child:
              Container(color: Colors.black.withOpacity(0.4)),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 20),
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
                              onPressed: () =>
                                  setState(() => isExpanded = false),
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

                      // SNAPSHOT PROFIL
                      Row(
                        children: [
                          _avatarWidget(radius: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.username,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: _Tema.teksUtama),
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(widget.email,
                                    style: const TextStyle(fontSize: 11.5, color: _Tema.teksAbu),
                                    overflow: TextOverflow.ellipsis),
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
                      menuItem(Icons.history_rounded, "Historis"),
                      menuItem(Icons.map_rounded, "Map"),
                      menuItem(Icons.cloud_outlined, "Polutan"),
                      menuItem(Icons.bookmark_rounded, "Tersimpan"),

                      const Spacer(),
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
      Text(
        teks,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _Tema.teksUtama, letterSpacing: 0.1),
      ),
    ],
  );

  // Judul khusus section "AQI sepanjang hari" -- sama seperti
  // _judulSeksi biasa, tapi dikasih tombol bookmark di kanan untuk
  // toggle favorit prediksi (tabel `favorit_prediksi`) pada lokasi
  // utama yang datanya sedang ditampilkan di section ini. Tombol
  // disembunyikan kalau belum ada lokasi utama sama sekali.
  Widget _judulSeksiAqiPerWaktu() {
    final adaLokasiUtama = _lokasiUtama != null;
    return Row(
      children: [
        const Icon(Icons.schedule_rounded, size: 16, color: _Tema.aksen),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            "AQI sepanjang hari (prediksi)",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _Tema.teksUtama, letterSpacing: 0.1),
          ),
        ),
        if (adaLokasiUtama)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _togglingFavoritPrediksi ? null : _toggleFavoritPrediksi,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: _togglingFavoritPrediksi
                  ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _Tema.aksen),
              )
                  : Icon(
                (_isFavoritPrediksi ?? false) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: 19,
                color: (_isFavoritPrediksi ?? false) ? _Tema.aksen : _Tema.teksAbu,
              ),
            ),
          ),
      ],
    );
  }

  BoxDecoration _dekorasiKartu() => BoxDecoration(
    color: _Tema.card,
    borderRadius: BorderRadius.circular(_Tema.radiusKartu),
    border: Border.all(color: _Tema.cardBorder),
    boxShadow: _Tema.cardShadow(opacity: 0.04),
  );

  // Kartu kecil generik untuk state loading & kosong -- dipakai di
  // beberapa seksi yang datanya dari API (lokasi terpantau, favorit, dst).
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

  // Spinner loading generik dengan tinggi tertentu -- SAMA PERSIS
  // dengan helper di dashboard guest, dipakai di semua kartu yang
  // datanya sedang dimuat dari API.
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

  // 1. KARTU AQI UTAMA -- DISAMAKAN DENGAN GUEST: loading / kosong /
  // data asli, TANPA fallback ke angka dummy lagi.
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
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: gradien,
        ),
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
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
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
            Text(_DummyData.waktuUpdate,
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
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
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(kategori,
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // 2. POLUTAN YANG DIPANTAU -- DISAMAKAN DENGAN GUEST: daftar
  // parameter (nama + satuan + keterangan singkat) saja, TANPA angka
  // palsu, karena belum ada endpoint nilai polutan asli. Ditampilkan
  // sebagai list vertikal supaya keterangan tiap parameter kebaca jelas.
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

  // 3. TREN KUALITAS UDARA -- DISAMAKAN DENGAN GUEST: data prediksi
  // asli, dengan loading & kartu kosong kalau data belum tersedia
  // (TANPA fallback ke _DummyData.trenMingguan lagi).
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
        child: CustomPaint(
          size: Size.infinite,
          painter: _TrenPainter(data),
        ),
      ),
    );
  }

  // 4. LOKASI TERPANTAU -- DIBATASI MAKS 3 LOKASI, ditampilkan sebagai
  // carousel satu-kartu-per-layar (PageView) yang bisa di-swipe kiri/
  // kanan ATAU pakai TOMBOL PANAH kiri/kanan, lengkap dengan titik
  // indikator di bawahnya. Sumber datanya tetap dari LokasiService.list().
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

    final daftar = _lokasiTerpantau.toList();

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

  // 5. TIPS HARI INI -- DISAMAKAN DENGAN GUEST: TANPA fallback dummy.
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

  // 6. PETA LOKASI -- preview mini-map (flutter_map + OpenStreetMap)
  // dengan titik dari LokasiService.list(). DISAMAKAN DENGAN GUEST:
  // marker sekarang menampilkan ANGKA AQI (bukan cuma titik warna
  // polos), tinggi peta diperbesar jadi 320 supaya marker+angka tetap
  // kebaca jelas, dan ditambah TOMBOL ZOOM IN/OUT (_kontrolZoomPeta)
  // selain gesture pinch-zoom bawaan peta. Tap ikon "buka penuh" ->
  // ke halaman peta asli (MapAirQualityUserPage).
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
                // Lapisan warna di belakang -- biar area peta tetap
                // kelihatan (tidak putih/kosong) selama tile map dari
                // server belum selesai dimuat.
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

  // 7. QUICK ACTIONS -- baris tombol aksi cepat di bawah kartu AQI utama.
  // Masih dummy (belum ada aksi nyata di baliknya).
  Widget _kartuQuickActions() {
    final aksi = [
      {"icon": Icons.report_gmailerrorred_outlined, "label": "Laporkan"},
      {"icon": Icons.notifications_active_outlined, "label": "Pengingat"},
      {"icon": Icons.ios_share_rounded, "label": "Bagikan"},
      {"icon": Icons.download_outlined, "label": "Unduh data"},
    ];
    return Row(
      children: List.generate(aksi.length, (i) {
        final a = aksi[i];
        final warna = _warnaQuickAction[i % _warnaQuickAction.length];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () {},
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

  // 8. CUACA SAAT INI -- SATU-SATUNYA dummy yang tetap dipertahankan
  // sebagai sumber utama, sama seperti dashboard guest, karena belum
  // ada endpoint publiknya.
  Widget _kartuCuaca() {
    final c = _DummyData.cuaca;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF60A5FA), Color(0xFF2F6FED)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: _Tema.aksen.withOpacity(0.28)),
        ],
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
                Text("${c["suhu"]}°C",
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                Text(c["kondisi"] as String,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.5)),
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

  // 9. STATISTIK RINGKASAN MINGGUAN -- DISAMAKAN DENGAN GUEST: data
  // prediksi asli, TANPA fallback ke _DummyData.statistikMingguan lagi.
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
        Expanded(child: _kotakStatistik(
          "Rata-rata",
          rata.toStringAsFixed(0),
          Icons.equalizer_rounded,
          _Tema.aksen,
        )),
        const SizedBox(width: 10),
        Expanded(child: _kotakStatistik(
          "Terbaik ($hariTerbaik)",
          nilai[idxMin].toStringAsFixed(0),
          Icons.thumb_up_alt_outlined,
          const Color(0xFF22C55E),
        )),
        const SizedBox(width: 10),
        Expanded(child: _kotakStatistik(
          "Terburuk ($hariTerburuk)",
          nilai[idxMax].toStringAsFixed(0),
          naik ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          const Color(0xFFEF4444),
        )),
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
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: _Tema.teksAbu, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // 10. AQI SEPANJANG HARI -- DISAMAKAN DENGAN GUEST: pakai data
  // prediksi asli dari PrediksiService (lokasi utama). Untuk tiap slot
  // anchor (Pagi 06:00, Siang 12:00, Sore 18:00, Malam 21:00), dicari
  // baris _prediksiHariIni hari ini yang jamnya PALING DEKAT ke anchor
  // tsb. TANPA fallback ke _DummyData.aqiPerWaktu lagi -- kalau
  // _prediksiHariIni kosong, tampilkan kartu info kosong.
  PrediksiModel? _cariPrediksiTerdekat(int jamAnchor) {
    if (_prediksiHariIni.isEmpty) return null;
    final sekarang = DateTime.now();
    PrediksiModel? terdekat;
    int? selisihTerkecil;
    for (final p in _prediksiHariIni) {
      if (p.tanggal.year != sekarang.year ||
          p.tanggal.month != sekarang.month ||
          p.tanggal.day != sekarang.day) {
        continue; // hanya slot hari ini
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
              final jamTampil = p != null
                  ? "${p.tanggal.hour.toString().padLeft(2, '0')}:00"
                  : "--:--";
              final warna = p != null
                  ? (_warnaKategori[kategoriDariAqi(nilai)] ?? _Tema.teksAbu)
                  : _Tema.teksAbu;
              return _slotAqiPerWaktu(
                jam: jamTampil, label: label, icon: icon, nilai: nilai, warna: warna,
                kosong: p == null,
              );
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
        decoration: BoxDecoration(
          color: warna.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(jam, style: const TextStyle(fontSize: 10, color: _Tema.teksAbu)),
            const SizedBox(height: 6),
            Icon(icon, size: 20, color: warna),
            const SizedBox(height: 6),
            Text(kosong ? "-" : "$nilai",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: warna)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: _Tema.teksAbu)),
          ],
        ),
      ),
    );
  }

  // 10b. PERBANDINGAN LOKASI -- bar horizontal AQI semua lokasi
  // terpantau (dari LokasiService.list()), diurutkan dari yang
  // terbaik. Lokasi utama ditandai dengan warna aksen supaya user
  // gampang bandingin posisinya.
  Widget _kartuPerbandinganLokasi() {
    if (_loadingLokasi) {
      return _kartuLoading(80);
    }
    if (_lokasiTerpantau.isEmpty) {
      return _kartuInfoKecil("Belum ada lokasi untuk dibandingkan");
    }

    final namaUtama = _lokasiUtama?.nama;
    final list = List<LokasiModel>.from(_lokasiTerpantau)
      ..sort((a, b) => a.aqi.compareTo(b.aqi));
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
                      child: Text(
                        l.nama,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isUtama ? FontWeight.w800 : FontWeight.w600,
                          color: isUtama ? _Tema.aksen : _Tema.teksUtama,
                        ),
                      ),
                    ),
                    Text("${l.aqi}",
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: warna)),
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

  // 11. LOKASI FAVORIT -- dari LokasiService.favoritList(), lengkap
  // dengan tombol hapus favorit langsung dari dashboard.
  Widget _kartuLokasiFavorit() {
    if (_loadingFavorit) {
      return _kartuLoading(66);
    }
    if (_lokasiFavorit.isEmpty) {
      return _kartuInfoKecil("Belum ada lokasi favorit", icon: Icons.star_border_rounded);
    }

    return Column(
      children: _lokasiFavorit.map((l) {
        final kategori = kategoriDariAqi(l.aqi);
        final warna = _warnaKategori[kategori] ?? _Tema.teksAbu;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: _dekorasiKartu(),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: warna.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.star_rounded, size: 18, color: warna),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l.nama,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Tema.teksUtama)),
              ),
              Text("${l.aqi}",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: warna)),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  try {
                    await LokasiService.favoritHapus(l.id);
                    await _loadLokasiFavorit();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Gagal menghapus favorit: $e")),
                    );
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 18, color: _Tema.teksAbu),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 12. ARTIKEL / EDUKASI -- DIBATASI MAKS 2 ARTIKEL, ditampilkan
  // sebagai carousel satu-kartu-per-layar (PageView) yang bisa
  // di-swipe kiri/kanan ATAU pakai TOMBOL PANAH kiri/kanan, lengkap
  // dengan titik indikator di bawahnya. Masih dummy (belum ada
  // endpoint artikel).
  Widget _kartuArtikel() {
    final daftar = _DummyData.artikel.toList();

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
// LINE CHART SEDERHANA -- dipakai di kartu "Tren kualitas udara
// (7 hari)". Menggambar garis halus + titik data + area gradient
// tipis di bawah garis, dengan label nilai di titik tertinggi &
// terendah supaya tetap informatif tanpa terlihat penuh sesak.
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
      canvas.drawCircle(p, 4, Paint()
        ..color = _Tema.aksen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
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
        tpNilai.paint(canvas, Offset(
          p.dx - tpNilai.width / 2,
          naik ? p.dy - tpNilai.height - 8 : p.dy + 8,
        ));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrenPainter old) => old.data != data;
}