import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/users.dart';

// =========================================================
// WARNA TEMA -- selaras dengan halaman lain PureAir
// =========================================================
class _Tema {
  static const bg         = Color(0xFFF5F5F5);
  static const card       = Colors.white;
  static const cardBorder = Color(0xFFE0E0E0);
  static const teksAbu    = Color(0xFF8A8A8E);
  static const teksHitam  = Color(0xFF1C1C1E);
  static const aksen      = Color(0xFF2F80ED);
}

// =========================================================
// MODEL: data polutan 1 lokasi dari tabel monitoring
// =========================================================
class DataPolutan {
  final String id;
  final String namaLokasi;
  final double aqi;
  final double pm25;
  final double pm10;
  final double co;
  final double no2;
  final double so2;
  final double o3;
  final String status;
  final String updatedAt;

  DataPolutan({
    required this.id,
    required this.namaLokasi,
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.co,
    required this.no2,
    required this.so2,
    required this.o3,
    required this.status,
    required this.updatedAt,
  });

  factory DataPolutan.fromJson(Map<String, dynamic> j) {
    double d(String k) => double.tryParse((j[k] ?? "0").toString()) ?? 0;
    return DataPolutan(
      id:         (j["id"] ?? "").toString(),
      namaLokasi: (j["nama_lokasi"] ?? "").toString(),
      aqi:        d("aqi"),
      pm25:       d("pm25"),
      pm10:       d("pm10"),
      co:         d("co"),
      no2:        d("no2"),
      so2:        d("so2"),
      o3:         d("o3"),
      status:     (j["status"] ?? "").toString(),
      updatedAt:  (j["updated_at"] ?? "").toString(),
    );
  }
}

// =========================================================
// MODEL: 1 item hasil pencarian kota
// =========================================================
class HasilCariKota {
  final String id;
  final String namaLokasi;

  HasilCariKota({required this.id, required this.namaLokasi});

  factory HasilCariKota.fromJson(Map<String, dynamic> j) {
    return HasilCariKota(
      id:         (j["id"] ?? "").toString(),
      namaLokasi: (j["nama_lokasi"] ?? "").toString(),
    );
  }
}

// =========================================================
// SERVICE
// =========================================================
class PolutanService {
  static const String _endpoint = "${ApiService.baseUrl}/user/polutan.php";

  static Future<List<HasilCariKota>> cariKota(String keyword) async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action":  "search",
      "keyword": keyword,
    }).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body);
    if (body["status"] != true) return [];

    final List data = body["data"] ?? [];
    return data
        .map((e) => HasilCariKota.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<DataPolutan?> getPolutan(String namaLokasi) async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action":      "get_polutan",
      "nama_lokasi": namaLokasi,
    }).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body);
    if (body["status"] != true) return null;

    return DataPolutan.fromJson(Map<String, dynamic>.from(body["data"]));
  }
}

// =========================================================
// HELPER: kategori per polutan
// =========================================================
class _KategoriInfo {
  final String label;
  final Color  warna;
  _KategoriInfo(this.label, this.warna);
}

_KategoriInfo _kategoriAqi(double v) {
  if (v <= 50)  return _KategoriInfo("Baik",             const Color(0xFF34C759));
  if (v <= 100) return _KategoriInfo("Sedang",           const Color(0xFFFFC107));
  if (v <= 150) return _KategoriInfo("Tidak Sehat",      const Color(0xFFFF9500));
  if (v <= 200) return _KategoriInfo("Tidak Sehat",      const Color(0xFFFF3B30));
  if (v <= 300) return _KategoriInfo("Sangat Tdk Sehat", const Color(0xFFAF52DE));
  return              _KategoriInfo("Berbahaya",          const Color(0xFF8B0000));
}

_KategoriInfo _kategoriPm25(double v) {
  if (v <= 12)  return _KategoriInfo("Baik",             const Color(0xFF34C759));
  if (v <= 35)  return _KategoriInfo("Sedang",           const Color(0xFFFFC107));
  if (v <= 55)  return _KategoriInfo("Tidak Sehat",      const Color(0xFFFF9500));
  if (v <= 150) return _KategoriInfo("Tidak Sehat",      const Color(0xFFFF3B30));
  if (v <= 250) return _KategoriInfo("Sangat Tdk Sehat", const Color(0xFFAF52DE));
  return              _KategoriInfo("Berbahaya",          const Color(0xFF8B0000));
}

