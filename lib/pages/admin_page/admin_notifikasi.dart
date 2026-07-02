import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/users.dart';

/// =========================================================
/// WARNA TEMA (dark, samakan dengan halaman lain)
/// =========================================================
class _Tema {
  static const bg = Color(0xFF17171B);
  static const card = Color(0xFF222226);
  static const cardBorder = Color(0xFF2E2E33);
  static const teksAbu = Color(0xFF9A9AA2);
  static const teksPutih = Color(0xFFF2F2F3);
  static const biru = Color(0xFF3B82F6);
  static const kuning = Color(0xFFFACC15); // WARNING
  static const merah = Color(0xFFF87171); // DANGER
}

/// =========================================================
/// MODEL -- mapping persis dari kolom tabel `notifikasi`
/// (id, tipe, severity, judul, pesan, nama_lokasi, sumber,
///  data_tambahan, dibaca, created_at)
/// =========================================================
class NotifikasiItem {
  final int id;
  final String tipe; // contoh: "AQI_TINGGI"
  final String severity; // INFO / WARNING / DANGER
  final String judul;
  final String pesan;
  final String? namaLokasi;
  final String? sumber;
  final Map<String, dynamic>? dataTambahan;
  final bool dibaca;
  final DateTime waktu;

  NotifikasiItem({
    required this.id,
    required this.tipe,
    required this.severity,
    required this.judul,
    required this.pesan,
    required this.namaLokasi,
    required this.sumber,
    required this.dataTambahan,
    required this.dibaca,
    required this.waktu,
  });

  factory NotifikasiItem.fromJson(Map<String, dynamic> j) {
    return NotifikasiItem(
      id: int.tryParse((j["id"] ?? "0").toString()) ?? 0,
      tipe: (j["tipe"] ?? "INFO").toString(),
      severity: (j["severity"] ?? "INFO").toString().toUpperCase(),
      judul: (j["judul"] ?? "").toString(),
      pesan: (j["pesan"] ?? "").toString(),
      namaLokasi: j["nama_lokasi"]?.toString(),
      sumber: j["sumber"]?.toString(),
      dataTambahan: j["data_tambahan"] is Map ? Map<String, dynamic>.from(j["data_tambahan"]) : null,
      dibaca: j["dibaca"].toString() == "1",
      waktu: DateTime.tryParse((j["created_at"] ?? "").toString()) ?? DateTime.now(),
    );
  }

  /// Hanya WARNING & DANGER dianggap "Peringatan" -- sesuai dengan
  /// hitungan total_peringatan di backend (severity IN WARNING,DANGER)
  bool get isPeringatan => severity == "WARNING" || severity == "DANGER";

  String get labelSeverity {
    switch (severity) {
      case "DANGER":
        return "Bahaya";
      case "WARNING":
        return "Peringatan";
      default:
        return "Info";
    }
  }

  Color get warnaSeverity {
    switch (severity) {
      case "DANGER":
        return _Tema.merah;
      case "WARNING":
        return _Tema.kuning;
      default:
        return _Tema.teksAbu;
    }
  }

  /// Ikon dipilih dari `tipe`, karena PHP tidak mengirim field ikon
  /// secara eksplisit. Sesuaikan daftar ini kalau ada tipe baru.
  IconData get ikon {
    switch (tipe) {
      case "AQI_TINGGI":
        return Icons.show_chart;
      case "SINKRONISASI_GAGAL":
        return Icons.sync_problem;
      case "LOKASI_BELUM_TERDAFTAR":
        return Icons.location_off_outlined;
      case "LOKASI_BARU":
        return Icons.add_circle_outline;
      case "STATUS_DIVALIDASI":
        return Icons.check_circle_outline;
      case "DATA_DIHUBUNGKAN":
        return Icons.link;
      case "DATA_DIPERBARUI":
        return Icons.refresh;
      default:
        return Icons.notifications_none;
    }
  }

  String get waktuRelatif {
    final now = DateTime.now();
    final selisih = now.difference(waktu);

    if (selisih.inMinutes < 1) return "Baru saja";
    if (selisih.inMinutes < 60) return "${selisih.inMinutes} menit lalu";
    if (selisih.inHours < 24) return "${selisih.inHours} jam lalu";
    if (selisih.inDays < 7) return "${selisih.inDays} hari lalu";
    return "${waktu.day}/${waktu.month}/${waktu.year}";
  }
}

