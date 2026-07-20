import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/session.dart';
import '../../services/users.dart';

// =========================================================
// WARNA TEMA (terang) -- selaras dengan dashboard user
// =========================================================
class _Tema {
  static const bg         = Color(0xFFF5F5F5);
  static const card       = Colors.white;
  static const cardBorder = Color(0xFFE0E0E0);
  static const teksAbu    = Color(0xFF8A8A8E);
  static const teksHitam  = Color(0xFF1C1C1E);
  static const aksen      = Color(0xFF2F80ED); // biru, selaras "PureAir"
  static const kuning     = Color(0xFFFFC107);

  // TAMBAHAN: shadow standar biar kartu tidak terasa flat
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
// Daftar slot jam prediksi (sinkron dgn $JAM_SLOT_LIST di PHP)
// =========================================================
const List<int> kJamSlotList = [8, 12, 17, 20, 22];

// =========================================================
// Daftar target yang diprediksi (sinkron dgn PHP)
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
// MODEL: 1 baris hasil prediksi (1 slot jam) dari tabel
// monitoring_prediksi
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
  if (aqi <= 50)  return AqiKategori("Baik",               const Color(0xFF34C759));
  if (aqi <= 100) return AqiKategori("Sedang",             const Color(0xFFFFC107));
  if (aqi <= 150) return AqiKategori("Tidak sehat (SG)",   const Color(0xFFFF9500));
  if (aqi <= 200) return AqiKategori("Tidak sehat",        const Color(0xFFFF3B30));
  if (aqi <= 300) return AqiKategori("Sangat tidak sehat", const Color(0xFFAF52DE));
  return             AqiKategori("Berbahaya",               const Color(0xFF8B0000));
}

// =========================================================
// SERVICE -- khusus sisi USER.
// =========================================================
class PrediksiService {
  static const String _endpoint = "${ApiService.baseUrl}/user/user_prediksi.php";