_KategoriInfo _kategoriPm10(double v) {
  if (v <= 54)  return _KategoriInfo("Baik",             const Color(0xFF34C759));
  if (v <= 154) return _KategoriInfo("Sedang",           const Color(0xFFFFC107));
  if (v <= 254) return _KategoriInfo("Tidak Sehat",      const Color(0xFFFF9500));
  if (v <= 354) return _KategoriInfo("Tidak Sehat",      const Color(0xFFFF3B30));
  if (v <= 424) return _KategoriInfo("Sangat Tdk Sehat", const Color(0xFFAF52DE));
  return              _KategoriInfo("Berbahaya",          const Color(0xFF8B0000));
}

_KategoriInfo _kategoriCo(double v) {
  if (v <= 4.4)  return _KategoriInfo("Baik",            const Color(0xFF34C759));
  if (v <= 9.4)  return _KategoriInfo("Sedang",          const Color(0xFFFFC107));
  if (v <= 12.4) return _KategoriInfo("Tidak Sehat",     const Color(0xFFFF9500));
  if (v <= 15.4) return _KategoriInfo("Tidak Sehat",     const Color(0xFFFF3B30));
  if (v <= 30.4) return _KategoriInfo("Sangat Tdk Sehat",const Color(0xFFAF52DE));
  return               _KategoriInfo("Berbahaya",         const Color(0xFF8B0000));
}

_KategoriInfo _kategoriNo2(double v) {
  if (v <= 53)  return _KategoriInfo("Baik",             const Color(0xFF34C759));
  if (v <= 100) return _KategoriInfo("Sedang",           const Color(0xFFFFC107));
  if (v <= 360) return _KategoriInfo("Tidak Sehat",      const Color(0xFFFF9500));
  if (v <= 649) return _KategoriInfo("Tidak Sehat",      const Color(0xFFFF3B30));
  if (v <= 1249)return _KategoriInfo("Sangat Tdk Sehat", const Color(0xFFAF52DE));
  return              _KategoriInfo("Berbahaya",          const Color(0xFF8B0000));
}

_KategoriInfo _kategoriSo2(double v) {
  if (v <= 35)  return _KategoriInfo("Baik",             const Color(0xFF34C759));
  if (v <= 75)  return _KategoriInfo("Sedang",           const Color(0xFFFFC107));
  if (v <= 185) return _KategoriInfo("Tidak Sehat",      const Color(0xFFFF9500));
  if (v <= 304) return _KategoriInfo("Tidak Sehat",      const Color(0xFFFF3B30));
  if (v <= 604) return _KategoriInfo("Sangat Tdk Sehat", const Color(0xFFAF52DE));
  return              _KategoriInfo("Berbahaya",          const Color(0xFF8B0000));
}

_KategoriInfo _kategoriO3(double v) {
  if (v <= 54)  return _KategoriInfo("Baik",             const Color(0xFF34C759));
  if (v <= 70)  return _KategoriInfo("Sedang",           const Color(0xFFFFC107));
  if (v <= 85)  return _KategoriInfo("Tidak Sehat",      const Color(0xFFFF9500));
  if (v <= 105) return _KategoriInfo("Tidak Sehat",      const Color(0xFFFF3B30));
  if (v <= 200) return _KategoriInfo("Sangat Tdk Sehat", const Color(0xFFAF52DE));
  return              _KategoriInfo("Berbahaya",          const Color(0xFF8B0000));
}

_KategoriInfo _getKategori(String param, double nilai) {
  switch (param) {
    case "pm25": return _kategoriPm25(nilai);
    case "pm10": return _kategoriPm10(nilai);
    case "co":   return _kategoriCo(nilai);
    case "no2":  return _kategoriNo2(nilai);
    case "so2":  return _kategoriSo2(nilai);
    case "o3":   return _kategoriO3(nilai);
    default:     return _kategoriAqi(nilai);
  }
}

// =========================================================
// HALAMAN INFO POLUTAN
// =========================================================
class InfoPolutanPage extends StatefulWidget {
  const InfoPolutanPage({super.key});

  @override
  State<InfoPolutanPage> createState() => _InfoPolutanPageState();
}

