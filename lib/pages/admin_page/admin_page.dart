import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart' hide Path;
import 'package:latlong2/latlong.dart' hide Path;
import '../../services/users.dart';
import '../../services/session.dart'; // session (SharedPreferences)
import '../dashboard_guest.dart';
import 'admin_kualitas_udara_page.dart';
import 'admin_map_kualitas_udara.dart';
import 'admin_kelola_users.dart';
import 'admin_validasi_data.dart';
import 'admin_notifikasi.dart';
import 'admin_prediksi_udara.dart';
import 'admin_laporan_page.dart';
import 'admin_profile.dart';

// =========================================================
// PENTING -- dependency dipakai buat preview peta (sama seperti yang
// dipakai admin_map_kualitas_udara.dart), pastikan ada di pubspec.yaml:
//
//   dependencies:
//     flutter_map: ^7.0.2
//     latlong2: ^0.9.1
// =========================================================

// =========================================================
// WARNA TEMA (light) -- konsisten dengan halaman lain
// =========================================================
// DIUBAH: warna disamakan dengan logo PureAir (biru & hijau-teal),
// dulunya oranye (0xFFFB7155). `aksen` dipakai luas di seluruh file
// (tombol, badge, indikator, grafik, dsb) jadi cukup ubah di sini saja
// supaya semuanya ikut matching.
class _Tema {
  static const bg         = Color(0xFFF6F7FB);
  static const card       = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE9EAF0);
  static const teksAbu    = Color(0xFF6B7280);
  static const teksUtama  = Color(0xFF0B2A4B); // navy, sama seperti teks "Pure" di logo
  static const aksen      = Color(0xFF12A8EC); // biru, sama seperti teks "Air" & lingkaran di logo
  static const aksenHijau = Color(0xFF04AB9E); // hijau-teal daun di logo, dipakai sebagai aksen kedua
  static const bahaya     = Color(0xFFEF4444);

  static List<BoxShadow> cardShadow({double opacity = 0.05}) => [
    BoxShadow(blurRadius: 14, offset: const Offset(0, 5), color: Colors.black.withOpacity(opacity)),
  ];
}

// Warna kategori AQI skala OpenWeather (1-5), dipakai di "Status kualitas
// udara" & "Data terbaru" -- sumbernya kolom `aqi` di tabel `lokasi`.
const Map<String, Color> _warnaKategori = {
  "Baik":         Color(0xFF22C55E),
  "Cukup baik":   Color(0xFF84CC16),
  "Sedang":       Color(0xFFEAB308),
  "Buruk":        Color(0xFFF97316),
  "Sangat buruk": Color(0xFFEF4444),
  "Tidak sehat":  Color(0xFFF97316), // alias, dipakai status validasi lama
  "Berbahaya":    Color(0xFFEF4444), // alias, dipakai status validasi lama
};

// Warna khusus untuk marker/legend lokasi yang statusnya NONAKTIF di peta
// -- dipisah dari _warnaKategori karena ini bukan kategori AQI, melainkan
// status aktif/tidak aktifnya lokasi itu sendiri (kolom `status` di tabel
// `lokasi`).
const Color _warnaNonaktif = Color(0xFF9CA3AF);

/// Kategori AQI skala OpenWeather (1-5), sama seperti kategoriAqiOpenWeather()
/// di laporan.php -- supaya label & warna di dashboard konsisten dengan
/// yang dihitung di server.
String _kategoriAqiOpenWeather(int? aqi) {
  switch (aqi) {
    case 1: return "Baik";
    case 2: return "Cukup baik";
    case 3: return "Sedang";
    case 4: return "Buruk";
    case 5: return "Sangat buruk";
    default: return "Tidak diketahui";
  }
}

// ============================================================
// KONTROL ZOOM PETA -- sama pola & tampilannya dengan yang dipakai di
// dashboard guest & dashboard user, supaya perilakunya konsisten di
// seluruh aplikasi. Dipakai oleh preview map di kartu "Peta lokasi".
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
        boxShadow: _Tema.cardShadow(opacity: 0.14),
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

// =========================================================
// REFACTOR -- dulu ada 8 class service (_UserService, _LokasiService,
// _MonitoringService, _RiwayatService, _PrediksiListUserService,
// _PrediksiService, _ValidasiService, _NotifikasiService) yang isinya
// 90% sama persis: POST + timeout + decode JSON + mapping List.
// Sekarang disatukan jadi satu helper generik `_Api`, jadi kalau nanti
// mau ubah timeout / tambah header auth, cukup ubah di satu tempat.
// =========================================================
class _ApiException implements Exception {
  final String message;
  _ApiException(this.message);
  @override
  String toString() => message;
}

class _Api {
  static Future<dynamic> _post(String endpoint, Map<String, String> body) async {
    try {
      final res = await http
          .post(Uri.parse("${ApiService.baseUrl}/$endpoint"), body: body)
          .timeout(const Duration(seconds: 15));
      return jsonDecode(res.body);
    } on TimeoutException {
      throw _ApiException("Koneksi timeout, cek jaringan kamu");
    } catch (_) {
      throw _ApiException("Gagal menghubungi server");
    }
  }