/// =========================================================
/// SERVICE -- panggilan ke notifikasi.php (action: list,
/// tandai_dibaca, tandai_semua_dibaca, hapus, hapus_yang_dibaca)
/// =========================================================
class NotifikasiService {
  static const String _endpoint = "${ApiService.baseUrl}/admin/notifikasi.php";

  static Future<Map<String, dynamic>> getList({String severity = "", String lokasi = "semua"}) async {
    final body = <String, String>{"action": "list"};
    if (severity.isNotEmpty) body["severity"] = severity;
    if (lokasi.isNotEmpty) body["lokasi"] = lokasi;

    final res = await http.post(Uri.parse(_endpoint), body: body).timeout(const Duration(seconds: 15));

    final decoded = _decode(res);
    if (decoded["status"] != true) {
      throw Exception(decoded["message"] ?? "Gagal mengambil notifikasi");
    }

    final List data = decoded["data"] ?? [];
    return {
      "items": data.map((e) => NotifikasiItem.fromJson(e)).toList(),
      "belum_dibaca": int.tryParse((decoded["belum_dibaca"] ?? "0").toString()) ?? 0,
      "total_peringatan": int.tryParse((decoded["total_peringatan"] ?? "0").toString()) ?? 0,
    };
  }

  static Future<void> markRead(int id) async {
    final res = await http
        .post(Uri.parse(_endpoint), body: {"action": "tandai_dibaca", "id": "$id"})
        .timeout(const Duration(seconds: 15));
    final body = _decode(res);
    if (body["status"] != true) {
      throw Exception(body["message"] ?? "Gagal menandai dibaca");
    }
  }

  static Future<void> markAllRead() async {
    final res = await http
        .post(Uri.parse(_endpoint), body: {"action": "tandai_semua_dibaca"})
        .timeout(const Duration(seconds: 15));
    final body = _decode(res);
    if (body["status"] != true) {
      throw Exception(body["message"] ?? "Gagal menandai semua dibaca");
    }
  }

  static Future<void> delete(int id) async {
    final res = await http
        .post(Uri.parse(_endpoint), body: {"action": "hapus", "id": "$id"})
        .timeout(const Duration(seconds: 15));
    final body = _decode(res);
    if (body["status"] != true) {
      throw Exception(body["message"] ?? "Gagal menghapus notifikasi");
    }
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception("Respon server tidak valid (HTTP ${res.statusCode})");
    }
  }
}

