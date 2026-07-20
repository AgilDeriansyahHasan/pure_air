import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/users.dart';

/// =========================================================
/// WARNA TEMA (light, konsisten dengan halaman lain)
/// =========================================================
class _Tema {
  static const bg         = Color(0xFFF6F7FB);
  static const card       = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE9EAF0);
  static const teksAbu    = Color(0xFF6B7280);
  static const teksPutih  = Color(0xFF111827);
  static const aksen      = Color(0xFFFB7155); // warna utama / aktif
  static const kuning     = Color(0xFFEAB308); // WARNING
  static const merah      = Color(0xFFEF4444); // DANGER
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
        return _Tema.aksen;
    }
  }

  /// Ikon dipilih dari `tipe`, karena PHP tidak mengirim field ikon
  /// secara eksplisit. Sesuaikan daftar ini kalau ada tipe baru.
  IconData get ikon {
    switch (tipe) {
      case "AQI_TINGGI":
        return Icons.show_chart_rounded;
      case "SINKRONISASI_GAGAL":
        return Icons.sync_problem_rounded;
      case "LOKASI_BELUM_TERDAFTAR":
        return Icons.location_off_outlined;
      case "LOKASI_BARU":
        return Icons.add_circle_outline_rounded;
      case "STATUS_DIVALIDASI":
        return Icons.check_circle_outline_rounded;
      case "DATA_DIHUBUNGKAN":
        return Icons.link_rounded;
      case "DATA_DIPERBARUI":
        return Icons.refresh_rounded;
      default:
        return Icons.notifications_none_rounded;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1F2937),
        content: Text(message),
      ),
    );
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
          padding: const EdgeInsets.only(top: 10, bottom: 12),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: _Tema.cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text("Filter Lokasi",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _Tema.teksPutih)),
            ),
            const SizedBox(height: 6),
            ...daftar.map((nama) {
              final label = nama == "semua" ? "Semua lokasi" : nama;
              final aktif = nama == _filterLokasi;
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: (aktif ? _Tema.aksen : _Tema.teksAbu).withOpacity(.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.location_on_rounded, size: 16, color: aktif ? _Tema.aksen : _Tema.teksAbu),
                ),
                title: Text(label,
                    style: TextStyle(
                      color: _Tema.teksPutih,
                      fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                    )),
                trailing: aktif ? const Icon(Icons.check_circle_rounded, color: _Tema.aksen) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _filterLokasi = nama);
                  _muatData();
                },
              );
            }),
          ],
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                        color: Colors.black.withOpacity(.05),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 18, color: _Tema.teksPutih),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text("Notifikasi",
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _Tema.teksPutih)),
              ),
              if (_belumDibaca > 0)
                InkWell(
                  onTap: _tandaiSemuaDibaca,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _Tema.aksen.withOpacity(.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _Tema.aksen.withOpacity(.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.done_all_rounded, size: 15, color: _Tema.aksen),
                      const SizedBox(width: 5),
                      const Text("Tandai dibaca",
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _Tema.aksen)),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
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
          padding: const EdgeInsets.only(top: 110, left: 24, right: 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _Tema.aksen.withOpacity(.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded, size: 32, color: _Tema.aksen),
              ),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _Tema.teksAbu, fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _muatData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Tema.aksen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Coba lagi"),
              ),
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
            Expanded(child: _ringkasanCard("Belum dibaca", "$_belumDibaca", _Tema.aksen, Icons.mark_email_unread_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _ringkasanCard("Peringatan AQI", "$_totalPeringatan", _Tema.kuning, Icons.warning_amber_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _ringkasanCard("Hari ini", "$_jumlahHariIni", const Color(0xFF3B82F6), Icons.today_rounded)),
          ],
        ),
        const SizedBox(height: 16),

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
        const SizedBox(height: 10),

        // ===== DROPDOWN LOKASI =====
        InkWell(
          onTap: _pilihLokasiFilter,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _Tema.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _Tema.cardBorder),
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  color: Colors.black.withOpacity(.03),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: _Tema.aksen),
                const SizedBox(width: 6),
                Text(
                  _filterLokasi == "semua" ? "Semua lokasi" : _filterLokasi,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: _Tema.teksPutih),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _Tema.teksAbu),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ===== LIST NOTIFIKASI =====
        if (_itemTampil.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 50),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _Tema.aksen.withOpacity(.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_off_rounded, size: 28, color: _Tema.aksen),
              ),
              const SizedBox(height: 14),
              const Text("Tidak ada notifikasi", style: TextStyle(color: _Tema.teksAbu, fontSize: 13)),
            ]),
          )
        else
          ..._itemTampil.map((item) => _notifikasiCard(item)),
      ],
    );
  }

  Widget _ringkasanCard(String label, String value, Color accent, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Tema.cardBorder),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: accent.withOpacity(.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withOpacity(.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: accent),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10.5, color: _Tema.teksAbu, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _tabFilter(String label, String value) {
    final aktif = _filterTab == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filterTab = value),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: aktif ? _Tema.aksen : _Tema.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: aktif ? _Tema.aksen : _Tema.cardBorder),
            boxShadow: aktif
                ? [
              BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 3),
                color: _Tema.aksen.withOpacity(.3),
              ),
            ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
              color: aktif ? Colors.white : _Tema.teksAbu,
            ),
          ),
        ),
      ),
    );
  }

  Widget _notifikasiCard(NotifikasiItem item) {
    final opacity = item.dibaca ? 0.6 : 1.0;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: () => _tapItem(item),
        onLongPress: () => _konfirmasiHapus(item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _Tema.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: item.dibaca ? _Tema.cardBorder : item.warnaSeverity.withOpacity(.3)),
            boxShadow: [
              BoxShadow(
                blurRadius: 12,
                offset: const Offset(0, 4),
                color: Colors.black.withOpacity(.03),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.warnaSeverity.withOpacity(0.12),
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
                                fontSize: 13.5, fontWeight: FontWeight.w700, color: _Tema.teksPutih),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(item.waktuRelatif, style: const TextStyle(fontSize: 11, color: _Tema.teksAbu)),
                        if (!item.dibaca) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(color: _Tema.aksen, shape: BoxShape.circle),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.warnaSeverity.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.labelSeverity,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: item.warnaSeverity),
                          ),
                        ),
                        if (item.namaLokasi != null && item.namaLokasi!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on_rounded, size: 12, color: _Tema.teksAbu),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _Tema.merah.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: _Tema.merah, size: 20),
            ),
            const SizedBox(width: 12),
            const Text("Hapus notifikasi?",
                style: TextStyle(color: _Tema.teksPutih, fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Text(item.judul, style: const TextStyle(color: _Tema.teksAbu, fontSize: 13.5)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: _Tema.teksAbu),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Tema.merah,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await NotifikasiService.delete(item.id);
                _muatData();
              } catch (e) {
                _tampilkanError(e.toString().replaceFirst("Exception: ", ""));
              }
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }
}