  static Future<List<String>> getDaftarLokasi() async {
    final res = await http
        .post(Uri.parse(_endpoint), body: {"action": "list_user"})
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

  // ---- Favorit KHUSUS prediksi: tabel `favorit_prediksi` di server,
  //      terpisah dari `favorit_lokasi` (Peta) & `favorit_histori`
  //      (Histori) ----

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
// HALAMAN USER: PREDIKSI KUALITAS UDARA (read-only)
// =========================================================
class PrediksiPage extends StatefulWidget {
  final String namaLokasi;
  const PrediksiPage({super.key, this.namaLokasi = "Pilih Lokasi"});

  @override
  State<PrediksiPage> createState() => _PrediksiPageState();
}

class _PrediksiPageState extends State<PrediksiPage> {
  late String                  _lokasiAktif = widget.namaLokasi;
  List<String>                 _daftarLokasi = [];
  List<PrediksiHarian>         _prediksi = [];
  List<PrediksiHarian>         _prediksiHarian = [];
  Map<String, InfoModelTarget> _model = {};
  int?                          _hariDipilih;
  DateTime?                     _tanggalFilter;
  final Map<int, int>           _jamDipilihPerHari = {};

  bool _loading = true;
  String? _error;

  // TAMBAHAN: state untuk tombol favorit (mirip halaman Peta/Histori)
  int  _userId        = 0; // 0 = belum login
  bool _isFavorit      = false;
  bool _favoritLoading = false;

  // TAMBAHAN: foto profil user, diambil dari Session supaya ikon
  // profil di header menampilkan foto asli, bukan placeholder.
  String? _fotoUrl;

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

  Future<void> _muatDaftarLokasi() async {
    try {
      final daftar = await PrediksiService.getDaftarLokasi();
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
          children: [
            // TAMBAHAN: handle bar kecil di atas bottom sheet
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _Tema.cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            ...daftar.map((nama) => ListTile(
              leading: const Icon(Icons.location_on_outlined, color: _Tema.teksAbu),
              title: Text(nama, style: const TextStyle(color: _Tema.teksHitam)),
              trailing: nama == _lokasiAktif
                  ? const Icon(Icons.check, color: _Tema.aksen)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _lokasiAktif = nama);
                _muatData();
              },
            )),
          ],
        );
      },
    );
  }

  Future<void> _pilihTanggal() async {
    if (_prediksiHarian.isEmpty) return;
    final dipilih = await showDatePicker(
      context: context,
      initialDate: _prediksiHarian.first.tanggal,
      firstDate: _prediksiHarian.first.tanggal.subtract(const Duration(days: 365)),
      lastDate: _prediksiHarian.last.tanggal.add(const Duration(days: 365)),
      builder: (context, child) {
        // TAMBAHAN: samakan warna date picker dengan aksen aplikasi
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _Tema.aksen,
              onPrimary: Colors.white,
              onSurface: _Tema.teksHitam,
            ),
          ),
          child: child!,
        );
      },
    );
    if (dipilih == null) return;

    int terdekat = 0;
    Duration selisihTerkecil = const Duration(days: 999999);
    for (int i = 0; i < _prediksiHarian.length; i++) {
      final selisih = _prediksiHarian[i].tanggal.difference(dipilih).abs();
      if (selisih < selisihTerkecil) {
        selisihTerkecil = selisih;
        terdekat = i;
      }
    }
    setState(() {
      _tanggalFilter = dipilih;
      _hariDipilih   = terdekat;
    });
  }

  Future<void> _muatData() async {
    if (_lokasiAktif == "Pilih Lokasi") {
      setState(() {
        _loading = false;
        _prediksi = [];
        _prediksiHarian = [];
        _model = {};
        _isFavorit = false;
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final hasil = await PrediksiService.getPrediksi(_lokasiAktif);
      if (!mounted) return;
      setState(() {
        _prediksi       = hasil.data;
        _prediksiHarian = PrediksiHarian.kelompokkanPerHari(hasil.data);
        _model          = hasil.model;
        _hariDipilih = null;
        _tanggalFilter = null;
        _jamDipilihPerHari.clear();
      });
      _cekFavoritStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // TAMBAHAN: cek status favorit lokasi yang sedang aktif, dipanggil
  // tiap kali lokasi berganti / data prediksi berhasil dimuat.
  Future<void> _cekFavoritStatus() async {
    if (_userId <= 0 || _lokasiAktif == "Pilih Lokasi") {
      if (mounted) setState(() => _isFavorit = false);
      return;
    }
    try {
      final hasil = await PrediksiService.cekFavorit(_lokasiAktif, userId: _userId);
      if (!mounted) return;
      setState(() => _isFavorit = hasil.isFavorit);
    } catch (_) {
      // Diamkan -- jangan ganggu tampilan prediksi kalau cek favorit gagal
    }
  }

  // TAMBAHAN: toggle favorit dengan optimistic update, sama polanya
  // dengan halaman Peta & Histori.
  Future<void> _toggleFavorit() async {
    if (_userId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan login ulang untuk memakai fitur favorit")),
      );
      return;
    }
    if (_lokasiAktif == "Pilih Lokasi" || _favoritLoading) return;

    final sebelum = _isFavorit;
    setState(() {
      _isFavorit = !_isFavorit;
      _favoritLoading = true;
    });
    try {
      final hasilBaru = await PrediksiService.toggleFavorit(_lokasiAktif, userId: _userId);
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

  void _unduhData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Fitur unduh data belum tersedia.")),
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
  // HEADER & JUDUL
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
          child: const Icon(Icons.menu, size: 24, color: _Tema.teksHitam),
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
        // TAMBAHAN: avatar sekarang menampilkan foto profil asli user
        // (dari Session), fallback ke ikon polos kalau belum ada foto
        // / gagal dimuat.
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
          "Prediksi Kualitas Udara",
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
      if (_lokasiAktif == "Pilih Lokasi")
        _buildBelumPilihLokasi()
      else if (_prediksiHarian.isEmpty)
        _buildKosong()
      else ...[
          _buildKartuPrediksi7Hari(),
          const SizedBox(height: 14),
          _buildKartuGrafik(),
          const SizedBox(height: 14),
          _buildKotakInfo(),
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
                  _lokasiAktif == "Pilih Lokasi" ? "Cari Lokasi" : _lokasiAktif,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _lokasiAktif == "Pilih Lokasi" ? _Tema.teksAbu : _Tema.teksHitam,
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
          onTap: _pilihTanggal,
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
                  _tanggalFilter == null ? "Cari Tanggal" : _formatTanggalSingkat(_tanggalFilter!),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _tanggalFilter == null ? _Tema.teksAbu : _Tema.teksHitam,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
      // TAMBAHAN: tombol favorit, cuma muncul kalau lokasi sudah dipilih
      // -- mirip ikon hati di halaman Peta & Histori.
      if (_lokasiAktif != "Pilih Lokasi") ...[
        const SizedBox(width: 10),
        _buildFavoritButton(),
      ],
    ]);
  }

  // TAMBAHAN: tombol bulat ikon hati, sama gaya dengan halaman Histori.
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

  Widget _buildBelumPilihLokasi() {
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
          "Pilih lokasi terlebih dahulu untuk\nmelihat prediksi kualitas udara.",
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
          "Belum ada hasil prediksi untuk\nlokasi ini saat ini.",
          textAlign: TextAlign.center,
          style: TextStyle(color: _Tema.teksAbu, fontSize: 13),
        ),
      ]),
    );
  }

  // -------------------------------------------------------
  // KARTU: PREDIKSI AQI 7 HARI KE DEPAN
  // -------------------------------------------------------
  Widget _buildKartuPrediksi7Hari() {
    final daftar = _prediksiHarian.take(7).toList();
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
        const Text("Prediksi AQI 7 Hari Ke Depan",
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
        const SizedBox(height: 12),
        SizedBox(
          height: 158,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: daftar.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) => _kartuHari(i, daftar[i]),
          ),
        ),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Icon(Icons.info_outline, size: 13, color: _Tema.teksAbu),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              "Data Diperbarui setiap saat berdasarkan data cuaca",
              style: TextStyle(fontSize: 10.5, color: _Tema.teksAbu),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _kartuHari(int i, PrediksiHarian p) {
    final aktif = (_hariDipilih ?? 0) == i;
    final k     = kategoriDariAqi(p.aqi);
    final label = i == 0 ? "Hari ini" : i == 1 ? "Besok" : _namaHari(p.tanggal);

    return InkWell(
      onTap: () => setState(() => _hariDipilih = i),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: aktif ? _Tema.aksen.withOpacity(0.06) : _Tema.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: aktif ? _Tema.aksen : _Tema.cardBorder, width: aktif ? 1.4 : 1),
          boxShadow: aktif ? _Tema.shadowTipis : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(children: [
            Text(label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
            Text(_formatTanggalSingkat(p.tanggal),
                style: const TextStyle(fontSize: 9.5, color: _Tema.teksAbu)),
          ]),
          Text(p.aqi.toStringAsFixed(0),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _Tema.teksHitam)),
          Text(k.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, color: k.warna, fontWeight: FontWeight.w600)),
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: k.warna, shape: BoxShape.circle)),
          InkWell(
            onTap: () => _bukaDetailHari(i),
            borderRadius: BorderRadius.circular(12),
            child: Icon(Icons.expand_more, size: 18, color: aktif ? _Tema.aksen : _Tema.teksAbu),
          ),
        ]),
      ),
    );
  }

  // -------------------------------------------------------
  // KARTU: GRAFIK PREDIKSI
  // -------------------------------------------------------
  Widget _buildKartuGrafik() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 12),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.cardBorder),
        boxShadow: _Tema.shadowKartu,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text("Grafik Prediksi Kualitas Udara",
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: LayoutBuilder(builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _pilihHariTerdekat(d.localPosition, size),
              onPanUpdate: (d) => _pilihHariTerdekat(d.localPosition, size),
              child: CustomPaint(
                painter: _PrediksiChartPainter(
                  _prediksiHarian,
                  "aqi",
                  indexAktif: _hariDipilih ?? 0,
                ),
                child: Container(),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 10, height: 10,
              decoration: const BoxDecoration(color: _Tema.aksen, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text("Prediksi AQI",
              style: TextStyle(fontSize: 11, color: _Tema.teksAbu, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }

  void _pilihHariTerdekat(Offset pos, Size size) {
    if (_prediksiHarian.isEmpty) return;
    const leftPadding = 30.0;
    final lebar = size.width - leftPadding;
    final stepX = _prediksiHarian.length > 1 ? lebar / (_prediksiHarian.length - 1) : lebar;
    final index = ((pos.dx - leftPadding) / stepX).round().clamp(0, _prediksiHarian.length - 1);
    if (_hariDipilih != index) setState(() => _hariDipilih = index);
  }

  // -------------------------------------------------------
  // KOTAK PERINGATAN & TOMBOL UNDUH
  // -------------------------------------------------------
  Widget _buildKotakInfo() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: _kotakPeringatan(
          "Informasi kualitas udara dan prediksi dapat berubah sewaktu-waktu berdasarkan kondisi lingkungan dan data sensor.",
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _kotakPeringatan(
          "Disarankan menggunakan masker saat kualitas udara berada pada kategori tidak sehat.",
        ),
      ),
    ]);
  }

  Widget _kotakPeringatan(String teks) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Tema.cardBorder),
        boxShadow: _Tema.shadowTipis,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _Tema.kuning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.warning_amber_rounded, size: 14, color: _Tema.kuning),
        ),
        const SizedBox(height: 6),
        Text(teks, style: const TextStyle(fontSize: 10, color: _Tema.teksAbu, height: 1.3)),
      ]),
    );
  }

  Widget _buildTombolUnduh() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _unduhData,
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

  // -------------------------------------------------------
  // BOTTOM SHEET: DETAIL PER HARI (jam & polutan lain)
  // -------------------------------------------------------
  void _bukaDetailHari(int index) {
    if (index < 0 || index >= _prediksiHarian.length) return;
    final p = _prediksiHarian[index];
    int jamLokal = _jamDipilihPerHari[index] ?? kJamSlotList.first;

    showModalBottomSheet(
      context: context,
      backgroundColor: _Tema.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                // TAMBAHAN: handle bar kecil di atas bottom sheet
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: _Tema.cardBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(children: [
                  const Icon(Icons.calendar_month, size: 16, color: _Tema.aksen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_formatTanggalLengkap(p.tanggal),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
                  ),
                ]),
                const SizedBox(height: 12),
                _buildPemilihJamSheet(jamLokal, (j) {
                  setSheet(() => jamLokal = j);
                  _jamDipilihPerHari[index] = j;
                }),
                const SizedBox(height: 12),
                _buildDetailJam(p.tanggal, jamLokal),
                if (_model.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildAkurasiCard(),
                ],
              ]),
            ),
          );
        });
      },
    );
  }

  Widget _buildPemilihJamSheet(int jamAktif, ValueChanged<int> onPilih) {
    return Row(
      children: kJamSlotList.map((jam) {
        final aktif = jam == jamAktif;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => onPilih(jam),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: aktif ? _Tema.aksen : _Tema.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: aktif ? _Tema.aksen : _Tema.cardBorder),
                  boxShadow: aktif ? _Tema.shadowTipis : null,
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
        color: _Tema.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(kLabelTarget[target] ?? target,
              style: const TextStyle(fontSize: 11, color: _Tema.teksAbu, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            "${nilai.toStringAsFixed(1)}${kSatuanTarget[target]?.isNotEmpty == true ? " ${kSatuanTarget[target]}" : ""}",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _Tema.teksHitam, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildAkurasiCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Tema.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Akurasi model per parameter",
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _Tema.teksHitam)),
        const SizedBox(height: 10),
        ...kDaftarTarget.where((t) => _model.containsKey(t)).map((t) {
          final m = _model[t]!;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 52, child: Text(kLabelTarget[t] ?? t,
                  style: const TextStyle(fontSize: 11.5, color: _Tema.teksHitam, fontWeight: FontWeight.w500))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (m.akurasi / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: _Tema.card,
                    valueColor: AlwaysStoppedAnimation(
                      m.akurasi >= 70 ? const Color(0xFF34C759)
                          : m.akurasi >= 50 ? const Color(0xFFFFC107)
                          : const Color(0xFFFF3B30),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 40, child: Text("${m.akurasi.toStringAsFixed(0)}%",
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, color: _Tema.teksAbu))),
            ]),
          );
        }),
        const SizedBox(height: 6),
        Text(
          "Dilatih dari ${_model.values.first.jumlahDataLatih > 0 ? _model.values.first.jumlahDataLatih : "-"} hari data histori"
              "${_model["aqi"]?.trainedAt != null ? " • ${_formatTanggalJam(_model["aqi"]!.trainedAt!)}" : ""}",
          style: const TextStyle(fontSize: 10, color: _Tema.teksAbu),
        ),
      ]),
    );
  }

  // -------------------------------------------------------
  // FORMAT TANGGAL
  // -------------------------------------------------------
  String _namaHari(DateTime t) {
    const nama = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"];
    return nama[t.weekday - 1];
  }

  String _formatTanggalLengkap(DateTime t) {
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    return "${t.day} ${b[t.month - 1]} ${t.year}";
  }

  String _formatTanggalSingkat(DateTime t) {
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    return "${t.day}/${t.month.toString().padLeft(2, '0')}";
  }

  String _formatTanggalJam(DateTime t) {
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    return "${t.day} ${b[t.month - 1]} ${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }
}