/// =========================================================
/// HALAMAN NOTIFIKASI
/// =========================================================
class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  // Filter tab di UI: "semua" / "peringatan" / "info"
  // -- "peringatan" diterjemahkan ke severity WARNING+DANGER di sisi Dart,
  //    karena backend hanya bisa filter 1 nilai severity per request.
  String _filterTab = "semua";
  String _filterLokasi = "semua";

  List<NotifikasiItem> _semuaItem = [];
  int _belumDibaca = 0;
  int _totalPeringatan = 0;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muatData();
  }

  Future<void> _muatData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Selalu ambil "semua severity" dari server, filter tab dilakukan
      // di Dart -- supaya kartu ringkasan tetap dihitung dari keseluruhan data.
      final hasil = await NotifikasiService.getList(lokasi: _filterLokasi);
      if (!mounted) return;
      setState(() {
        _semuaItem = hasil["items"];
        _belumDibaca = hasil["belum_dibaca"];
        _totalPeringatan = hasil["total_peringatan"];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<NotifikasiItem> get _itemTampil {
    if (_filterTab == "semua") return _semuaItem;
    if (_filterTab == "peringatan") return _semuaItem.where((e) => e.isPeringatan).toList();
    return _semuaItem.where((e) => !e.isPeringatan).toList(); // "info"
  }

  int get _jumlahHariIni {
    final now = DateTime.now();
    return _semuaItem
        .where((e) => e.waktu.year == now.year && e.waktu.month == now.month && e.waktu.day == now.day)
        .length;
  }

  List<String> get _daftarLokasi {
    final set = _semuaItem.map((e) => e.namaLokasi).whereType<String>().where((s) => s.isNotEmpty).toSet().toList();
    set.sort();
    return set;
  }

  Future<void> _tandaiSemuaDibaca() async {
    try {
      await NotifikasiService.markAllRead();
      _muatData();
    } catch (e) {
      _tampilkanError(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _tapItem(NotifikasiItem item) async {
    if (!item.dibaca) {
      try {
        await NotifikasiService.markRead(item.id);
        _muatData();
      } catch (e) {
        _tampilkanError(e.toString().replaceFirst("Exception: ", ""));
      }
    }
  }

  void _tampilkanError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _pilihLokasiFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _Tema.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final daftar = ["semua", ..._daftarLokasi];
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: daftar.map((nama) {
            final label = nama == "semua" ? "Semua lokasi" : nama;
            return ListTile(
              leading: const Icon(Icons.location_on_outlined, color: _Tema.teksAbu),
              title: Text(label, style: const TextStyle(color: _Tema.teksPutih)),
              trailing: nama == _filterLokasi ? const Icon(Icons.check, color: _Tema.biru) : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _filterLokasi = nama);
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.maybePop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _Tema.card,
                    border: Border.all(color: _Tema.cardBorder),
                  ),
                  child: const Icon(Icons.arrow_back, size: 18, color: _Tema.teksPutih),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text("Notifikasi",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _Tema.teksPutih)),
              ),
              OutlinedButton.icon(
                onPressed: _tandaiSemuaDibaca,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _Tema.cardBorder),
                  foregroundColor: _Tema.teksPutih,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text("Tandai semua dibaca", style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text("Peringatan kenaikan AQI dan aktivitas sistem pemantauan",
              style: TextStyle(fontSize: 12.5, color: _Tema.teksAbu)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 100, left: 24, right: 24),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ===== KARTU RINGKASAN =====
        Row(
          children: [
            Expanded(child: _ringkasanCard("Belum dibaca", "$_belumDibaca", _Tema.teksPutih)),
            const SizedBox(width: 8),
            Expanded(child: _ringkasanCard("Peringatan AQI", "$_totalPeringatan", _Tema.kuning)),
            const SizedBox(width: 8),
            Expanded(child: _ringkasanCard("Hari ini", "$_jumlahHariIni", _Tema.teksPutih)),
          ],
        ),
        const SizedBox(height: 14),

        // ===== TAB FILTER =====
        Row(
          children: [
            _tabFilter("Semua", "semua"),
            const SizedBox(width: 8),
            _tabFilter("Peringatan", "peringatan"),
            const SizedBox(width: 8),
            _tabFilter("Info", "info"),
          ],
        ),
        const SizedBox(height: 8),

        // ===== DROPDOWN LOKASI =====
        InkWell(
          onTap: _pilihLokasiFilter,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _Tema.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _Tema.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _filterLokasi == "semua" ? "Semua lokasi" : _filterLokasi,
                  style: const TextStyle(fontSize: 12.5, color: _Tema.teksPutih),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 16, color: _Tema.teksAbu),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ===== LIST NOTIFIKASI =====
        if (_itemTampil.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text("Tidak ada notifikasi", style: TextStyle(color: _Tema.teksAbu, fontSize: 13)),
            ),
          )
        else
          ..._itemTampil.map((item) => _notifikasiCard(item)),
      ],
    );
  }

  Widget _ringkasanCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _Tema.teksAbu)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }

  Widget _tabFilter(String label, String value) {
    final aktif = _filterTab == value;
    return InkWell(
      onTap: () => setState(() => _filterTab = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: aktif ? _Tema.biru : _Tema.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: aktif ? _Tema.biru : _Tema.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: aktif ? Colors.white : _Tema.teksAbu,
          ),
        ),
      ),
    );
  }

  Widget _notifikasiCard(NotifikasiItem item) {
    final opacity = item.dibaca ? 0.55 : 1.0;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: () => _tapItem(item),
        onLongPress: () => _konfirmasiHapus(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _Tema.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _Tema.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.warnaSeverity.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(item.ikon, size: 17, color: item.warnaSeverity),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.judul,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600, color: _Tema.teksPutih),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(item.waktuRelatif, style: const TextStyle(fontSize: 11, color: _Tema.teksAbu)),
                        if (!item.dibaca) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(color: _Tema.biru, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.pesan,
                      style: const TextStyle(fontSize: 12, color: _Tema.teksAbu, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.warnaSeverity.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.labelSeverity,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: item.warnaSeverity),
                          ),
                        ),
                        if (item.namaLokasi != null && item.namaLokasi!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on_outlined, size: 12, color: _Tema.teksAbu),
                          const SizedBox(width: 2),
                          Text(item.namaLokasi!, style: const TextStyle(fontSize: 11, color: _Tema.teksAbu)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _konfirmasiHapus(NotifikasiItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _Tema.card,
        title: const Text("Hapus notifikasi?", style: TextStyle(color: _Tema.teksPutih)),
        content: Text(item.judul, style: const TextStyle(color: _Tema.teksAbu)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await NotifikasiService.delete(item.id);
                _muatData();
              } catch (e) {
                _tampilkanError(e.toString().replaceFirst("Exception: ", ""));
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}