class _InfoPolutanPageState extends State<InfoPolutanPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode             _searchFocus = FocusNode();

  List<HasilCariKota> _hasilCari   = [];
  bool                _showDropdown = false;
  bool                _loadingCari  = false;

  DataPolutan? _dataPolutan;
  bool         _loadingPolutan = false;
  String?      _errorPolutan;

  @override
  void initState() {
    super.initState();
    _muatSemuaLokasi();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _muatSemuaLokasi() async {
    setState(() => _loadingCari = true);
    try {
      final hasil = await PolutanService.cariKota("");
      if (!mounted) return;
      setState(() {
        _hasilCari    = hasil;
        _showDropdown = false;
      });
    } catch (_) {}
    if (mounted) setState(() => _loadingCari = false);
  }

  Future<void> _onSearchChanged(String value) async {
    if (value.trim().isEmpty) {
      _muatSemuaLokasi();
      setState(() => _showDropdown = false);
      return;
    }

    setState(() { _loadingCari = true; _showDropdown = true; });

    try {
      final hasil = await PolutanService.cariKota(value.trim());
      if (!mounted) return;
      setState(() => _hasilCari = hasil);
    } catch (_) {}

    if (mounted) setState(() => _loadingCari = false);
  }

  Future<void> _pilihLokasi(String namaLokasi) async {
    _searchCtrl.text = namaLokasi;
    _searchFocus.unfocus();
    setState(() { _showDropdown = false; _loadingPolutan = true; _errorPolutan = null; });

    try {
      final data = await PolutanService.getPolutan(namaLokasi);
      if (!mounted) return;
      setState(() => _dataPolutan = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorPolutan = "Gagal memuat data polutan");
    } finally {
      if (mounted) setState(() => _loadingPolutan = false);
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
              child: GestureDetector(
                onTap: () {
                  _searchFocus.unfocus();
                  setState(() => _showDropdown = false);
                },
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    _buildSearchBar(),
                    if (_showDropdown) _buildDropdownHasilCari(),
                    const SizedBox(height: 14),
                    if (_loadingPolutan)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_errorPolutan != null)
                      _buildErrorCard()
                    else if (_dataPolutan == null)
                        _buildBelumPilih()
                      else ...[
                          _buildLabelSection("Parameter saat ini"),
                          const SizedBox(height: 10),
                          _buildGridPolutan(),
                          const SizedBox(height: 14),
                          _buildKategoriAqiCard(),
                          const SizedBox(height: 10),
                          _buildInfoCard(
                            icon: Icons.info_outline,
                            judul: "Informasi Polutan",
                            subjudul: "Apa itu polutan dan kenapa perlu dipantau",
                            onTap: () => _showInfoPolutanSheet(),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoCard(
                            icon: Icons.monitor_heart_outlined,
                            judul: "Tips Sehat",
                            subjudul: "Cara melindungi diri dari udara buruk",
                            onTap: () => _showTipsSehatSheet(),
                          ),
                          const SizedBox(height: 8),
                          if (_dataPolutan?.updatedAt.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                "Terakhir diperbarui: ${_dataPolutan!.updatedAt}",
                                style: const TextStyle(fontSize: 10.5, color: _Tema.teksAbu),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                    const SizedBox(height: 24),
                  ],
                ),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.08))],
            ),
            child: const Icon(Icons.arrow_back, size: 18, color: _Tema.teksHitam),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text("Info Polutan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
            Text("Parameter yang dipantau PureAir",
                style: TextStyle(fontSize: 11.5, color: _Tema.teksAbu)),
          ]),
        ),
        Row(children: const [
          Icon(Icons.air, color: _Tema.aksen, size: 22),
          SizedBox(width: 4),
          Text("PureAir", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _Tema.aksen)),
        ]),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _showDropdown ? _Tema.aksen : _Tema.cardBorder),
        boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black.withOpacity(0.05))],
      ),
      child: Row(children: [
        const SizedBox(width: 12),
        const Icon(Icons.search, size: 18, color: _Tema.teksAbu),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller:  _searchCtrl,
            focusNode:   _searchFocus,
            onChanged:   _onSearchChanged,
            onTap:       () => setState(() => _showDropdown = _hasilCari.isNotEmpty),
            style: const TextStyle(fontSize: 14, color: _Tema.teksHitam),
            decoration: const InputDecoration(
              hintText:    "Cari nama kota...",
              hintStyle:   TextStyle(fontSize: 13.5, color: _Tema.teksAbu),
              border:      InputBorder.none,
              isDense:     true,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        if (_searchCtrl.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: _Tema.teksAbu),
            onPressed: () {
              _searchCtrl.clear();
              setState(() { _showDropdown = false; _dataPolutan = null; _errorPolutan = null; });
              _muatSemuaLokasi();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          )
        else
          const SizedBox(width: 12),
      ]),
    );
  }

  Widget _buildDropdownHasilCari() {
    if (_loadingCari) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _Tema.cardBorder),
          boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.06))],
        ),
        child: const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_hasilCari.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _Tema.cardBorder),
        ),
        child: const Text("Kota tidak ditemukan",
            style: TextStyle(fontSize: 13, color: _Tema.teksAbu)),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Tema.cardBorder),
        boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.06))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: _hasilCari.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 14, endIndent: 14),
          itemBuilder: (_, i) {
            final item = _hasilCari[i];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.location_on_outlined, size: 18, color: _Tema.aksen),
              title: Text(item.namaLokasi,
                  style: const TextStyle(fontSize: 13.5, color: _Tema.teksHitam)),
              onTap: () => _pilihLokasi(item.namaLokasi),
            );
          },
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
      ),
      child: Column(children: const [
        Icon(Icons.search, size: 36, color: _Tema.teksAbu),
        SizedBox(height: 10),
        Text("Cari nama kota di atas\nuntuk melihat info polutan.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _Tema.teksAbu)),
      ]),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(children: [
        const Icon(Icons.cloud_off, size: 36, color: _Tema.teksAbu),
        const SizedBox(height: 8),
        Text(_errorPolutan!, style: const TextStyle(color: _Tema.teksAbu, fontSize: 13)),
      ]),
    );
  }

  Widget _buildLabelSection(String label) {
    return Text(label,
        style: const TextStyle(fontSize: 12.5, color: _Tema.teksAbu, fontWeight: FontWeight.w500));
  }

  Widget _buildGridPolutan() {
    final d = _dataPolutan!;
    final params = [
      {"label": "PM2.5", "nilai": d.pm25, "satuan": "µg/m³", "param": "pm25"},
      {"label": "PM10",  "nilai": d.pm10, "satuan": "µg/m³", "param": "pm10"},
      {"label": "CO",    "nilai": d.co,   "satuan": "ppm",   "param": "co"},
      {"label": "NO2",   "nilai": d.no2,  "satuan": "ppb",   "param": "no2"},
      {"label": "SO2",   "nilai": d.so2,  "satuan": "ppb",   "param": "so2"},
      {"label": "O3",    "nilai": d.o3,   "satuan": "ppb",   "param": "o3"},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: params.map((p) {
        final nilai    = p["nilai"] as double;
        final param    = p["param"] as String;
        final kat      = _getKategori(param, nilai);
        return _kartuPolutan(
          label:  p["label"] as String,
          nilai:  nilai,
          satuan: p["satuan"] as String,
          kat:    kat,
        );
      }).toList(),
    );
  }

  Widget _kartuPolutan({
    required String       label,
    required double       nilai,
    required String       satuan,
    required _KategoriInfo kat,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: _Tema.teksAbu, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            nilai % 1 == 0 ? nilai.toStringAsFixed(0) : nilai.toStringAsFixed(1),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _Tema.teksHitam),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: kat.warna.withOpacity(0.13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(kat.label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kat.warna)),
          ),
        ],
      ),
    );
  }

  Widget _buildKategoriAqiCard() {
    final kategori = [
      {"range": "0 – 50",    "label": "Baik",              "warna": const Color(0xFF34C759)},
      {"range": "51 – 100",  "label": "Sedang",            "warna": const Color(0xFFFFC107)},
      {"range": "101 – 150", "label": "Tidak Sehat",       "warna": const Color(0xFFFF9500)},
      {"range": "151 – 200", "label": "Sangat Tidak Sehat","warna": const Color(0xFFFF3B30)},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Kategori AQI",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
        const SizedBox(height: 10),
        ...kategori.map((k) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: k["warna"] as Color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              child: Text(k["range"] as String,
                  style: const TextStyle(fontSize: 12, color: _Tema.teksAbu)),
            ),
            Text(k["label"] as String,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: _Tema.teksHitam)),
          ]),
        )),
      ]),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String   judul,
    required String   subjudul,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _Tema.cardBorder),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _Tema.aksen.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: _Tema.aksen),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(judul,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _Tema.teksHitam)),
            const SizedBox(height: 2),
            Text(subjudul,
                style: const TextStyle(fontSize: 11.5, color: _Tema.teksAbu)),
          ])),
          const Icon(Icons.chevron_right, size: 18, color: _Tema.teksAbu),
        ]),
      ),
    );
  }

  // -------------------------------------------------------
  // Bottom sheet: Informasi Polutan
  // -------------------------------------------------------
  void _showInfoPolutanSheet() {
    final infos = [
      {
        "label": "PM2.5",
        "desc":  "Partikel halus berdiameter < 2,5 µm yang dapat masuk jauh ke dalam paru-paru dan aliran darah. Sumbernya antara lain asap kendaraan, pembakaran, dan industri.",
      },
      {
        "label": "PM10",
        "desc":  "Partikel kasar berdiameter < 10 µm. Biasa berasal dari debu jalan, konstruksi, dan pertanian. Dapat mengiritasi saluran pernapasan.",
      },
      {
        "label": "CO (Karbon Monoksida)",
        "desc":  "Gas tidak berwarna dan tidak berbau hasil pembakaran tidak sempurna. Dalam kadar tinggi dapat mengganggu pengikatan oksigen oleh darah.",
      },
      {
        "label": "NO₂ (Nitrogen Dioksida)",
        "desc":  "Gas coklat kemerahan dari emisi kendaraan dan pembangkit listrik. Dapat menyebabkan iritasi saluran napas dan memperburuk asma.",
      },
      {
        "label": "SO₂ (Sulfur Dioksida)",
        "desc":  "Gas berbau tajam hasil pembakaran bahan bakar fosil dan proses industri. Berkontribusi pada hujan asam dan gangguan pernapasan.",
      },
      {
        "label": "O₃ (Ozon Permukaan)",
        "desc":  "Terbentuk dari reaksi kimia NO₂ dan senyawa organik di bawah sinar matahari. Berbeda dari ozon pelindung di stratosfer, ozon permukaan berbahaya bagi paru-paru.",
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _Tema.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _Tema.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text("Informasi Polutan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
            const SizedBox(height: 4),
            const Text("Apa itu polutan dan kenapa perlu dipantau",
                style: TextStyle(fontSize: 12, color: _Tema.teksAbu)),
            const SizedBox(height: 16),
            ...infos.map((info) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _Tema.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _Tema.cardBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info["label"]!,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Tema.aksen)),
                const SizedBox(height: 6),
                Text(info["desc"]!,
                    style: const TextStyle(fontSize: 12.5, color: _Tema.teksHitam, height: 1.5)),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // Bottom sheet: Tips Sehat
  // -------------------------------------------------------
  void _showTipsSehatSheet() {
    final tips = [
      {
        "icon": Icons.masks_outlined,
        "judul": "Gunakan masker",
        "desc":  "Gunakan masker N95 atau KN95 saat kualitas udara buruk, terutama di luar ruangan.",
      },
      {
        "icon": Icons.home_outlined,
        "judul": "Tetap di dalam ruangan",
        "desc":  "Tutup jendela dan pintu saat AQI tinggi. Gunakan penyaring udara (air purifier) jika tersedia.",
      },
      {
        "icon": Icons.directions_run_outlined,
        "judul": "Hindari aktivitas berat di luar",
        "desc":  "Tunda olahraga di luar ruangan ketika AQI di atas 100, terutama bagi kelompok sensitif.",
      },
      {
        "icon": Icons.water_drop_outlined,
        "judul": "Perbanyak minum air putih",
        "desc":  "Hidrasi yang cukup membantu tubuh membuang racun dan menjaga kesehatan saluran napas.",
      },
      {
        "icon": Icons.local_hospital_outlined,
        "judul": "Perhatikan gejala",
        "desc":  "Segera konsultasi ke dokter jika mengalami sesak napas, batuk berkepanjangan, atau iritasi mata.",
      },
      {
        "icon": Icons.eco_outlined,
        "judul": "Tanam tanaman penyaring udara",
        "desc":  "Beberapa tanaman seperti lidah mertua dan peace lily dapat membantu menyaring polutan dalam ruangan.",
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _Tema.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _Tema.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text("Tips Sehat",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
            const SizedBox(height: 4),
            const Text("Cara melindungi diri dari udara buruk",
                style: TextStyle(fontSize: 12, color: _Tema.teksAbu)),
            const SizedBox(height: 16),
            ...tips.map((t) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _Tema.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _Tema.cardBorder),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _Tema.aksen.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(t["icon"] as IconData, size: 18, color: _Tema.aksen),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t["judul"] as String,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _Tema.teksHitam)),
                  const SizedBox(height: 4),
                  Text(t["desc"] as String,
                      style: const TextStyle(fontSize: 12, color: _Tema.teksAbu, height: 1.5)),
                ])),
              ]),
            )),
          ],
        ),
      ),
    );
  }
}