  /// Endpoint yang responnya langsung berupa List mentah (mis. users.php).
  static Future<List<Map<String, dynamic>>> getList(
      String endpoint, Map<String, String> body) async {
    final decoded = await _post(endpoint, body);
    if (decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Endpoint berbentuk {status, data} (lokasi.php, monitoring.php, dst).
  static Future<List<Map<String, dynamic>>> getStatusData(
      String endpoint, Map<String, String> body) async {
    final decoded = await _post(endpoint, body);
    if (decoded is! Map || decoded["status"] != true) return [];
    final List data = decoded["data"] ?? [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

/// REFACTOR -- wadah generik untuk state "loading / error / data" satu
/// bagian dashboard. Dulu tiap bagian (user, lokasi, monitoring, validasi,
/// notifikasi) punya sepasang field terpisah (_xLoading + _xList) dan
/// try/catch yang isinya sama semua. Sekarang cukup satu instance _Muat
/// per bagian, dan pemanggilannya lewat _jalankan() di bawah.
class _Muat<T> {
  bool loading = true;
  String? error;
  T data;
  _Muat(this.data);
}

class AdminDashboardPage extends StatefulWidget {
  final String username;
  final String email;

  const AdminDashboardPage({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final List<Map<String, dynamic>> _menuItems = const [
    {"title": "User", "icon": Icons.people_alt_rounded},
    {"title": "Kualitas Udara", "icon": Icons.air_rounded},
    {"title": "Prediksi", "icon": Icons.auto_graph_rounded},
    {"title": "Laporan", "icon": Icons.article_rounded},
    {"title": "Notifikasi", "icon": Icons.notifications_rounded},
    {"title": "Validasi", "icon": Icons.verified_rounded},
    {"title": "Lokasi", "icon": Icons.location_on_rounded},
  ];

  // ------------------------------------------------------
  // Data akun yang tampil di header & menu akun diambil dari Session
  // (SharedPreferences), bukan cuma dari widget.username / widget.email
  // pemberian constructor. Kalau data session kosong (mis. baru pertama
  // login & belum sempat ke-simpan), fallback ke widget.username/email.
  // ------------------------------------------------------
  String _username = "";
  String _email = "";
  String? _fotoUrl;

  // Lima bagian ini polanya sama semua: fetch -> List<Map>. Sekarang
  // pakai _Muat<T> generik, bukan pasangan field manual lagi.
  final _users        = _Muat<List<Map<String, dynamic>>>([]);
  final _lokasi       = _Muat<List<Map<String, dynamic>>>([]);
  final _monitoring   = _Muat<List<Map<String, dynamic>>>([]);
  final _validasi     = _Muat<List<Map<String, dynamic>>>([]);
  final _notifikasi   = _Muat<List<Map<String, dynamic>>>([]);

  // ------------------------------------------------------
  // State untuk "Grafik historis per lokasi". Key = nama_lokasi, value =
  // list baris histori mentah dari monitoring.php (action=list_riwayat).
  // Timer & PageController-nya sekarang dikelola di dalam _KartuCarousel,
  // jadi di sini cukup simpan datanya saja.
  // ------------------------------------------------------
  bool _riwayatLoading = true;
  String? _riwayatError;
  final Map<String, List<Map<String, dynamic>>> _riwayatPerLokasi = {};

  // ------------------------------------------------------
  // State untuk "Grafik prediksi per lokasi". Daftar lokasi diambil dari
  // prediksi.php (action=list_user), yaitu lokasi yang sudah punya hasil
  // prediksi tersimpan.
  // ------------------------------------------------------
  bool _prediksiLoading = true;
  String? _prediksiError;
  List<String> _lokasiPunyaPrediksi = [];
  final Map<String, List<Map<String, dynamic>>> _prediksiPerLokasi = {};

  // Dipakai buat preview mini-map di kartu "Peta lokasi".
  final MapController _previewMapController = MapController();

  @override
  void initState() {
    super.initState();
    _muatSession();
    _muatSemuaData();
  }

  // (Tidak perlu dispose Timer/PageController lagi di sini -- keduanya
  // sekarang jadi tanggung jawab _KartuCarousel, di-dispose otomatis
  // waktu widget itu di-dispose oleh Flutter.)

  // ------------------------------------------------------
  // Ambil data akun dari Session (SharedPreferences), yang disimpan
  // sewaktu login lewat Session.simpan(...). Kalau nilainya kosong
  // (belum pernah disimpan), pakai widget.username/email sebagai fallback.
  // ------------------------------------------------------
  Future<void> _muatSession() async {
    try {
      final username = await Session.getUsername();
      final email    = await Session.getEmail();
      final foto     = await Session.getFotoUrl();
      if (!mounted) return;
      setState(() {
        _username = username.isNotEmpty ? username : widget.username;
        _email    = email.isNotEmpty ? email : widget.email;
        _fotoUrl  = foto;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _username = widget.username;
        _email    = widget.email;
      });
    }
  }

  Future<void> _muatSemuaData() async {
    // _muatMonitoring() dijalankan lebih dulu (bukan di dalam Future.wait
    // di bawah) karena _muatRiwayatSemuaLokasi() butuh daftar nama lokasi
    // dari _monitoring.data untuk tahu lokasi mana saja yang perlu diambil
    // grafik historisnya.
    await _muatMonitoring();
    await Future.wait([
      _muatUsers(),
      _muatLokasi(),
      _muatValidasi(),
      _muatNotifikasi(),
      _muatRiwayatSemuaLokasi(),
      _muatPrediksiSemuaLokasi(),
    ]);
  }

  /// REFACTOR -- satu helper untuk semua bagian yang polanya "fetch List,
  /// tandai loading/error, lalu setState". Menggantikan 5 method
  /// _muatXxx yang tadinya masing-masing ~10 baris try/catch/setState.
  Future<void> _jalankan<T>(_Muat<T> target, Future<T> Function() ambil) async {
    if (mounted) setState(() { target.loading = true; target.error = null; });
    try {
      target.data = await ambil();
    } catch (e) {
      target.error = e is _ApiException ? e.message : "Gagal memuat data";
    }
    target.loading = false;
    if (mounted) setState(() {});
  }

  Future<void> _muatUsers() => _jalankan(
      _users, () => _Api.getList("admin/users.php", {"action": "get"}));

  Future<void> _muatLokasi() async {
    await _jalankan(_lokasi,
            () => _Api.getStatusData("admin/lokasi.php", {"action": "list"}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitPreviewMap());
  }

  Future<void> _muatMonitoring() => _jalankan(_monitoring,
          () => _Api.getStatusData("admin/monitoring.php", {"action": "list"}));

  Future<void> _muatValidasi() => _jalankan(_validasi,
          () => _Api.getStatusData("admin/validasi.php", {"action": "list"}));

  Future<void> _muatNotifikasi() => _jalankan(
      _notifikasi,
          () => _Api.getStatusData(
          "admin/notifikasi.php", {"action": "list", "lokasi": "semua"}));

  // ------------------------------------------------------
  // Ambil histori (monitoring.php action=list_riwayat) untuk SETIAP
  // lokasi yang ada di _monitoring.data, secara paralel. Hasilnya dipakai
  // carousel "Grafik historis per lokasi" -- 1 lokasi = 1 slide.
  // ------------------------------------------------------
  Future<void> _muatRiwayatSemuaLokasi() async {
    if (mounted) setState(() { _riwayatLoading = true; _riwayatError = null; });
    try {
      final namaLokasiList = _monitoring.data
          .map((m) => (m["nama_lokasi"] ?? "").toString())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      final hasil = <String, List<Map<String, dynamic>>>{};
      await Future.wait(namaLokasiList.map((nama) async {
        try {
          hasil[nama] = await _Api.getStatusData(
              "admin/monitoring.php", {"action": "list_riwayat", "nama_lokasi": nama});
        } catch (_) {
          hasil[nama] = [];
        }
      }));

      _riwayatPerLokasi
        ..clear()
        ..addAll(hasil);
    } catch (e) {
      _riwayatError = e is _ApiException ? e.message : "Gagal memuat data histori";
    }
    _riwayatLoading = false;
    if (mounted) setState(() {});
  }

  // Ambil daftar lokasi yang sudah punya prediksi + hasil prediksinya
  // masing-masing (prediksi.php list_user + get_prediksi).
  Future<void> _muatPrediksiSemuaLokasi() async {
    if (mounted) setState(() { _prediksiLoading = true; _prediksiError = null; });
    try {
      final lokasiPunyaPrediksi =
      await _Api.getStatusData("admin/prediksi.php", {"action": "list_user"});
      final namaLokasiList = lokasiPunyaPrediksi
          .map((m) => (m["nama_lokasi"] ?? "").toString())
          .where((s) => s.isNotEmpty)
          .toList();

      final hasil = <String, List<Map<String, dynamic>>>{};
      await Future.wait(namaLokasiList.map((nama) async {
        try {
          hasil[nama] = await _Api.getStatusData(
              "admin/prediksi.php", {"action": "get_prediksi", "nama_lokasi": nama});
        } catch (_) {
          hasil[nama] = [];
        }
      }));

      _lokasiPunyaPrediksi = namaLokasiList;
      _prediksiPerLokasi
        ..clear()
        ..addAll(hasil);
    } catch (e) {
      _prediksiError = e is _ApiException ? e.message : "Gagal memuat data prediksi";
    }
    _prediksiLoading = false;
    if (mounted) setState(() {});
  }

  // DIUBAH: dulu 3 kategori (Admin / Validator / User Biasa), sekarang
  // disederhanakan jadi 2 kategori saja -- "Admin" dan "User" (validator
  // ikut dihitung sebagai User).
  List<Map<String, Object>> get _statistikUserDinamis {
    int admin = 0, user = 0;
    for (final u in _users.data) {
      final role = (u["role"] ?? "").toString().toLowerCase();
      if (role == "admin") {
        admin++;
      } else {
        user++;
      }
    }
    return [
      {"label": "Admin", "jumlah": admin, "warna": _Tema.aksen},
      {"label": "User",  "jumlah": user,  "warna": const Color(0xFF3B82F6)},
    ];
  }

  int get _jumlahBelumValid => _validasi.data
      .where((v) => v["status"] != "Valid" && v["status"] != "Diambil")
      .length;

  int get _jumlahValid => _validasi.data
      .where((v) => v["status"] == "Valid" || v["status"] == "Diambil")
      .length;

  List<Map<String, Object>> get _statusUdaraDinamis {
    final Map<String, int> hitung = {
      "Baik": 0, "Cukup baik": 0, "Sedang": 0, "Buruk": 0, "Sangat buruk": 0,
    };
    for (final l in _lokasi.data) {
      if ((l["status"] ?? "") != "aktif") continue;
      final aqiRaw = l["aqi"];
      if (aqiRaw == null || aqiRaw == "") continue;
      final aqi = int.tryParse(aqiRaw.toString());
      final kategori = _kategoriAqiOpenWeather(aqi);
      if (hitung.containsKey(kategori)) hitung[kategori] = hitung[kategori]! + 1;
    }
    return hitung.entries
        .where((e) => e.value > 0)
        .map((e) => {"label": e.key, "jumlah": e.value})
        .toList();
  }

  List<Map<String, dynamic>> get _dataTerbaruDinamis {
    final lokasiPunyaData =
    _lokasi.data.where((l) => (l["update_terakhir"] ?? "") != "").toList();
    lokasiPunyaData.sort((a, b) =>
        (b["update_terakhir"] ?? "").toString().compareTo((a["update_terakhir"] ?? "").toString()));
    return lokasiPunyaData.take(5).toList();
  }

  List<Map<String, dynamic>> get _aktivitasValidasiDinamis {
    final list = [..._validasi.data];
    list.sort((a, b) =>
        (int.tryParse((b["id"] ?? "0").toString()) ?? 0)
            .compareTo(int.tryParse((a["id"] ?? "0").toString()) ?? 0));
    return list.take(4).toList();
  }

  List<Map<String, dynamic>> get _notifikasiTerbaruDinamis => _notifikasi.data.take(3).toList();

  // ------------------------------------------------------
  // Helper umum -- kelompokkan baris-baris (yang punya kolom waktu &
  // kolom nilai numerik) jadi rata-rata HARIAN, dipakai baik untuk data
  // histori (kolom "created_at") maupun data prediksi (kolom "tanggal").
  // ------------------------------------------------------
  Map<String, double> _rataRataHarian(
      List<Map<String, dynamic>> rows, String kolomWaktu, String kolomNilai) {
    final Map<String, List<double>> perTanggal = {};
    for (final r in rows) {
      final waktu = DateTime.tryParse((r[kolomWaktu] ?? "").toString());
      if (waktu == null) continue;
      final key =
          "${waktu.year.toString().padLeft(4, '0')}-${waktu.month.toString().padLeft(2, '0')}-${waktu.day.toString().padLeft(2, '0')}";
      final nilai = double.tryParse((r[kolomNilai] ?? "0").toString()) ?? 0;
      perTanggal.putIfAbsent(key, () => []).add(nilai);
    }
    final Map<String, double> hasil = {};
    perTanggal.forEach((k, v) {
      hasil[k] = v.reduce((a, b) => a + b) / v.length;
    });
    return hasil;
  }

  // Ubah map {"Y-m-d": rataRata} jadi list siap-pakai untuk
  // _BarChartPainter / _LineChartPainter, dengan label "dd/MM".
  // `ambilDariAwal = true` dipakai untuk data prediksi (ambil N hari ke
  // depan yang PALING DEKAT), sedangkan untuk histori dibiarkan false
  // (ambil N hari TERAKHIR yang paling baru).
  List<Map<String, Object>> _keDataGrafik(
      Map<String, double> rataRataHarian, {bool ambilDariAwal = false, int maksimal = 7}) {
    final entries = rataRataHarian.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final dipakai = entries.length <= maksimal
        ? entries
        : (ambilDariAwal ? entries.sublist(0, maksimal) : entries.sublist(entries.length - maksimal));
    return dipakai.map((e) {
      final tgl = DateTime.tryParse(e.key);
      final label = tgl == null
          ? e.key
          : "${tgl.day.toString().padLeft(2, '0')}/${tgl.month.toString().padLeft(2, '0')}";
      return {"hari": label, "jumlah": e.value};
    }).toList();
  }

  /// Lokasi yang punya koordinat valid, dipakai buat preview map & legend.
  /// SENGAJA tidak difilter berdasarkan status -- lokasi aktif MAUPUN
  /// nonaktif sama-sama ditampilkan di peta, supaya admin bisa lihat
  /// semuanya sekaligus (bedanya cuma di warna marker, lihat _kartuPeta).
  List<Map<String, dynamic>> get _lokasiPunyaKoordinat => _lokasi.data.where((l) {
    final lat = double.tryParse((l["latitude"] ?? "").toString());
    final lng = double.tryParse((l["longitude"] ?? "").toString());
    return lat != null && lng != null;
  }).toList();

  LatLng? _keLatLng(Map<String, dynamic> l) {
    final lat = double.tryParse((l["latitude"] ?? "").toString());
    final lng = double.tryParse((l["longitude"] ?? "").toString());
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  void _fitPreviewMap() {
    final titik = _lokasiPunyaKoordinat.map(_keLatLng).whereType<LatLng>().toList();
    if (titik.isEmpty) return;
    if (titik.length == 1) {
      _previewMapController.move(titik.first, 9);
      return;
    }
    try {
      final bounds = LatLngBounds.fromPoints(titik);
      _previewMapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(24)));
    } catch (_) {
      // controller belum siap (map preview belum ke-attach) -- aman diabaikan,
      // _fitPreviewMap akan dipanggil lagi setelah data lain selesai dimuat.
    }
  }

  // ------------------------------------------------------
  // NAVIGASI -- satu-satunya tempat logika "menu mana buka halaman mana"
  // didefinisikan. Dipakai oleh grid menu maupun kartu "menunggu validasi".
  // ------------------------------------------------------
  void _navigasiKe(String title) {
    Widget? tujuan;
    switch (title) {
      case "User":
        tujuan = const KelolaUserPage();
        break;
      case "Kualitas Udara":
        tujuan = const KualitasUdaraDashboardPage();
        break;
      case "Prediksi":
        tujuan = const PrediksiKualitasUdaraPage();
        break;
      case "Laporan":
        tujuan = const LaporanPage();
        break;
      case "Notifikasi":
        tujuan = const NotifikasiPage();
        break;
      case "Lokasi":
        tujuan = const MapAirQualityPage();
        break;
      case "Validasi":
        tujuan = const AdminValidasiDataPage();
        break;
    }

    if (tujuan != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => tujuan!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$title belum tersedia")),
      );
    }
  }

  // Menghapus session (Session.hapus()) sebelum pindah ke DashboardGuest,
  // supaya data akun benar-benar dibersihkan waktu logout.
  void _konfirmasiLogout() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.w700, color: _Tema.teksUtama)),
          content: const Text(
            "Apakah kamu yakin ingin keluar dari akun ini?",
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
                backgroundColor: _Tema.bahaya,
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
        );
      },
    );
  }

  Widget _buildAccountMenu() {
    return PopupMenuButton<String>(
      tooltip: "Akun",
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      icon: CircleAvatar(
        radius: 24,
        backgroundColor: _Tema.aksen,
        backgroundImage: (_fotoUrl != null && _fotoUrl!.isNotEmpty)
            ? NetworkImage(_fotoUrl!)
            : null,
        child: (_fotoUrl != null && _fotoUrl!.isNotEmpty)
            ? null
            : const Icon(Icons.person_rounded, color: Colors.white, size: 20),
      ),
      onSelected: (value) {
        switch (value) {
          case "profile":
            Session.getUserId().then((userId) async {
              if (!mounted) return;
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(userId: userId),
                ),
              );
              if (updated == true) _muatSession();
            });
            break;
          case "logout":
            _konfirmasiLogout();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_username,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _Tema.teksUtama)),
                const SizedBox(height: 2),
                Text(_email,
                    style: const TextStyle(fontSize: 12, color: _Tema.teksAbu),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: "profile",
          child: Row(children: [
            Icon(Icons.settings_rounded, size: 18, color: _Tema.teksUtama),
            SizedBox(width: 10),
            Text("Profile"),
          ]),
        ),
        const PopupMenuItem<String>(
          value: "logout",
          child: Row(children: [
            Icon(Icons.logout_rounded, size: 18, color: _Tema.bahaya),
            SizedBox(width: 10),
            Text("Logout", style: TextStyle(color: _Tema.bahaya)),
          ]),
        ),
      ],
    );
  }

  Widget _menuCard(String title, IconData icon) {
    return InkWell(
      onTap: () => _navigasiKe(title),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _Tema.cardBorder),
          boxShadow: _Tema.cardShadow(opacity: 0.03),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40, height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _Tema.aksen.withOpacity(.1), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 20, color: _Tema.aksen),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _Tema.teksUtama),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = _username;

    return Scaffold(
      backgroundColor: _Tema.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _Tema.aksen,
          onRefresh: () async {
            await _muatSession();
            await _muatSemuaData();
          },
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // TAMBAHAN: dulu cuma Icon(Icons.air_rounded) + teks biasa,
              // sekarang pakai gambar logo asli (icon lingkaran + wordmark
              // "PureAir") supaya konsisten dengan brand. Badge "ADMIN" di
              // sebelahnya buat nunjukin ini panel admin, bukan app user.
              //
              // PENTING -- daftarkan asset ini dulu di pubspec.yaml:
              //   flutter:
              //     assets:
              //       - assets/images/pureair_logo_icon.png
              //       - assets/images/pureair_wordmark.png
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _Tema.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _Tema.cardBorder),
                  boxShadow: _Tema.cardShadow(opacity: 0.04),
                ),
                child: Row(
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
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_Tema.aksen.withOpacity(.15), _Tema.aksenHijau.withOpacity(.15)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _Tema.aksen.withOpacity(.3)),
                      ),
                      child: const Text(
                        "ADMIN",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _Tema.aksen,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildAccountMenu(),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text("Welcome $username 👋",
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _Tema.teksUtama)),
              const SizedBox(height: 2),
              const Text("Berikut ringkasan aktivitas hari ini",
                  style: TextStyle(fontSize: 12.5, color: _Tema.teksAbu)),
              const SizedBox(height: 18),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _menuItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) => _menuCard(
                  _menuItems[index]["title"] as String,
                  _menuItems[index]["icon"] as IconData,
                ),
              ),
              const SizedBox(height: 26),

              _judulSeksi("Ringkasan data"),
              const SizedBox(height: 10),
              _kartuRingkasan(),
              const SizedBox(height: 22),

              _judulSeksi("Statistik user"),
              const SizedBox(height: 10),
              _kartuStatistikUser(),
              const SizedBox(height: 22),

              _judulSeksi("Status kualitas udara"),
              const SizedBox(height: 10),
              _kartuStatusUdara(),
              const SizedBox(height: 22),

              _judulSeksi("Peta lokasi"),
              const SizedBox(height: 10),
              _kartuPeta(),
              const SizedBox(height: 22),

              _judulSeksi("Grafik historis per lokasi"),
              const SizedBox(height: 10),
              _kartuGrafikHistorisLokasi(),
              const SizedBox(height: 22),

              _judulSeksi("Grafik prediksi per lokasi"),
              const SizedBox(height: 10),
              _kartuGrafikPrediksiLokasi(),
              const SizedBox(height: 22),

              _judulSeksi("Data terbaru"),
              const SizedBox(height: 10),
              _kartuDataTerbaru(),
              const SizedBox(height: 22),

              _judulSeksi("Aktivitas validasi"),
              const SizedBox(height: 10),
              _kartuValidasi(),
              const SizedBox(height: 22),

              _judulSeksi("Notifikasi terbaru"),
              const SizedBox(height: 10),
              _kartuNotifikasi(),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------
  // WIDGET UMUM
  // ------------------------------------------------------
  Widget _judulSeksi(String teks) => Text(
    teks,
    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _Tema.teksUtama),
  );

  BoxDecoration _dekorasiKartu() => BoxDecoration(
    color: _Tema.card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _Tema.cardBorder),
    boxShadow: _Tema.cardShadow(opacity: 0.04),
  );

  Widget _kartuSpinner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: _dekorasiKartu(),
    child: const Center(
      child: SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: _Tema.aksen)),
    ),
  );

  Widget _kartuKosong(String pesan) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: _dekorasiKartu(),
    child: Text(pesan, style: const TextStyle(fontSize: 12.5, color: _Tema.teksAbu)),
  );

  // TAMBAHAN -- dulu kalau fetch gagal, section cuma diem nunjukin
  // spinner terus atau "-"/kosong tanpa penjelasan. Sekarang ada pesan
  // error yang jelas + tombol "Coba lagi" biar user bisa retry sendiri
  // tanpa harus pull-to-refresh seluruh halaman.
  Widget _kartuError(String pesan, VoidCallback onRetry) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: _dekorasiKartu(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.error_outline_rounded, size: 18, color: _Tema.bahaya),
        const SizedBox(width: 8),
        Expanded(child: Text(pesan, style: const TextStyle(fontSize: 12.5, color: _Tema.teksAbu))),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        height: 32,
        child: OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: _Tema.aksen,
            side: const BorderSide(color: _Tema.aksen),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text("Coba lagi", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    ]),
  );

  String _formatJamDariString(String? waktu) {
    if (waktu == null || waktu.isEmpty) return "-";
    final t = DateTime.tryParse(waktu);
    if (t == null) return "-";
    return "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }

  // 1. RINGKASAN DATA (info cards)
  Widget _kartuRingkasan() {
    String nilai(_Muat<List<Map<String, dynamic>>> m) =>
        (m.loading || m.error != null) ? "-" : "${m.data.length}";

    final ringkasan = [
      {"label": "Total User", "value": nilai(_users), "icon": Icons.people_alt_rounded, "warna": const Color(0xFF3B82F6)},
      {"label": "Total Lokasi", "value": nilai(_lokasi), "icon": Icons.location_on_rounded, "warna": _Tema.aksen},
      {"label": "Lokasi Termonitor", "value": nilai(_monitoring), "icon": Icons.bar_chart_rounded, "warna": const Color(0xFF8B5CF6)},
      {
        "label": "Data Belum Valid",
        "value": (_validasi.loading || _validasi.error != null) ? "-" : "$_jumlahBelumValid",
        "icon": Icons.hourglass_top_rounded,
        "warna": const Color(0xFFEAB308),
      },
      {
        "label": "Data Valid",
        "value": (_validasi.loading || _validasi.error != null) ? "-" : "$_jumlahValid",
        "icon": Icons.verified_rounded,
        "warna": const Color(0xFF22C55E),
      },
      {"label": "Total Notifikasi", "value": nilai(_notifikasi), "icon": Icons.notifications_rounded, "warna": _Tema.bahaya},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ringkasan.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, i) {
        final item  = ringkasan[i];
        final warna = item["warna"] as Color;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: _dekorasiKartu(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28, height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: warna.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(item["icon"] as IconData, size: 14, color: warna),
              ),
              const SizedBox(height: 8),
              Text(item["value"] as String,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _Tema.teksUtama)),
              Text(item["label"] as String,
                  style: const TextStyle(fontSize: 10, color: _Tema.teksAbu, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }

  // Satu slide untuk carousel historis / prediksi -- dulu ada 2 blok kode
  // yang isinya sama persis kecuali sumber data & painter-nya. Sekarang
  // disatukan jadi 1 helper.
  Widget _slideGrafikLokasi({
    required String nama,
    required int index,
    required int total,
    required IconData icon,
    required String subjudul,
    required String pesanKosong,
    CustomPainter? painter,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: _dekorasiKartu(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 15, color: _Tema.aksen),
            const SizedBox(width: 6),
            Expanded(
              child: Text(nama,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Tema.teksUtama),
                  overflow: TextOverflow.ellipsis),
            ),
            Text("${index + 1}/$total", style: const TextStyle(fontSize: 10.5, color: _Tema.teksAbu)),
          ]),
          const SizedBox(height: 2),
          Text(subjudul, style: const TextStyle(fontSize: 10.5, color: _Tema.teksAbu)),
          const SizedBox(height: 10),
          Expanded(
            child: painter == null
                ? Center(
                child: Text(pesanKosong, style: const TextStyle(fontSize: 11.5, color: _Tema.teksAbu)))
                : CustomPaint(size: Size.infinite, painter: painter),
          ),
        ]),
      ),
    );
  }

  // 2b. CAROUSEL GRAFIK HISTORIS PER LOKASI -- bar chart rata-rata PM2.5
  // harian (7 hari terakhir) per lokasi termonitor.
  Widget _kartuGrafikHistorisLokasi() {
    final namaLokasiList = _riwayatPerLokasi.keys.toList();
    final slides = namaLokasiList.asMap().entries.map((entry) {
      final rows = _riwayatPerLokasi[entry.value] ?? [];
      final dataGrafik = _keDataGrafik(_rataRataHarian(rows, "created_at", "pm25"));
      return _slideGrafikLokasi(
        nama: entry.value,
        index: entry.key,
        total: namaLokasiList.length,
        icon: Icons.location_on_rounded,
        subjudul: "Rata-rata PM2.5 harian (histori 7 hari terakhir)",
        pesanKosong: "Belum ada data histori untuk lokasi ini",
        painter: dataGrafik.isEmpty ? null : _BarChartPainter(dataGrafik),
      );
    }).toList();

    return _KartuCarousel(
      loading: _riwayatLoading,
      error: _riwayatError,
      onRetry: _muatRiwayatSemuaLokasi,
      pesanKosong: "Belum ada lokasi termonitor dengan data histori",
      slides: slides,
    );
  }

  // 2c. CAROUSEL GRAFIK PREDIKSI PER LOKASI -- line chart tren AQI
  // prediksi hari demi hari ke depan.
  Widget _kartuGrafikPrediksiLokasi() {
    final slides = _lokasiPunyaPrediksi.asMap().entries.map((entry) {
      final rows = _prediksiPerLokasi[entry.value] ?? [];
      final dataGrafik = _keDataGrafik(
          _rataRataHarian(rows, "tanggal", "aqi_prediksi"),
          ambilDariAwal: true);
      return _slideGrafikLokasi(
        nama: entry.value,
        index: entry.key,
        total: _lokasiPunyaPrediksi.length,
        icon: Icons.auto_graph_rounded,
        subjudul: "Rata-rata AQI prediksi per hari (ke depan)",
        pesanKosong: "Belum ada hasil prediksi untuk lokasi ini",
        painter: dataGrafik.isEmpty ? null : _LineChartPainter(dataGrafik),
      );
    }).toList();

    return _KartuCarousel(
      loading: _prediksiLoading,
      error: _prediksiError,
      onRetry: _muatPrediksiSemuaLokasi,
      pesanKosong: "Belum ada lokasi dengan hasil prediksi. Jalankan prediksi dulu di halaman Prediksi.",
      slides: slides,
    );
  }

  // 3. STATUS KUALITAS UDARA (stacked bar + legend)
  Widget _kartuStatusUdara() {
    if (_lokasi.loading) return _kartuSpinner();
    if (_lokasi.error != null) return _kartuError(_lokasi.error!, _muatLokasi);

    final statusUdara = _statusUdaraDinamis;
    if (statusUdara.isEmpty) return _kartuKosong("Belum ada lokasi aktif dengan data AQI");

    final total = statusUdara.fold<int>(0, (s, e) => s + (e["jumlah"] as int));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _dekorasiKartu(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: statusUdara.map((e) {
                final jumlah = e["jumlah"] as int;
                final warna  = _warnaKategori[e["label"]] ?? _Tema.teksAbu;
                return Expanded(flex: jumlah, child: Container(color: warna));
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...statusUdara.map((e) {
          final jumlah = e["jumlah"] as int;
          final warna  = _warnaKategori[e["label"]] ?? _Tema.teksAbu;
          final persen = total == 0 ? 0 : (jumlah / total * 100).round();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: warna, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(e["label"] as String,
                  style: const TextStyle(fontSize: 12.5, color: _Tema.teksUtama, fontWeight: FontWeight.w600))),
              Text("$jumlah lokasi", style: const TextStyle(fontSize: 11.5, color: _Tema.teksAbu)),
              const SizedBox(width: 8),
              SizedBox(width: 34, child: Text("$persen%",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11.5, color: warna, fontWeight: FontWeight.w700))),
            ]),
          );
        }),
      ]),
    );
  }

  // 4. DATA TERBARU (tabel kecil)
  Widget _kartuDataTerbaru() {
    if (_lokasi.loading) return _kartuSpinner();
    if (_lokasi.error != null) return _kartuError(_lokasi.error!, _muatLokasi);

    final dataTerbaru = _dataTerbaruDinamis;
    if (dataTerbaru.isEmpty) return _kartuKosong("Belum ada lokasi yang punya data AQI");

    return Container(
      width: double.infinity,
      decoration: _dekorasiKartu(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: const Color(0xFFF9FAFB),
          child: const Row(children: [
            SizedBox(width: 48, child: Text("Waktu", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _Tema.teksAbu))),
            Expanded(child: Text("Lokasi", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _Tema.teksAbu))),
            SizedBox(width: 40, child: Text("AQI", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _Tema.teksAbu))),
            SizedBox(width: 88, child: Text("Status", textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _Tema.teksAbu))),
          ]),
        ),
        ...dataTerbaru.map((d) {
          final aqi     = int.tryParse((d["aqi"] ?? "").toString());
          final label   = _kategoriAqiOpenWeather(aqi);
          final warna   = _warnaKategori[label] ?? _Tema.teksAbu;
          final waktu   = _formatJamDariString(d["update_terakhir"] as String?);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _Tema.cardBorder))),
            child: Row(children: [
              SizedBox(width: 48, child: Text(waktu,
                  style: const TextStyle(fontSize: 12, color: _Tema.teksUtama, fontWeight: FontWeight.w600))),
              Expanded(child: Text((d["nama"] ?? "-").toString(),
                  style: const TextStyle(fontSize: 12.5, color: _Tema.teksUtama, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
              SizedBox(width: 40, child: Text(aqi?.toString() ?? "-",
                  style: const TextStyle(fontSize: 12.5, color: _Tema.teksUtama, fontWeight: FontWeight.w700))),
              SizedBox(
                width: 88,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: warna.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(label,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: warna)),
                  ),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // 5. AKTIVITAS VALIDASI
  Widget _kartuValidasi() {
    Color warnaStatus(String s) {
      switch (s) {
        case "Valid":
        case "Diambil": return const Color(0xFF22C55E);
        case "Ditolak": return _Tema.bahaya;
        default:        return const Color(0xFFEAB308);
      }
    }

    String formatWaktu(String? raw) {
      if (raw == null || raw.isEmpty) return "-";
      final t = DateTime.tryParse(raw);
      if (t == null) return "-";
      final jam = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
      return "${t.day}/${t.month} $jam";
    }

    return Column(children: [
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _navigasiKe("Validasi"),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _Tema.aksen.withOpacity(.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Tema.aksen.withOpacity(.25)),
          ),
          child: Row(children: [
            const Icon(Icons.hourglass_top_rounded, size: 18, color: _Tema.aksen),
            const SizedBox(width: 10),
            const Expanded(child: Text("Data menunggu validasi",
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _Tema.teksUtama))),
            Text((_validasi.loading || _validasi.error != null) ? "-" : "$_jumlahBelumValid",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _Tema.aksen)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 18, color: _Tema.aksen),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      if (_validasi.loading)
        _kartuSpinner()
      else if (_validasi.error != null)
        _kartuError(_validasi.error!, _muatValidasi)
      else if (_aktivitasValidasiDinamis.isEmpty)
          _kartuKosong("Belum ada data validasi masuk")
        else
          Container(
            width: double.infinity,
            decoration: _dekorasiKartu(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: _aktivitasValidasiDinamis.asMap().entries.map((entry) {
                final v = entry.value;
                final status = (v["status"] ?? "REVIEW").toString();
                final warna = warnaStatus(status);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: entry.key == 0 ? null : const Border(top: BorderSide(color: _Tema.cardBorder)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((v["nama_lokasi"] ?? "-").toString(),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _Tema.teksUtama)),
                        const SizedBox(height: 2),
                        Text("Masuk ${formatWaktu(v["created_at"] as String?)}",
                            style: const TextStyle(fontSize: 11, color: _Tema.teksAbu)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: warna.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(status,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: warna)),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
    ]);
  }

  // 6. NOTIFIKASI TERBARU
  Widget _kartuNotifikasi() {
    Color warnaSeverity(String s) {
      switch (s.toUpperCase()) {
        case "DANGER":  return _Tema.bahaya;
        case "WARNING": return const Color(0xFFEAB308);
        default:        return _Tema.aksen;
      }
    }

    IconData ikonTipe(String tipe) {
      switch (tipe) {
        case "AQI_TINGGI":              return Icons.show_chart_rounded;
        case "SINKRONISASI_GAGAL":      return Icons.sync_problem_rounded;
        case "LOKASI_BELUM_TERDAFTAR":  return Icons.location_off_outlined;
        case "LOKASI_BARU":             return Icons.add_circle_outline_rounded;
        case "STATUS_DIVALIDASI":       return Icons.check_circle_outline_rounded;
        case "DATA_DIHUBUNGKAN":        return Icons.link_rounded;
        case "DATA_DIPERBARUI":         return Icons.refresh_rounded;
        case "DATA_SIAP_DIAMBIL":       return Icons.inventory_2_outlined;
        case "DATA_DIAMBIL":            return Icons.download_done_rounded;
        case "PENCARIAN_GAGAL":         return Icons.search_off_rounded;
        default:                        return Icons.notifications_none_rounded;
      }
    }

    String waktuRelatif(String? raw) {
      if (raw == null || raw.isEmpty) return "-";
      final t = DateTime.tryParse(raw);
      if (t == null) return "-";
      final selisih = DateTime.now().difference(t);
      if (selisih.inMinutes < 1) return "Baru saja";
      if (selisih.inMinutes < 60) return "${selisih.inMinutes} menit lalu";
      if (selisih.inHours < 24) return "${selisih.inHours} jam lalu";
      return "${selisih.inDays} hari lalu";
    }

    if (_notifikasi.loading) return _kartuSpinner();
    if (_notifikasi.error != null) return _kartuError(_notifikasi.error!, _muatNotifikasi);

    final notifikasi = _notifikasiTerbaruDinamis;
    if (notifikasi.isEmpty) return _kartuKosong("Belum ada notifikasi");

    return Container(
      width: double.infinity,
      decoration: _dekorasiKartu(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: notifikasi.asMap().entries.map((entry) {
          final n = entry.value;
          final warna = warnaSeverity((n["severity"] ?? "INFO").toString());
          final ikon = ikonTipe((n["tipe"] ?? "").toString());
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: entry.key == 0 ? null : const Border(top: BorderSide(color: _Tema.cardBorder)),
            ),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: warna.withOpacity(.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(ikon, size: 16, color: warna),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((n["judul"] ?? "-").toString(),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _Tema.teksUtama)),
                  const SizedBox(height: 2),
                  Text(waktuRelatif(n["created_at"] as String?),
                      style: const TextStyle(fontSize: 10.5, color: _Tema.teksAbu)),
                ]),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // 7. STATISTIK USER (2 kategori: Admin & User)
  Widget _kartuStatistikUser() {
    if (_users.loading) return _kartuSpinner();
    if (_users.error != null) return _kartuError(_users.error!, _muatUsers);

    final statistik = _statistikUserDinamis;
    final total = statistik.fold<int>(0, (s, e) => s + (e["jumlah"] as int));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _dekorasiKartu(),
      child: Column(children: [
        Row(
          children: statistik.map((e) {
            final jumlah = e["jumlah"] as int;
            final warna  = e["warna"] as Color;
            final persen = total == 0 ? 0 : (jumlah / total * 100).round();
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: e == statistik.last ? 0 : 10),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: warna.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: warna.withOpacity(.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(width: 8, height: 8,
                          decoration: BoxDecoration(color: warna, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(e["label"] as String,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _Tema.teksUtama)),
                    ]),
                    const SizedBox(height: 8),
                    Text("$jumlah",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: warna)),
                    const SizedBox(height: 2),
                    Text("$persen% dari total user",
                        style: const TextStyle(fontSize: 10.5, color: _Tema.teksAbu)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: statistik.map((e) {
                final jumlah = e["jumlah"] as int;
                final warna  = e["warna"] as Color;
                return Expanded(flex: jumlah == 0 ? 1 : jumlah, child: Container(color: jumlah == 0 ? const Color(0xFFF3F4F6) : warna));
              }).toList(),
            ),
          ),
        ),
      ]),
    );
  }

  // ------------------------------------------------------
  // 8. PETA LOKASI -- PREVIEW MAP (flutter_map + OpenStreetMap). Markernya
  // dari _lokasi.data, menampilkan ANGKA AQI di dalamnya (bukan cuma
  // titik warna polos) dan diwarnai sesuai kategori AQI kalau lokasinya
  // AKTIF, atau abu-abu (_warnaNonaktif) kalau lokasinya TIDAK AKTIF --
  // jadi admin bisa langsung bedakan lokasi aktif vs nonaktif di peta.
  // Ditambah TOMBOL ZOOM IN/OUT (_kontrolZoomPeta) selain gesture
  // pinch-zoom bawaan peta. Tap ikon "buka penuh" -> MapAirQualityPage.
  // ------------------------------------------------------
  Widget _kartuPeta() {
    final titikValid = _lokasiPunyaKoordinat;
    final jumlahAktif = titikValid.where((l) => (l["status"] ?? "") == "aktif").length;
    final jumlahNonaktif = titikValid.length - jumlahAktif;

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
              MaterialPageRoute(builder: (_) => const MapAirQualityPage()),
            ),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.open_in_full_rounded, size: 14, color: _Tema.teksAbu),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 320,
            child: _lokasi.loading
                ? Container(
              color: const Color(0xFFF3F4F6),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _Tema.aksen),
              ),
            )
                : _lokasi.error != null
                ? Container(
              color: const Color(0xFFF3F4F6),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_lokasi.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, color: _Tema.teksAbu)),
                const SizedBox(height: 8),
                TextButton(onPressed: _muatLokasi, child: const Text("Coba lagi")),
              ]),
            )
                : titikValid.isEmpty
                ? Container(
              color: const Color(0xFFF3F4F6),
              alignment: Alignment.center,
              child: const Text("Belum ada lokasi dengan koordinat",
                  style: TextStyle(fontSize: 11.5, color: _Tema.teksAbu)),
            )
                : Stack(
              fit: StackFit.expand,
              children: [
                Container(color: const Color(0xFFEAECEF)),
                FlutterMap(
                  mapController: _previewMapController,
                  options: const MapOptions(
                    initialCenter: LatLng(-2.5, 118.0),
                    initialZoom: 4.4,
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
                      markers: titikValid.map((l) {
                        final titik = _keLatLng(l)!;
                        final aktif = (l["status"] ?? "") == "aktif";
                        final aqi   = int.tryParse((l["aqi"] ?? "").toString());
                        final warna = aktif
                            ? (_warnaKategori[_kategoriAqiOpenWeather(aqi)] ?? _Tema.teksAbu)
                            : _warnaNonaktif;
                        return Marker(
                          point: titik,
                          width: 36, height: 36,
                          child: Opacity(
                            opacity: aktif ? 1 : 0.75,
                            child: Container(
                              decoration: BoxDecoration(
                                color: warna,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black.withOpacity(0.18))],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                aqi != null ? "$aqi" : "-",
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                              ),
                            ),
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
        if (!_lokasi.loading && _lokasi.error == null && titikValid.isNotEmpty) ...[
          // Legend kategori AQI (untuk lokasi aktif).
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: _warnaKategori.entries
                .where((e) => ["Baik", "Cukup baik", "Sedang", "Buruk", "Sangat buruk"].contains(e.key))
                .map((e) {
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: e.value, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(e.key, style: const TextStyle(fontSize: 10.5, color: _Tema.teksAbu)),
              ]);
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Ringkasan jumlah lokasi aktif vs nonaktif yang tampil di peta,
          // plus legend warna abu-abu buat status nonaktif.
          Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: _warnaNonaktif, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            const Text("Nonaktif", style: TextStyle(fontSize: 10.5, color: _Tema.teksAbu)),
            const SizedBox(width: 14),
            Icon(Icons.check_circle_rounded, size: 12, color: _Tema.aksenHijau),
            const SizedBox(width: 4),
            Text("$jumlahAktif aktif", style: const TextStyle(fontSize: 10.5, color: _Tema.teksAbu, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Icon(Icons.pause_circle_filled_rounded, size: 12, color: _warnaNonaktif),
            const SizedBox(width: 4),
            Text("$jumlahNonaktif nonaktif", style: const TextStyle(fontSize: 10.5, color: _Tema.teksAbu, fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
  }
}

// =========================================================
// TAMBAHAN -- widget carousel generik. Menggantikan 2 blok kode yang
// dulu duplikat (carousel historis & prediksi), sekaligus membenahi 2
// bug:
//  1. Kalau jumlah slide berubah (mis. setelah refresh), index halaman
//     lama bisa lebih besar dari jumlah slide yang baru -> di sini
//     di-reset otomatis lewat didUpdateWidget, supaya PageView tidak
//     error / nyangkut di halaman kosong.
//  2. Auto-slide timer sekarang berhenti sementara saat user sedang
//     menyentuh/menggeser carousel secara manual, jadi tidak lagi
//     "rebutan" animasi dengan swipe user.
// =========================================================
class _KartuCarousel extends StatefulWidget {
  final bool loading;
  final String? error;
  final List<Widget> slides;
  final VoidCallback onRetry;
  final String pesanKosong;

  const _KartuCarousel({
    required this.loading,
    required this.error,
    required this.slides,
    required this.onRetry,
    required this.pesanKosong,
  });

  @override
  State<_KartuCarousel> createState() => _KartuCarouselState();
}

class _KartuCarouselState extends State<_KartuCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _halaman = 0;
  bool _sedangDisentuh = false;

  @override
  void initState() {
    super.initState();
    _mulaiTimer();
  }

  @override
  void didUpdateWidget(covariant _KartuCarousel old) {
    super.didUpdateWidget(old);
    // Jumlah slide berubah (mis. setelah pull-to-refresh) -> reset ke
    // halaman pertama supaya tidak nyangkut di index yang sudah tidak ada.
    if (old.slides.length != widget.slides.length) {
      _halaman = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _mulaiTimer();
    }
  }

  void _mulaiTimer() {
    _timer?.cancel();
    if (widget.slides.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients || _sedangDisentuh) return;
      final jumlah = widget.slides.length;
      if (jumlah <= 1) return;
      final berikutnya = (_halaman + 1) % jumlah;
      _controller.animateToPage(
        berikutnya,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _indikatorHalaman(int jumlah, int aktif) {
    if (jumlah <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(jumlah, (i) {
        final isAktif = i == aktif;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isAktif ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isAktif ? _Tema.aksen : _Tema.cardBorder,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Container(
        width: double.infinity,
        height: 210,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Tema.cardBorder),
          boxShadow: _Tema.cardShadow(opacity: 0.04),
        ),
        child: const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: _Tema.aksen),
        ),
      );
    }

    if (widget.error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Tema.cardBorder),
          boxShadow: _Tema.cardShadow(opacity: 0.04),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: _Tema.bahaya),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.error!, style: const TextStyle(fontSize: 12.5, color: _Tema.teksAbu))),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: OutlinedButton(
              onPressed: widget.onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: _Tema.aksen,
                side: const BorderSide(color: _Tema.aksen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Coba lagi", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      );
    }

    if (widget.slides.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Tema.cardBorder),
          boxShadow: _Tema.cardShadow(opacity: 0.04),
        ),
        child: Text(widget.pesanKosong, style: const TextStyle(fontSize: 12.5, color: _Tema.teksAbu)),
      );
    }

    return Column(children: [
      SizedBox(
        height: 210,
        child: Listener(
          onPointerDown: (_) => _sedangDisentuh = true,
          onPointerUp: (_) {
            // Beri jeda sebentar sebelum auto-slide aktif lagi, supaya
            // tidak langsung "menyentak" begitu jari dilepas.
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) _sedangDisentuh = false;
            });
          },
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _halaman = i),
            itemBuilder: (context, index) => widget.slides[index],
          ),
        ),
      ),
      const SizedBox(height: 10),
      _indikatorHalaman(widget.slides.length, _halaman),
    ]);
  }
}

