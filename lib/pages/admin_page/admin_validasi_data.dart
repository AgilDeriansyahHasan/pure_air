import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/users.dart';

class AppColors {
  static const bg = Color(0xFFF1F5F4);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF14213D);
  static const muted = Color(0xFF5B6B73);
  static const mutedSoft = Color(0xFF94A3A0);
  static const accent = Color(0xFF0E7C86);
  static const accentSoft = Color(0xFFE3F0F1);
  static const success = Color(0xFF2F9E44);
  static const successSoft = Color(0xFFE7F6EA);
  static const danger = Color(0xFFD64550);
  static const dangerSoft = Color(0xFFFBE9EA);
  static const warning = Color(0xFFC9852A);
  static const warningSoft = Color(0xFFFCEEDD);
  static const border = Color(0xFFE2E8E6);

  // Shadow tipis yang dipakai konsisten di semua kartu "surface" --
  // supaya kartu kelihatan sedikit terangkat, tidak flat/menempel
  // ke background seperti sebelumnya.
  static List<BoxShadow> cardShadow({double opacity = 0.045, double blur = 16}) => [
    BoxShadow(
      color: Colors.black.withOpacity(opacity),
      blurRadius: blur,
      offset: const Offset(0, 6),
    ),
  ];
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color soft;
  _StatItem(this.label, this.value, this.icon, this.color, this.soft);
}

class _CheckItem {
  final IconData icon;
  final String title;
  final String desc;
  final int pass;
  final int total;
  _CheckItem(this.icon, this.title, this.desc, this.pass, this.total);
}

class AdminValidasiDataPage extends StatefulWidget {
  const AdminValidasiDataPage({super.key});

  @override
  State<AdminValidasiDataPage> createState() => _AdminValidasiDataPageState();
}

class _AdminValidasiDataPageState extends State<AdminValidasiDataPage> {
  bool loading = false;
  List dataList = [];
  String activeTab = "Semua";

  // id data yang sedang dalam proses "kirim ke laporan", supaya
  // tombol pada kartu itu saja yang berubah loading (bukan semua).
  final Set<String> _sedangMengekspor = {};

  // PAGINASI untuk daftar kartu di "Tinjauan Manual" -- 5 data per
  // halaman, direset ke halaman 1 setiap ganti tab / muat ulang data.
  static const int itemPerHalaman = 5;
  int halamanSaatIni = 1;