// =========================================================
// GRAFIK GARIS PROYEKSI AQI (mengikuti gaya mockup: skala 0..max
// dengan garis bantu & label sumbu Y)
// =========================================================
class _PrediksiChartPainter extends CustomPainter {
  final List<PrediksiHarian> data;
  final String target;
  final int? indexAktif;
  _PrediksiChartPainter(this.data, this.target, {this.indexAktif});

  static const double _leftPadding = 30.0;
  static const double _paddingBottom = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final nilai = data.map((e) => e.nilai(target)).toList();
    final maxV  = nilai.reduce(math.max);
    final niceMax = ((maxV / 50).ceil() * 50).toDouble();
    final effectiveMax = niceMax <= 0 ? 50.0 : niceMax;

    final chartH   = size.height - _paddingBottom;
    final lebarX   = size.width - _leftPadding;
    final stepX    = data.length > 1 ? lebarX / (data.length - 1) : lebarX;

    const styleSumbu = TextStyle(color: _Tema.teksAbu, fontSize: 9.5);
    final gridPaint = Paint()
      ..color = _Tema.cardBorder
      ..strokeWidth = 1;

    // Sumbu Y & garis bantu horizontal
    for (int i = 0; i <= 3; i++) {
      final nilaiLabel = effectiveMax * (3 - i) / 3;
      final y = (chartH) * i / 3;
      canvas.drawLine(Offset(_leftPadding, y), Offset(size.width, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: nilaiLabel.toStringAsFixed(0), style: styleSumbu),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_leftPadding - tp.width - 6, y - tp.height / 2));
    }

    final linePaint = Paint()
      ..color = _Tema.aksen
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_Tema.aksen.withOpacity(0.20), _Tema.aksen.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(_leftPadding, 0, lebarX, chartH));
    final dotPaint = Paint()..color = _Tema.aksen;
    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path(), fillPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = _leftPadding + i * stepX;
      final y = chartH - (nilai[i] / effectiveMax * chartH);
      points.add(Offset(x, y));
      if (i == 0) { path.moveTo(x, y); fillPath.moveTo(x, chartH); fillPath.lineTo(x, y); }
      else { path.lineTo(x, y); fillPath.lineTo(x, y); }
    }
    fillPath.lineTo(points.last.dx, chartH);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    const styleN = TextStyle(color: _Tema.teksAbu, fontSize: 9.5);
    const styleA = TextStyle(color: _Tema.teksHitam, fontSize: 9.5, fontWeight: FontWeight.w700);
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];

    for (int i = 0; i < points.length; i++) {
      final aktif = i == indexAktif;
      if (!aktif) {
        canvas.drawCircle(points[i], 3, dotPaint);
        canvas.drawCircle(points[i], 3, dotBorderPaint);
      }
      final tp = TextPainter(
        text: TextSpan(text: "${data[i].tanggal.day} ${b[data[i].tanggal.month - 1]}", style: aktif ? styleA : styleN),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, chartH + 6));
    }

    // Titik aktif digambar TERAKHIR supaya selalu tampil di atas titik lain
    if (indexAktif != null && indexAktif! < points.length) {
      final p = points[indexAktif!];
      canvas.drawCircle(p, 8, Paint()..color = _Tema.aksen.withOpacity(0.15));
      canvas.drawCircle(p, 5, Paint()..color = _Tema.aksen);
      canvas.drawCircle(p, 5, dotBorderPaint..strokeWidth = 1.8);
    }
  }

  @override
  bool shouldRepaint(covariant _PrediksiChartPainter old) =>
      old.data != data || old.target != target || old.indexAktif != indexAktif;
}