// =========================================================
// BAR CHART SEDERHANA (dipakai di carousel "Grafik historis per lokasi")
// =========================================================
class _BarChartPainter extends CustomPainter {
  final List<Map<String, Object>> data;
  _BarChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const paddingBottom = 20.0;
    final chartH = size.height - paddingBottom;
    final nilai  = data.map((e) => e["jumlah"] as double).toList();
    final maxV   = nilai.reduce(math.max).clamp(1, double.infinity);

    final slot = size.width / data.length;
    final barW = slot * 0.42;

    const styleLabel = TextStyle(color: _Tema.teksAbu, fontSize: 10, fontWeight: FontWeight.w600);

    for (int i = 0; i < data.length; i++) {
      final v    = nilai[i];
      final h    = (v / maxV) * chartH;
      final left = i * slot + (slot - barW) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, chartH - h, barW, h),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [_Tema.aksen, _Tema.aksen.withOpacity(0.6)],
        ).createShader(Rect.fromLTWH(left, chartH - h, barW, h));

      canvas.drawRRect(rect, paint);

      final tpHari = TextPainter(
        text: TextSpan(text: data[i]["hari"] as String, style: styleLabel),
        textDirection: TextDirection.ltr,
      )..layout();
      tpHari.paint(canvas, Offset(left + barW / 2 - tpHari.width / 2, chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) => old.data != data;
}

// =========================================================
// LINE CHART -- dipakai khusus di carousel "Grafik prediksi per lokasi"
// karena data prediksi lebih pas ditampilkan sebagai tren garis (naik/
// turun dari hari ke hari) dibanding bar chart.
// =========================================================
class _LineChartPainter extends CustomPainter {
  final List<Map<String, Object>> data;
  _LineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const paddingBottom = 20.0;
    const paddingTop = 18.0;
    final chartH = size.height - paddingBottom - paddingTop;
    final nilai  = data.map((e) => e["jumlah"] as double).toList();
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
    List<Offset> titik(double Function(int) yOf) {
      if (n == 1) {
        return [Offset(size.width / 2, yOf(0))];
      }
      return List.generate(n, (i) {
        final x = size.width * (i / (n - 1));
        return Offset(x, yOf(i));
      });
    }

    double yUntuk(int i) {
      final v = nilai[i];
      final t = (v - minV) / rangeV;
      return paddingTop + chartH * (1 - t);
    }

    final titikTitik = titik(yUntuk);

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
  bool shouldRepaint(covariant _LineChartPainter old) => old.data != data;
}