  final lokasiController = TextEditingController();
  final List<String> tabs = ["Semua", "Pending", "Valid", "Tolak", "Review"];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    lokasiController.dispose();
    super.dispose();
  }

  Future<void> ambilData() async {
    if (lokasiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Masukkan lokasi")),
      );
      return;
    }
    setState(() => loading = true);
    await http.post(
      Uri.parse("${ApiService.baseUrl}/admin/validasi.php"),
      body: {"action": "get", "lokasi": lokasiController.text},
    );
    lokasiController.clear();
    await loadData();
    setState(() => loading = false);
  }

  Future<void> loadData() async {
    final response = await http.post(
      Uri.parse("${ApiService.baseUrl}/admin/validasi.php"),
      body: {"action": "list"},
    );
    final result = json.decode(response.body);
    setState(() {
      dataList = result["data"] ?? [];
      halamanSaatIni = 1;
    });
  }

  Future<void> updateStatus(id, status) async {
    final response = await http.post(
      Uri.parse("${ApiService.baseUrl}/admin/validasi.php"),
      body: {
        "action": "update",
        "id": id.toString(),
        "status": status,
      },
    );

    await loadData();

    try {
      final result = json.decode(response.body);
      final sync = result["sync"];
      if (sync != null && mounted) {
        final synced = sync["synced"] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sync["message"]?.toString() ?? ""),
            backgroundColor: synced ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> hapusData(dynamic id) async {
    await http.post(
      Uri.parse("${ApiService.baseUrl}/admin/validasi.php"),
      body: {
        "action": "delete",
        "id": id.toString(),
      },
    );
    await loadData();
  }

  void _konfirmasiHapus(dynamic d) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
            SizedBox(width: 8),
            Text("Hapus Data",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          "Data dari \"${d["nama_lokasi"] ?? "-"}\" akan dihapus secara permanen. Lanjutkan?",
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await hapusData(d["id"]);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("\"${d["nama_lokasi"]}\" berhasil dihapus")),
                );
              }
            },
            icon: const Icon(Icons.delete_outline, size: 14),
            label: const Text("Hapus"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// Dulu "_eksporData" -- munculkan dialog teks lalu snackbar palsu
  /// saat "Unduh" ditekan. Sekarang dialog itu dihapus total: tombol
  /// langsung mengirim baris data ini ke tabel laporan_items lewat
  /// laporan.php (kategori "validasi"). Ringkasan diisi
  /// "<nama_lokasi> · #<id>" supaya beberapa baris dengan lokasi sama
  /// tapi waktu berbeda tetap dianggap entri terpisah di halaman
  /// Laporan (per BARIS DATA, bukan per lokasi seperti Kualitas
  /// Udara/Prediksi).
  Future<void> _kirimKeLaporan(dynamic d) async {
    final id = d["id"].toString();
    if (_sedangMengekspor.contains(id)) return;

    setState(() => _sedangMengekspor.add(id));

    final namaLokasi = (d["nama_lokasi"] ?? "-").toString();
    final ringkasan = "$namaLokasi · #$id";

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
        body: {
          "action": "kirim",
          "kategori": "validasi",
          "ringkasan": ringkasan,
        },
      );

      if (!mounted) return;

      if (response.body.isEmpty) {
        throw "Server tidak mengirim response";
      }

      final result = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result["status"] == "success"
                ? "Data \"$namaLokasi\" dikirim ke laporan"
                : (result["message"] ?? "Gagal mengirim ke laporan"),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _sedangMengekspor.remove(id));
      }
    }
  }

  void _tandaiPrioritas(dynamic d) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.flag_outlined, color: AppColors.warning, size: 20),
            SizedBox(width: 8),
            Text("Tandai Prioritas",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          "Data dari \"${d["nama_lokasi"] ?? "-"}\" akan ditandai sebagai prioritas untuk ditinjau ulang oleh tim.",
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("\"${d["nama_lokasi"]}\" ditandai sebagai prioritas")),
              );
            },
            icon: const Icon(Icons.flag_outlined, size: 14),
            label: const Text("Tandai"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    return double.tryParse(v.toString()) ?? 0;
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Valid":  return AppColors.success;
      case "Tolak":  return AppColors.danger;
      case "Review": return AppColors.accent;
      default:       return AppColors.warning;
    }
  }

  Color _statusSoft(String status) {
    switch (status) {
      case "Valid":  return AppColors.successSoft;
      case "Tolak":  return AppColors.dangerSoft;
      case "Review": return AppColors.accentSoft;
      default:       return AppColors.warningSoft;
    }
  }

  Color _levelColor(String metric, double value) {
    final thresh = {
      "pm25": [15, 55],
      "pm10": [50, 150],
      "co":   [2, 9],
      "no2":  [40, 100],
      "so2":  [20, 75],
      "o3":   [54, 70],
    };
    final t = thresh[metric] ?? [50, 100];
    if (value <= t[0]) return AppColors.success;
    if (value <= t[1]) return AppColors.warning;
    return AppColors.danger;
  }

  Map<String, dynamic> _aqiInfo(int aqi) {
    switch (aqi) {
      case 1: return {"label": "Baik", "color": AppColors.success, "soft": AppColors.successSoft};
      case 2: return {"label": "Sedang", "color": AppColors.warning, "soft": AppColors.warningSoft};
      case 3: return {"label": "Tidak Sehat (Sensitif)", "color": AppColors.warning, "soft": AppColors.warningSoft};
      case 4: return {"label": "Tidak Sehat", "color": AppColors.danger, "soft": AppColors.dangerSoft};
      case 5: return {"label": "Berbahaya", "color": AppColors.danger, "soft": AppColors.dangerSoft};
      default: return {"label": "Tidak diketahui", "color": AppColors.muted, "soft": AppColors.bg};
    }
  }

  Widget _aqiBadge(int aqi) {
    final info  = _aqiInfo(aqi);
    final color = info["color"] as Color;
    final soft  = info["soft"]  as Color;
    final label = info["label"] as String;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.air, size: 12, color: color),
          const SizedBox(width: 5),
          Text("AQI $aqi · $label",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  bool _kelengkapanOk(dynamic d) {
    for (final k in ["pm25", "pm10", "co", "no2", "so2", "o3", "nama_lokasi"]) {
      if (d[k] == null || d[k].toString().isEmpty) return false;
    }
    return true;
  }

  bool _tipeDataOk(dynamic d) {
    for (final k in ["pm25", "pm10", "co", "no2", "so2", "o3"]) {
      if (double.tryParse(d[k].toString()) == null) return false;
    }
    return true;
  }

  bool _rentangOk(dynamic d) {
    final pm25 = _num(d["pm25"]);
    final pm10 = _num(d["pm10"]);
    return pm25 >= 0 && pm25 <= 500 && pm10 >= 0 && pm10 <= 600;
  }

  bool _timestampOk(dynamic d) {
    final t = d["created_at"]?.toString();
    if (t == null || t.isEmpty) return false;
    final dupes = dataList.where((e) => e["created_at"] == t).length;
    return dupes <= 1;
  }

  bool _isValidAll(dynamic d) =>
      _kelengkapanOk(d) && _tipeDataOk(d) && _rentangOk(d) && _timestampOk(d);

  bool _isBermasalah(dynamic d) =>
      !_isValidAll(d) || (d["status"]?.toString() == "Tolak");

  String _issueText(dynamic d) {
    if (!_kelengkapanOk(d)) return "Terdapat kolom data yang kosong";
    if (!_tipeDataOk(d))    return "Format nilai polutan tidak sesuai";
    if (!_rentangOk(d))     return "Nilai polutan di luar rentang wajar";
    if (!_timestampOk(d))   return "Timestamp duplikat dengan data lain";
    if (d["status"]?.toString() == "Tolak") return "Ditolak oleh admin";
    return "";
  }

  int _countWhere(bool Function(dynamic) f) => dataList.where(f).length;

  // ambil potongan list untuk halaman tertentu (paginasi Tinjauan Manual)
  List _itemHalaman(List sumber, int halaman) {
    final awal = (halaman - 1) * itemPerHalaman;
    if (awal >= sumber.length) return [];
    final akhir = (awal + itemPerHalaman > sumber.length) ? sumber.length : awal + itemPerHalaman;
    return sumber.sublist(awal, akhir);
  }

  @override
  Widget build(BuildContext context) {
    final total          = dataList.length;
    final kelengkapan    = _countWhere(_kelengkapanOk);
    final tipeData       = _countWhere(_tipeDataOk);
    final rentang        = _countWhere(_rentangOk);
    final timestampValid = _countWhere(_timestampOk);
    final lolos          = _countWhere(_isValidAll);
    final bermasalah     = total - lolos;

    final avgAqi = dataList.isNotEmpty
        ? (dataList
        .map((d) => int.tryParse(d["aqi"]?.toString() ?? "0") ?? 0)
        .reduce((a, b) => a + b) /
        dataList.length)
        .toStringAsFixed(1)
        : "0";

    final pendingCount = dataList.where((d) => (d["status"] ?? "Pending") == "Pending").length;
    final validCount = dataList.where((d) => d["status"] == "Valid").length;
    final reviewGroupCount =
        dataList.where((d) => d["status"] == "Tolak" || d["status"] == "Review").length;

    final List filtered = activeTab == "Semua"
        ? dataList
        : dataList.where((d) => (d["status"] ?? "Pending") == activeTab).toList();

    final totalHalamanFiltered = filtered.isEmpty ? 1 : (filtered.length / itemPerHalaman).ceil();
    final halamanAman = halamanSaatIni.clamp(1, totalHalamanFiltered);
    final filteredHalamanIni = _itemHalaman(filtered, halamanAman);

    final List problemList = dataList.where((d) => _isBermasalah(d)).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.ink,
        title: const Text(
          "Validasi Data Kualitas Udara",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel("01", "Sumber Data"),
            _sumberDataCard(),
            const SizedBox(height: 26),

            _sectionLabel("02", "Ringkasan Validasi Otomatis"),
            _statGrid([
              _StatItem("Total data", "$total", Icons.layers_outlined, AppColors.accent, AppColors.accentSoft),
              _StatItem("Lolos validasi", "$lolos", Icons.check_circle_outline, AppColors.success, AppColors.successSoft),
              _StatItem("Data bermasalah", "$bermasalah", Icons.cancel_outlined, AppColors.danger, AppColors.dangerSoft),
              _StatItem("Rata-rata AQI", avgAqi, Icons.air_outlined, AppColors.warning, AppColors.warningSoft),
            ]),
            const SizedBox(height: 26),

            _sectionLabel("03", "Pemeriksaan Validasi"),
            _checksCard([
              _CheckItem(Icons.fact_check_outlined, "Kelengkapan Data",
                  "Memeriksa data kosong pada setiap kolom", kelengkapan, total),
              _CheckItem(Icons.layers_outlined, "Tipe Data",
                  "Memeriksa format dan tipe data sesuai standar", tipeData, total),
              _CheckItem(Icons.speed_outlined, "Rentang Nilai",
                  "Memeriksa nilai berada dalam rentang wajar", rentang, total),
              _CheckItem(Icons.schedule_outlined, "Timestamp",
                  "Memeriksa format tanggal dan duplikasi data", timestampValid, total),
            ]),
            const SizedBox(height: 26),

            _sectionLabel("04", "Tinjauan Manual"),
            Row(
              children: [
                Expanded(child: _miniStat("Pending", "$pendingCount", AppColors.warning, AppColors.warningSoft, Icons.schedule_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _miniStat("Valid", "$validCount", AppColors.success, AppColors.successSoft, Icons.check_circle_outline)),
                const SizedBox(width: 10),
                Expanded(child: _miniStat("Ditolak / Review", "$reviewGroupCount", AppColors.danger, AppColors.dangerSoft, Icons.cancel_outlined)),
              ],
            ),
            const SizedBox(height: 16),
            _tabsRow(),
            const SizedBox(height: 14),

            if (filtered.isEmpty)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.cardShadow(),
                ),
                child: _emptyState(loading
                    ? "Memuat data..."
                    : (dataList.isEmpty
                    ? "Belum ada data. Ambil data dari API untuk memulai."
                    : "Tidak ada data pada kategori ini.")),
              )
            else
              ...filteredHalamanIni.map((d) => _stationCard(d)).toList(),

            if (filtered.isNotEmpty && totalHalamanFiltered > 1) ...[
              const SizedBox(height: 4),
              _paginasiRow(halamanAman, totalHalamanFiltered),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionLabel("05", "Data Bermasalah"),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(20)),
                  child: Text("${problemList.length} Data",
                      style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _problemTable(problemList),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String step, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 26, height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(step,
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 15.5)),
        ],
      ),
    );
  }

  Widget _sumberDataCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.cloud_outlined, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("OpenWeather API", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.ink)),
                    SizedBox(height: 2),
                    Text("Data akan diambil berdasarkan lokasi", style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: lokasiController,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: "Contoh: Depok",
              hintStyle: const TextStyle(color: AppColors.mutedSoft),
              prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.mutedSoft),
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: loading ? null : ambilData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_download_outlined, size: 18),
              label: Text(loading ? "Mengambil data..." : "Ambil Data dari API",
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statGrid(List<_StatItem> items) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: items.map((i) => _statCard(i)).toList(),
    );
  }

  Widget _statCard(_StatItem i) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34, height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: i.soft, borderRadius: BorderRadius.circular(10)),
            child: Icon(i.icon, color: i.color, size: 17),
          ),
          const SizedBox(height: 10),
          Text(i.value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1)),
          const SizedBox(height: 3),
          Text(i.label, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color, Color soft, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _checksCard(List<_CheckItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: List.generate(items.length, (idx) {
          final c      = items[idx];
          final ok     = c.total > 0 && c.pass == c.total;
          final isLast = idx == items.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : AppColors.border))),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(9)),
                  child: Icon(c.icon, size: 16, color: AppColors.accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                      const SizedBox(height: 1),
                      Text(c.desc, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ok ? AppColors.successSoft : AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ok ? Icons.check_circle : Icons.error_outline, size: 13, color: ok ? AppColors.success : AppColors.warning),
                      const SizedBox(width: 4),
                      Text("${c.pass}/${c.total}",
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ok ? AppColors.success : AppColors.warning)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _tabsRow() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t      = tabs[i];
          final count  = t == "Semua" ? dataList.length : dataList.where((d) => (d["status"] ?? "Pending") == t).length;
          final active = activeTab == t;
          return GestureDetector(
            onTap: () => setState(() { activeTab = t; halamanSaatIni = 1; }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: active ? AppColors.ink : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? AppColors.ink : AppColors.border),
                boxShadow: active
                    ? [BoxShadow(color: AppColors.ink.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Text("$t · $count", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.muted)),
            ),
          );
        },
      ),
    );
  }

  Widget _readingChip(String label, String unit, dynamic rawValue, String metricKey) {
    final value = _num(rawValue);
    final color = _levelColor(metricKey, value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500)),
            ],
          ),
          Text.rich(
            TextSpan(
              text: "${rawValue ?? '-'} ",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
              children: [
                TextSpan(text: unit, style: const TextStyle(fontSize: 10, color: AppColors.mutedSoft, fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stationCard(dynamic d) {
    final status   = (d["status"] ?? "Pending").toString();
    final hasIssue = !_isValidAll(d);
    final aqi      = int.tryParse(d["aqi"]?.toString() ?? "0") ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hasIssue ? AppColors.danger.withOpacity(0.25) : AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d["nama_lokasi"]?.toString() ?? "-", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.ink)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 11, color: AppColors.mutedSoft),
                        const SizedBox(width: 4),
                        Text(d["created_at"]?.toString() ?? "-", style: const TextStyle(fontSize: 11, color: AppColors.mutedSoft)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (aqi > 0) _aqiBadge(aqi) else const SizedBox.shrink(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusSoft(status),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor(status).withOpacity(0.18)),
                ),
                child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status))),
              ),
            ],
          ),
          if (hasIssue) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_issueText(d), style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w500))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 4.2,
              children: [
                _readingChip("PM2.5", "µg/m³", d["pm25"], "pm25"),
                _readingChip("PM10", "µg/m³", d["pm10"], "pm10"),
                _readingChip("CO", "ppm", d["co"], "co"),
                _readingChip("NO2", "ppb", d["no2"], "no2"),
                _readingChip("SO2", "ppb", d["so2"], "so2"),
                _readingChip("O3", "ppb", d["o3"], "o3"),
              ],
            ),
          ),
          if (status != "Tolak") ...[
            const SizedBox(height: 12),
            _actionButtons(d, status),
          ],
        ],
      ),
    );
  }

  // Pending  → Valid | Review | Tolak
  // Valid    → (sudah valid, hanya "Kirim ke Laporan" -- dulu "Ekspor")
  // Tolak    → masuk ke Data Bermasalah, hanya tombol Pulihkan
  // Review   → Valid | Tolak | Tandai Prioritas
  Widget _actionButtons(dynamic d, String status) {
    final id = d["id"].toString();
    final sedangMengekspor = _sedangMengekspor.contains(id);

    Widget btnValid = Expanded(
      child: ElevatedButton.icon(
        onPressed: () => updateStatus(d["id"], "Valid"),
        icon: const Icon(Icons.check_circle_outline, size: 14),
        label: const Text("Valid", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );

    Widget btnReview = Expanded(
      child: OutlinedButton.icon(
        onPressed: () => updateStatus(d["id"], "Review"),
        icon: const Icon(Icons.replay_outlined, size: 14, color: AppColors.ink),
        label: const Text("Review", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.bg,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );

    Widget btnTolak = Expanded(
      child: ElevatedButton.icon(
        onPressed: () => updateStatus(d["id"], "Tolak"),
        icon: const Icon(Icons.cancel_outlined, size: 14, color: AppColors.danger),
        label: const Text("Tolak", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.danger)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dangerSoft,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );

    // Dulu "Ekspor" (munculkan dialog teks) -- sekarang langsung
    // kirim data ini ke laporan (kategori "validasi"), tanpa dialog.
    Widget btnKirimLaporan = Expanded(
      child: ElevatedButton.icon(
        onPressed: sedangMengekspor ? null : () => _kirimKeLaporan(d),
        icon: sedangMengekspor
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
            : const Icon(Icons.ios_share, size: 14, color: AppColors.accent),
        label: Text(sedangMengekspor ? "Mengirim..." : "Kirim ke Laporan",
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.accent)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentSoft,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );

    Widget btnPrioritas = Expanded(
      child: ElevatedButton.icon(
        onPressed: () => _tandaiPrioritas(d),
        icon: const Icon(Icons.flag_outlined, size: 14, color: AppColors.warning),
        label: const Text("Prioritas", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.warning)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warningSoft,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );

    const gap = SizedBox(width: 8);

    switch (status) {
      case "Valid":
        return Row(children: [btnKirimLaporan]);
      case "Tolak":
        return const SizedBox.shrink();
      case "Review":
        return Row(children: [btnValid, gap, btnTolak, gap, btnPrioritas]);
      default:
        return Row(children: [btnValid, gap, btnReview, gap, btnTolak]);
    }
  }

  Widget _paginasiRow(int halamanAman, int totalHalaman) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _tombolHalaman(
          icon: Icons.chevron_left_rounded,
          aktif: halamanAman > 1,
          onTap: () => setState(() => halamanSaatIni = halamanAman - 1),
        ),
        const SizedBox(width: 14),
        Text(
          "Halaman $halamanAman dari $totalHalaman",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
        ),
        const SizedBox(width: 14),
        _tombolHalaman(
          icon: Icons.chevron_right_rounded,
          aktif: halamanAman < totalHalaman,
          onTap: () => setState(() => halamanSaatIni = halamanAman + 1),
        ),
      ],
    );
  }

  Widget _tombolHalaman({required IconData icon, required bool aktif, required VoidCallback onTap}) {
    return InkWell(
      onTap: aktif ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34, height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: aktif ? AppColors.accentSoft : AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: aktif ? AppColors.accent.withOpacity(.3) : AppColors.border),
        ),
        child: Icon(icon, size: 20, color: aktif ? AppColors.accent : AppColors.mutedSoft),
      ),
    );
  }

  Widget _emptyState(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
            child: const Icon(Icons.search, color: AppColors.accent, size: 26),
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12.5), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _problemTable(List problemList) {
    if (problemList.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow(),
        ),
        child: _emptyState(
          dataList.isEmpty
              ? "Belum ada data untuk divalidasi. Ambil data dari API untuk melihat hasil validasi."
              : "Tidak ditemukan data bermasalah pada pengambilan terakhir.",
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(problemList.length, (i) {
          final d      = problemList[i];
          final isLast = i == problemList.length - 1;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: i.isOdd ? AppColors.bg.withOpacity(0.4) : Colors.transparent,
              border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : AppColors.border)),
            ),
            child: Row(
              children: [
                SizedBox(width: 22, child: Text("${i + 1}", style: const TextStyle(fontSize: 11, color: AppColors.mutedSoft, fontWeight: FontWeight.w600))),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Text(d["nama_lokasi"]?.toString() ?? "-", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink), overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Text(_issueText(d), style: const TextStyle(fontSize: 11, color: AppColors.danger), overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  onPressed: () => updateStatus(d["id"], "Pending"),
                  icon: const Icon(Icons.restore_outlined, size: 16, color: AppColors.accent),
                  tooltip: "Pulihkan ke Pending",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
                const SizedBox(width: 2),
                IconButton(
                  onPressed: () => _konfirmasiHapus(d),
                  icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                  tooltip: "Hapus data",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}