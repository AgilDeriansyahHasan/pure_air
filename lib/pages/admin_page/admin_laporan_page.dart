import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/users.dart';

// =========================================================
// WARNA TEMA (light) -- konsisten dengan halaman lain
// =========================================================
class _Tema {
  static const bg         = Color(0xFFF8F9FC);
  static const card       = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFEDEEF3);
  static const teksAbu    = Color(0xFF6B7280);
  static const teksUtama  = Color(0xFF111827);
  static const aksen      = Color(0xFF3B82F6); // biru, dipertahankan dari desain asli
  static const aksenGelap = Color(0xFF2563EB);
  static const hijau      = Color(0xFF10B981);

  static List<BoxShadow> cardShadow({double opacity = 0.04}) => [
    BoxShadow(
      blurRadius: 16,
      offset: const Offset(0, 6),
      color: Colors.black.withOpacity(opacity),
    ),
  ];
}

// Warna untuk label kategori AQI skala OpenWeather (1-5),
// dipakai di ringkasan harian maupun detail per jam (kualitas udara histori),
// dan juga dipakai untuk kategori AQI per lokasi (skala sama).
Color warnaKategoriAqi(String kategori) {
  switch (kategori) {
    case "Baik":
      return const Color(0xff10B981);
    case "Cukup baik":
      return const Color(0xff3B82F6);
    case "Sedang":
      return const Color(0xffF59E0B);
    case "Buruk":
      return const Color(0xffEF4444);
    case "Sangat buruk":
      return const Color(0xff7C2D12);
    default:
      return Colors.black45;
  }
}

// Warna untuk label kategori AQI skala US-EPA (0-500), dipakai khusus
// untuk data prediksi (monitoring_prediksi) -- BEDA skala dari histori.
Color warnaKategoriAqiEpa(String kategori) {
  switch (kategori) {
    case "Baik":
      return const Color(0xff10B981);
    case "Sedang":
      return const Color(0xffF59E0B);
    case "Tidak sehat (SG)":
      return const Color(0xffF97316);
    case "Tidak sehat":
      return const Color(0xffEF4444);
    case "Sangat tidak sehat":
      return const Color(0xff8B5CF6);
    case "Berbahaya":
      return const Color(0xff7C2D12);
    default:
      return Colors.black45;
  }
}

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  // daftar kategori untuk GRID STATUS (atas).
  // "Notifikasi" TIDAK ditampilkan di sini sesuai permintaan --
  // grid ini sekarang berisi 5 kategori utama: User, Lokasi,
  // Kualitas Udara, Prediksi, dan Validasi.
  //
  // "multiEntry" = true berarti kategori ini bisa punya banyak
  // entri aktif sekaligus (per lokasi / per baris data), jadi di
  // kartu status akan ditampilkan jumlah entrinya, bukan cuma
  // "Terkirim" / "Belum dikirim".
  final List<Map<String, dynamic>> kategoriList = const [
    {"key": "user", "label": "User", "icon": Icons.people_rounded, "multiEntry": false},
    {"key": "lokasi", "label": "Lokasi", "icon": Icons.location_on_rounded, "multiEntry": false},
    {"key": "kualitas_udara", "label": "Kualitas Udara", "icon": Icons.air_rounded, "multiEntry": true},
    {"key": "prediksi", "label": "Prediksi", "icon": Icons.show_chart_rounded, "multiEntry": true},
    {"key": "validasi", "label": "Validasi", "icon": Icons.verified_outlined, "multiEntry": true},
  ];

  // info tampilan (label, icon, warna) untuk SEMUA kategori termasuk
  // "notifikasi" -- tetap disimpan di sini (bukan di grid status) supaya
  // kalau backend masih mengirim item berkategori notifikasi, item itu
  // tetap bisa tampil rapi di daftar "Data terkumpul".
  final Map<String, Map<String, dynamic>> semuaKategoriInfo = const {
    "user": {"label": "User", "icon": Icons.people_rounded, "warna": Color(0xff3B82F6)},
    "kualitas_udara": {"label": "Kualitas Udara", "icon": Icons.air_rounded, "warna": Color(0xff0EA5E9)},
    "prediksi": {"label": "Prediksi", "icon": Icons.show_chart_rounded, "warna": Color(0xff8B5CF6)},
    "notifikasi": {"label": "Notifikasi", "icon": Icons.notifications_rounded, "warna": Color(0xffF59E0B)},
    "lokasi": {"label": "Lokasi", "icon": Icons.location_on_rounded, "warna": Color(0xff10B981)},
    "validasi": {"label": "Validasi", "icon": Icons.verified_outlined, "warna": Color(0xffEF4444)},
  };

  List items = [];
  bool isLoading = true;
  bool isDownloading = false;
  bool isLoadingDetail = false;

  // notifikasi ringkas "X data diekspor hari ini" di atas halaman.
  // Ditutup manual lewat tombol X; muncul lagi kalau data dimuat ulang.
  bool notifDitutup = false;

  // PAGINASI untuk daftar "Data terkumpul"
  static const int itemPerHalaman = 5;
  int halamanSaatIni = 1;

  @override
  void initState() {
    super.initState();
    fetchLaporan();
  }

  // GET DATA LAPORAN
  Future<void> fetchLaporan() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
        body: {"action": "get"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          items = data['data'] ?? [];
          isLoading = false;
          halamanSaatIni = 1;
          notifDitutup = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // dipanggil saat sebuah item di "Data terkumpul" diklik.
  void lihatDetail(Map item) {
    final kategori = item["kategori"];

    if (kategori == "user") {
      tampilkanDetailUser();
    } else if (kategori == "lokasi") {
      tampilkanDetailLokasi();
    } else if (kategori == "kualitas_udara") {
      // ringkasan menyimpan nama lokasi yang dikirim dari tombol Export
      final namaLokasi = (item["ringkasan"] ?? "").toString();
      tampilkanDetailKualitasUdara(namaLokasi);
    } else if (kategori == "prediksi") {
      // ringkasan menyimpan nama lokasi, sama seperti kualitas_udara
      final namaLokasi = (item["ringkasan"] ?? "").toString();
      tampilkanDetailPrediksi(namaLokasi);
    } else if (kategori == "validasi") {
      // ringkasan berformat "<nama_lokasi> · #<id>", ambil id-nya
      // saja untuk dikirim ke detail_validasi
      final ringkasan = (item["ringkasan"] ?? "").toString();
      final idMatch = RegExp(r'#(\d+)$').firstMatch(ringkasan);
      final id = idMatch?.group(1) ?? "";
      tampilkanDetailValidasi(id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text("Detail untuk kategori '$kategori' belum tersedia"),
        ),
      );
    }
  }

  // Bentuk dialog yang seragam untuk semua "Detail ..." di halaman ini,
  // supaya tidak perlu mengulang shape/padding/tombol tutup tiap kali.
  Future<void> _tampilkanDialog({
    required String judul,
    String? subjudul,
    IconData icon = Icons.description_rounded,
    Color warnaIkon = _Tema.aksen,
    required Widget konten,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: warnaIkon.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: warnaIkon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(judul,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: _Tema.teksUtama)),
                  if (subjudul != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subjudul,
                          style: const TextStyle(fontSize: 11.5, color: _Tema.teksAbu)),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(width: double.maxFinite, child: konten),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _Tema.aksen),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  // tombol bulat kecil untuk navigasi paginasi (Sebelumnya / Berikutnya)
  Widget _tombolHalaman({
    required IconData icon,
    required bool aktif,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: aktif ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: aktif ? _Tema.aksen.withOpacity(.1) : _Tema.card,
          shape: BoxShape.circle,
          border: Border.all(color: aktif ? _Tema.aksen.withOpacity(.25) : _Tema.cardBorder),
        ),
        child: Icon(icon, size: 20, color: aktif ? _Tema.aksen : _Tema.teksAbu.withOpacity(.4)),
      ),
    );
  }

  Widget _judulSeksi(String teks) {
    return Text(
      teks,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _Tema.teksUtama),
    );
  }

  Widget _kosongTeks(String teks) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(teks, style: const TextStyle(fontSize: 12, color: _Tema.teksAbu)),
    );
  }

  // ambil data dari laporan.php (action=detail_user)
  // lalu tampilkan sebagai dialog di atas halaman Laporan
  Future<void> tampilkanDetailUser() async {
    setState(() {
      isLoadingDetail = true;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
        body: {"action": "detail_user"},
      );

      if (!mounted) return;
      setState(() {
        isLoadingDetail = false;
      });

      if (response.statusCode != 200) {
        throw "Gagal mengambil detail (status ${response.statusCode})";
      }

      final data = jsonDecode(response.body);
      final List userBaru = data["user_baru"] ?? [];
      final List jadiAdmin = data["jadi_admin"] ?? [];

      _tampilkanDialog(
        judul: "Detail laporan user",
        subjudul: data["periode"] ?? "7 hari terakhir",
        icon: Icons.people_rounded,
        warnaIkon: const Color(0xff3B82F6),
        konten: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _judulSeksi("User baru daftar (${userBaru.length})"),
              const SizedBox(height: 8),
              if (userBaru.isEmpty)
                _kosongTeks("Tidak ada user baru minggu ini")
              else
                ...userBaru.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(top: 5, right: 8),
                        decoration: const BoxDecoration(color: _Tema.hijau, shape: BoxShape.circle),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u["username"] ?? "-",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _Tema.teksUtama),
                            ),
                            Text(
                              u["email"] ?? "-",
                              style: const TextStyle(fontSize: 11, color: _Tema.teksAbu),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),

              const SizedBox(height: 8),
              const Divider(height: 1, color: _Tema.cardBorder),
              const SizedBox(height: 14),

              _judulSeksi("Jadi admin (${jadiAdmin.length})"),
              const SizedBox(height: 8),
              if (jadiAdmin.isEmpty)
                _kosongTeks("Tidak ada user yang jadi admin minggu ini")
              else
                ...jadiAdmin.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(top: 5, right: 8),
                        decoration: BoxDecoration(color: _Tema.aksen, shape: BoxShape.circle),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u["username"] ?? "-",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _Tema.teksUtama),
                            ),
                            Text(
                              u["email"] ?? "-",
                              style: const TextStyle(fontSize: 11, color: _Tema.teksAbu),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingDetail = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ambil data dari laporan.php (action=detail_lokasi)
  // lalu tampilkan sebagai dialog: daftar semua lokasi beserta status
  // aktif/nonaktif dan kategori kualitas udara terakhirnya.
  Future<void> tampilkanDetailLokasi() async {
    setState(() {
      isLoadingDetail = true;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
        body: {"action": "detail_lokasi"},
      );

      if (!mounted) return;
      setState(() {
        isLoadingDetail = false;
      });

      if (response.statusCode != 200) {
        throw "Gagal mengambil detail (status ${response.statusCode})";
      }

      final data = jsonDecode(response.body);

      if (data["status"] != "success") {
        throw data["message"] ?? "Gagal mengambil detail";
      }

      final List daftarLokasi = data["lokasi"] ?? [];

      _tampilkanDialog(
        judul: "Detail laporan lokasi",
        subjudul:
        "Aktif: ${data["aktif"] ?? 0} · Nonaktif: ${data["nonaktif"] ?? 0} · Tidak sehat: ${data["tidak_sehat"] ?? 0}",
        icon: Icons.location_on_rounded,
        warnaIkon: const Color(0xff10B981),
        konten: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (daftarLokasi.isEmpty)
                _kosongTeks("Belum ada data lokasi")
              else
                ...daftarLokasi.map((l) => _barisLokasi(l)),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingDetail = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // satu baris lokasi di dalam dialog detail lokasi: nama, badge
  // status aktif/nonaktif, dan kategori kualitas udara terakhir
  // (kalau ada datanya).
  Widget _barisLokasi(Map l) {
    final status = (l["status"] ?? "nonaktif").toString();
    final aktif = status == "aktif";
    final kategori = l["kategori"] as String?;
    final aqi = l["aqi"];
    final warnaKategori = kategori != null ? warnaKategoriAqi(kategori) : Colors.black26;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l["nama"] ?? "-",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _Tema.teksUtama),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: (aktif ? _Tema.hijau : Colors.grey).withOpacity(.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              aktif ? "Aktif" : "Nonaktif",
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: aktif ? _Tema.hijau : Colors.grey[600],
              ),
            ),
          ),
          if (kategori != null)
            Text(
              "$kategori · AQI $aqi",
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: warnaKategori),
            )
          else
            const Text("Belum ada data", style: TextStyle(fontSize: 11.5, color: _Tema.teksAbu)),
        ],
      ),
    );
  }

  // baris ringkasan harian (dipakai oleh dialog kualitas udara & prediksi)
  Widget _barisRingkasanHarian({
    required String tanggalLabel,
    required String kategori,
    required int aqi,
    required Color warna,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                tanggalLabel,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _Tema.teksUtama),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
            ),
            Expanded(
              child: Text(
                kategori,
                style: TextStyle(fontSize: 12, color: warna, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              "AQI $aqi",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Tema.teksUtama),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 18, color: _Tema.teksAbu),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTanggalPendek(String? raw) {
    if (raw == null || raw.isEmpty) return "-";
    try {
      final dt = DateTime.parse(raw);
      const bulan = [
        "Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
        "Jul", "Agu", "Sep", "Okt", "Nov", "Des",
      ];
      return "${dt.day} ${bulan[dt.month - 1]}";
    } catch (_) {
      return raw;
    }
  }

  // ambil data dari laporan.php (action=detail_kualitas_udara)
  // lalu tampilkan sebagai dialog di atas halaman Laporan
  Future<void> tampilkanDetailKualitasUdara(String namaLokasi) async {
    if (namaLokasi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama lokasi tidak ditemukan pada data ini")),
      );
      return;
    }

    setState(() {
      isLoadingDetail = true;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
        body: {
          "action": "detail_kualitas_udara",
          "nama_lokasi": namaLokasi,
        },
      );

      if (!mounted) return;
      setState(() {
        isLoadingDetail = false;
      });

      if (response.statusCode != 200) {
        throw "Gagal mengambil detail (status ${response.statusCode})";
      }

      final data = jsonDecode(response.body);

      if (data["status"] != "success") {
        throw data["message"] ?? "Gagal mengambil detail";
      }

      final List harian = data["harian"] ?? [];

      _tampilkanDialog(
        judul: namaLokasi,
        subjudul: "Kualitas udara · ${data["periode"] ?? "7 hari terakhir"}",
        icon: Icons.air_rounded,
        warnaIkon: const Color(0xff0EA5E9),
        konten: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (harian.isEmpty)
                _kosongTeks(data["message"] ?? "Belum ada data untuk lokasi ini")
              else
                ...harian.map((h) {
                  final kategori = (h["kategori"] ?? "-").toString();
                  final tanggalMentah = (h["tanggal"] ?? "").toString();
                  return _barisRingkasanHarian(
                    tanggalLabel: _formatTanggalPendek(h["tanggal"]),
                    kategori: kategori,
                    aqi: (h["aqi"] is int) ? h["aqi"] : int.tryParse("${h["aqi"]}") ?? 0,
                    warna: warnaKategoriAqi(kategori),
                    onTap: tanggalMentah.isEmpty
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailJamKualitasUdaraPage(
                            namaLokasi: namaLokasi,
                            tanggal: tanggalMentah,
                          ),
                        ),
                      );
                    },
                  );
                }),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingDetail = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ambil data dari laporan.php (action=detail_prediksi)
  // lalu tampilkan sebagai dialog di atas halaman Laporan
  Future<void> tampilkanDetailPrediksi(String namaLokasi) async {
    if (namaLokasi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama lokasi tidak ditemukan pada data ini")),
      );
      return;
    }

    setState(() {
      isLoadingDetail = true;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
        body: {
          "action": "detail_prediksi",
          "nama_lokasi": namaLokasi,
        },
      );

      if (!mounted) return;
      setState(() {
        isLoadingDetail = false;
      });

      if (response.statusCode != 200) {
        throw "Gagal mengambil detail (status ${response.statusCode})";
      }

      final data = jsonDecode(response.body);

      if (data["status"] != "success") {
        throw data["message"] ?? "Gagal mengambil detail";
      }

      final List harian = data["harian"] ?? [];

      _tampilkanDialog(
        judul: namaLokasi,
        subjudul: "Prediksi · ${data["periode"] ?? "7 hari ke depan"}",
        icon: Icons.show_chart_rounded,
        warnaIkon: const Color(0xff8B5CF6),
        konten: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (harian.isEmpty)
                _kosongTeks(data["message"] ??
                    "Belum ada hasil prediksi untuk lokasi ini")
              else
                ...harian.map((h) {
                  final kategori = (h["kategori"] ?? "-").toString();
                  final tanggalMentah = (h["tanggal"] ?? "").toString();
                  return _barisRingkasanHarian(
                    tanggalLabel: _formatTanggalPendek(h["tanggal"]),
                    kategori: kategori,
                    aqi: (h["aqi"] is int) ? h["aqi"] : int.tryParse("${h["aqi"]}") ?? 0,
                    warna: warnaKategoriAqiEpa(kategori),
                    onTap: tanggalMentah.isEmpty
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailJamPrediksiPage(
                            namaLokasi: namaLokasi,
                            tanggal: tanggalMentah,
                          ),
                        ),
                      );
                    },
                  );
                }),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingDetail = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ambil 1 baris data dari laporan.php (action=detail_validasi)
  // lalu tampilkan sebagai dialog: ringkasan validasi otomatis +
  // status manual (Pending/Valid/Tolak/Review) untuk baris itu.
  Future<void> tampilkanDetailValidasi(String id) async {
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ID data tidak ditemukan pada item ini")),
      );
      return;
    }

    setState(() {
      isLoadingDetail = true;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
        body: {
          "action": "detail_validasi",
          "id": id,
        },
      );

      if (!mounted) return;
      setState(() {
        isLoadingDetail = false;
      });

      if (response.statusCode != 200) {
        throw "Gagal mengambil detail (status ${response.statusCode})";
      }

      final result = jsonDecode(response.body);

      if (result["status"] != "success") {
        throw result["message"] ?? "Gagal mengambil detail";
      }

      final d = result["data"];
      final statusValidasi = (d["status_validasi"] ?? "Pending").toString();
      final lolos = d["lolos_validasi"] == true;

      Color warnaStatus(String s) {
        switch (s) {
          case "Valid":
            return const Color(0xff10B981);
          case "Tolak":
            return const Color(0xffEF4444);
          case "Review":
            return const Color(0xff3B82F6);
          default:
            return const Color(0xffF59E0B);
        }
      }

      Widget baris(String label, String value, {bool ok = true}) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12, color: _Tema.teksAbu)),
              ),
              Icon(
                ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 14,
                color: ok ? const Color(0xff10B981) : const Color(0xffEF4444),
              ),
              const SizedBox(width: 6),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Tema.teksUtama)),
            ],
          ),
        );
      }

      _tampilkanDialog(
        judul: (d["nama_lokasi"] ?? "-").toString(),
        subjudul: "Validasi data",
        icon: Icons.verified_outlined,
        warnaIkon: const Color(0xffEF4444),
        konten: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: warnaStatus(statusValidasi).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusValidasi,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: warnaStatus(statusValidasi),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text("AQI ${d["aqi"]}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Tema.teksUtama)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Diambil: ${d["created_at"] ?? "-"}",
                style: const TextStyle(fontSize: 11, color: _Tema.teksAbu),
              ),
              const SizedBox(height: 16),

              Text(
                lolos ? "Lolos validasi otomatis" : "Gagal validasi otomatis",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: lolos ? const Color(0xff10B981) : const Color(0xffEF4444),
                ),
              ),
              const SizedBox(height: 8),
              baris("Kelengkapan data", d["kelengkapan_ok"] == true ? "Lengkap" : "Ada yang kosong", ok: d["kelengkapan_ok"] == true),
              baris("Tipe data", d["tipe_data_ok"] == true ? "Sesuai" : "Tidak sesuai", ok: d["tipe_data_ok"] == true),
              baris("Rentang nilai", d["rentang_ok"] == true ? "Wajar" : "Di luar rentang", ok: d["rentang_ok"] == true),

              const SizedBox(height: 16),
              const Divider(height: 1, color: _Tema.cardBorder),
              const SizedBox(height: 12),
              const Text("Nilai polutan",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Tema.teksUtama)),
              const SizedBox(height: 6),
              baris("PM2.5", "${d["pm25"]} µg/m³"),
              baris("PM10", "${d["pm10"]} µg/m³"),
              baris("CO", "${d["co"]} ppm"),
              baris("NO2", "${d["no2"]} ppb"),
              baris("SO2", "${d["so2"]} ppb"),
              baris("O3", "${d["o3"]} ppb"),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingDetail = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // cek apakah kategori tertentu sudah ada di daftar item terkumpul
  bool sudahDikirim(String kategoriKey) {
    return items.any((item) => item["kategori"] == kategoriKey);
  }

  // hitung berapa banyak entri untuk kategori tertentu -- dipakai
  // sebagai badge jumlah pada kategori multi-entry (kualitas_udara,
  // prediksi, validasi) di grid status.
  int jumlahItem(String kategoriKey) {
    return items.where((item) => item["kategori"] == kategoriKey).length;
  }

  // cek apakah sebuah tanggal (dikirim_at) jatuh pada hari ini,
  // dipakai untuk notifikasi "X data diekspor hari ini".
  bool _adalahHariIni(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    } catch (_) {
      return false;
    }
  }

  // ambil potongan item untuk halaman tertentu (paginasi "Data terkumpul")
  List _itemHalaman(int halaman) {
    final awal = (halaman - 1) * itemPerHalaman;
    if (awal >= items.length) return [];
    final akhir = (awal + itemPerHalaman > items.length) ? items.length : awal + itemPerHalaman;
    return items.sublist(awal, akhir);
  }

  // TODO: endpoint export_laporan.php (PHP + dompdf) belum dibuat.
  // Saat sudah ada, ganti isi fungsi ini untuk membuka URL PDF-nya,
  // misalnya lewat url_launcher atau menyimpan file ke device.
  Future<void> downloadPdf() async {
    setState(() {
      isDownloading = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    setState(() {
      isDownloading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Text("Fitur download PDF belum tersedia"),
      ),
    );
  }

  // batalkan kategori dari laporan (ubah status jadi 'dibatalkan')
  // TODO: endpoint batal_laporan.php belum dibuat, tombol ini
  // sudah disiapkan di UI tapi belum terhubung ke server.
  void batalkanItem(Map item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Batalkan dari laporan",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _Tema.teksUtama)),
        content: Text(
          "Hapus '${item["kategori"]}' dari daftar data terkumpul?",
          style: const TextStyle(fontSize: 13, color: _Tema.teksAbu),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _Tema.teksAbu),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  content: const Text("Endpoint batal_laporan.php belum dibuat"),
                ),
              );
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  String formatWaktu(String? raw) {
    if (raw == null || raw.isEmpty) return "-";
    try {
      final dt = DateTime.parse(raw);
      const bulan = [
        "Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
        "Jul", "Agu", "Sep", "Okt", "Nov", "Des",
      ];
      final jam = dt.hour.toString().padLeft(2, '0');
      final menit = dt.minute.toString().padLeft(2, '0');
      return "${dt.day} ${bulan[dt.month - 1]}, $jam.$menit";
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalTerkirim = items.length;
    final jumlahHariIni = items.where((i) => _adalahHariIni(i["dikirim_at"])).length;
    final tampilkanNotif = jumlahHariIni > 0 && !notifDitutup;

    final totalHalaman = totalTerkirim == 0 ? 1 : (totalTerkirim / itemPerHalaman).ceil();
    final halamanAman = halamanSaatIni.clamp(1, totalHalaman);
    final itemHalamanIni = _itemHalaman(halamanAman);

    return Scaffold(
      backgroundColor: _Tema.bg,
      appBar: AppBar(
        backgroundColor: _Tema.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "Laporan",
          style: TextStyle(color: _Tema.teksUtama, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: _Tema.teksUtama),
        actions: [
          IconButton(
            onPressed: isLoading ? null : fetchLaporan,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Muat ulang",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _Tema.aksen))
          : RefreshIndicator(
        color: _Tema.aksen,
        onRefresh: fetchLaporan,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // ============ NOTIFIKASI "X DIEKSPOR HARI INI" ============
            // Hanya tampil kalau ada data yang diekspor hari ini, dan
            // hilang setelah ditutup lewat tombol X (sampai data
            // dimuat ulang lagi).
            if (tampilkanNotif) ...[
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _Tema.aksen.withOpacity(.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _Tema.aksen.withOpacity(.18)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _Tema.aksen.withOpacity(.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.file_upload_rounded, size: 17, color: _Tema.aksen),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12.5, color: _Tema.teksUtama, fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(
                                text: "$jumlahHariIni data ",
                                style: const TextStyle(fontWeight: FontWeight.w800, color: _Tema.aksenGelap),
                              ),
                              const TextSpan(text: "diekspor ke laporan hari ini"),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => notifDitutup = true),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 17, color: _Tema.teksAbu.withOpacity(.8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            Row(
              children: const [
                Icon(Icons.grid_view_rounded, size: 15, color: _Tema.teksAbu),
                SizedBox(width: 6),
                Text(
                  "Status kategori",
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _Tema.teksUtama),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // GRID STATUS KATEGORI -- 5 kategori: User, Lokasi,
            // Kualitas Udara, Prediksi, Validasi (Notifikasi tidak
            // ditampilkan di sini).
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: kategoriList.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.35,
              ),
              itemBuilder: (context, index) {
                final kategori = kategoriList[index];
                final key = kategori["key"] as String;
                final multiEntry = kategori["multiEntry"] == true;
                final terkirim = sudahDikirim(key);
                final jumlah = jumlahItem(key);
                const warnaAktif = _Tema.hijau;

                String subteks;
                if (!terkirim) {
                  subteks = "Belum ada data";
                } else if (multiEntry) {
                  subteks = "$jumlah entri";
                } else {
                  subteks = "Terkirim";
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: terkirim ? warnaAktif.withOpacity(.08) : _Tema.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: terkirim ? warnaAktif.withOpacity(.3) : _Tema.cardBorder,
                    ),
                    boxShadow: terkirim ? null : _Tema.cardShadow(opacity: 0.03),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (terkirim ? warnaAktif : _Tema.aksen).withOpacity(.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          kategori["icon"],
                          size: 16,
                          color: terkirim ? warnaAktif : _Tema.aksen,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              kategori["label"],
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _Tema.teksUtama),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              subteks,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: terkirim ? warnaAktif : _Tema.teksAbu,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (terkirim)
                        const Icon(Icons.check_circle_rounded, size: 16, color: warnaAktif),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Data terkumpul",
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _Tema.teksUtama),
                ),
                if (items.isNotEmpty)
                  Text(
                    "$totalTerkirim item",
                    style: const TextStyle(fontSize: 11.5, color: _Tema.teksAbu, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _Tema.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _Tema.cardBorder),
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _Tema.aksen.withOpacity(.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.inbox_rounded, size: 26, color: _Tema.aksen),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Belum ada data yang dikirim ke laporan",
                    style: TextStyle(color: _Tema.teksAbu, fontSize: 12.5),
                  ),
                ]),
              )
            else
              ...itemHalamanIni.map((item) {
                final kategoriInfo = semuaKategoriInfo[item["kategori"]] ?? {
                  "label": item["kategori"],
                  "icon": Icons.insert_drive_file_rounded,
                  "warna": _Tema.aksen,
                };
                final warnaKategori = kategoriInfo["warna"] as Color? ?? _Tema.aksen;
                final punyaRingkasan = [
                  "kualitas_udara",
                  "prediksi",
                  "validasi"
                ].contains(item["kategori"]) && item["ringkasan"] != null;

                return InkWell(
                  onTap: isLoadingDetail ? null : () => lihatDetail(item),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _Tema.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _Tema.cardBorder),
                      boxShadow: _Tema.cardShadow(opacity: 0.03),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: warnaKategori.withOpacity(.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(kategoriInfo["icon"], size: 18, color: warnaKategori),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                punyaRingkasan
                                    ? "${kategoriInfo["label"]} · ${item["ringkasan"]}"
                                    : kategoriInfo["label"],
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Tema.teksUtama),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 11, color: _Tema.teksAbu),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      "Dikirim ${formatWaktu(item["dikirim_at"])}"
                                          "${!punyaRingkasan && item["ringkasan"] != null ? " · ${item["ringkasan"]}" : ""}",
                                      style: const TextStyle(fontSize: 11, color: _Tema.teksAbu),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isLoadingDetail)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _Tema.aksen),
                            ),
                          )
                        else
                          const Icon(Icons.chevron_right_rounded, size: 18, color: _Tema.teksAbu),
                        InkWell(
                          onTap: () => batalkanItem(item),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.close_rounded, size: 17, color: _Tema.teksAbu),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            // ============ KONTROL PAGINASI "Data terkumpul" ============
            if (items.isNotEmpty && totalHalaman > 1) ...[
              const SizedBox(height: 4),
              Row(
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
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _Tema.teksAbu),
                  ),
                  const SizedBox(width: 14),
                  _tombolHalaman(
                    icon: Icons.chevron_right_rounded,
                    aktif: halamanAman < totalHalaman,
                    onTap: () => setState(() => halamanSaatIni = halamanAman + 1),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: items.isEmpty || isDownloading ? null : downloadPdf,
                icon: isDownloading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(isDownloading ? "Menyiapkan..." : "Download PDF"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Tema.aksen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _Tema.aksen.withOpacity(.35),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// HALAMAN DETAIL PER JAM -- kerangka bersama untuk kualitas udara
// (histori) dan prediksi, supaya tampilan konsisten & tidak
// duplikasi widget.
// =========================================================
class _KartuJam extends StatelessWidget {
  final String jamLabel;
  final String kategori;
  final int aqi;
  final Color warna;
  final Map<String, dynamic> polutan; // label -> nilai
  final double? confidence;

  const _KartuJam({
    required this.jamLabel,
    required this.kategori,
    required this.aqi,
    required this.warna,
    required this.polutan,
    this.confidence,
  });

  Widget _polutanKecil(String label, dynamic nilai) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: _Tema.teksAbu, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            (nilai is num) ? nilai.toStringAsFixed(1) : "-",
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _Tema.teksUtama),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.cardBorder),
        boxShadow: _Tema.cardShadow(opacity: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                jamLabel,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _Tema.teksUtama),
              ),
              const SizedBox(width: 8),
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  kategori,
                  style: TextStyle(fontSize: 12.5, color: warna, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (confidence != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _Tema.aksen.withOpacity(.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${(confidence! * 100).toStringAsFixed(0)}% yakin",
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _Tema.aksen),
                  ),
                ),
              Text(
                "AQI $aqi",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Tema.teksUtama),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: polutan.entries
                .map((e) => _polutanKecil(e.key, e.value))
                .toList(),
          ),
        ],
      ),
    );
  }
}

Widget _stateGagal({
  required String pesan,
  required VoidCallback onRetry,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _Tema.aksen.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off_rounded, size: 26, color: _Tema.aksen),
          ),
          const SizedBox(height: 12),
          Text(pesan, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _Tema.teksAbu)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onRetry,
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
  );
}

Widget _stateKosong(String pesan) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 40),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _Tema.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _Tema.cardBorder),
    ),
    child: Text(
      pesan,
      style: const TextStyle(color: _Tema.teksAbu, fontSize: 12.5),
    ),
  );
}

String _formatTanggalLengkap(String raw) {
  try {
    final dt = DateTime.parse(raw);
    const bulan = [
      "Januari", "Februari", "Maret", "April", "Mei", "Juni",
      "Juli", "Agustus", "September", "Oktober", "November", "Desember",
    ];
    return "${dt.day} ${bulan[dt.month - 1]} ${dt.year}";
  } catch (_) {
    return raw;
  }
}

String _formatJam(String? raw) {
  if (raw == null || raw.isEmpty) return "-";
  try {
    final dt = DateTime.parse(raw);
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return "$jam:$menit";
  } catch (_) {
    return raw;
  }
}

// =========================================================
// HALAMAN DETAIL PER JAM (kualitas udara histori, 1 lokasi, 1 tanggal)
// Dibuka dari dialog ringkasan harian saat sebuah tanggal diklik.
// =========================================================
class DetailJamKualitasUdaraPage extends StatefulWidget {
  final String namaLokasi;
  final String tanggal; // format Y-m-d, dikirim dari laporan.php

  const DetailJamKualitasUdaraPage({
    super.key,
    required this.namaLokasi,
    required this.tanggal,
  });

  @override
  State<DetailJamKualitasUdaraPage> createState() =>
      _DetailJamKualitasUdaraPageState();
}

class _DetailJamKualitasUdaraPageState
    extends State<DetailJamKualitasUdaraPage> {
  List jamJam = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _muatData();
  }

  Future<void> _muatData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
        body: {
          "action": "detail_kualitas_udara_jam",
          "nama_lokasi": widget.namaLokasi,
          "tanggal": widget.tanggal,
        },
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw "Gagal mengambil data (status ${response.statusCode})";
      }

      final data = jsonDecode(response.body);

      if (data["status"] != "success") {
        throw data["message"] ?? "Gagal mengambil data";
      }

      setState(() {
        jamJam = data["jam_jam"] ?? [];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Tema.bg,
      appBar: AppBar(
        backgroundColor: _Tema.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _Tema.teksUtama),
        title: Text(
          widget.namaLokasi,
          style: const TextStyle(color: _Tema.teksUtama, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _Tema.aksen))
          : error != null
          ? _stateGagal(pesan: error!, onRetry: _muatData)
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: _Tema.teksAbu),
              const SizedBox(width: 6),
              Text(
                _formatTanggalLengkap(widget.tanggal),
                style: const TextStyle(fontSize: 13, color: _Tema.teksAbu),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (jamJam.isEmpty)
            _stateKosong("Tidak ada data per jam untuk tanggal ini")
          else
            ...jamJam.map((j) {
              final kategori = (j["kategori"] ?? "-").toString();
              return _KartuJam(
                jamLabel: _formatJam(j["waktu"]),
                kategori: kategori,
                aqi: (j["aqi"] is int) ? j["aqi"] : int.tryParse("${j["aqi"]}") ?? 0,
                warna: warnaKategoriAqi(kategori),
                polutan: {
                  "PM2.5": j["pm25"],
                  "PM10": j["pm10"],
                  "CO": j["co"],
                  "NO2": j["no2"],
                  "SO2": j["so2"],
                  "O3": j["o3"],
                },
              );
            }),
        ],
      ),
    );
  }
}

// =========================================================
// HALAMAN DETAIL PER SLOT JAM PREDIKSI (1 lokasi, 1 tanggal proyeksi)
// Dibuka dari dialog ringkasan harian prediksi saat sebuah tanggal
// diklik. Skala AQI di sini US-EPA (0-500), beda dengan histori.
// =========================================================
class DetailJamPrediksiPage extends StatefulWidget {
  final String namaLokasi;
  final String tanggal; // format Y-m-d, dikirim dari laporan.php

  const DetailJamPrediksiPage({
    super.key,
    required this.namaLokasi,
    required this.tanggal,
  });

  @override
  State<DetailJamPrediksiPage> createState() => _DetailJamPrediksiPageState();
}

class _DetailJamPrediksiPageState extends State<DetailJamPrediksiPage> {
  List jamJam = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _muatData();
  }

  Future<void> _muatData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
        body: {
          "action": "detail_prediksi_jam",
          "nama_lokasi": widget.namaLokasi,
          "tanggal": widget.tanggal,
        },
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw "Gagal mengambil data (status ${response.statusCode})";
      }

      final data = jsonDecode(response.body);

      if (data["status"] != "success") {
        throw data["message"] ?? "Gagal mengambil data";
      }

      setState(() {
        jamJam = data["jam_jam"] ?? [];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Tema.bg,
      appBar: AppBar(
        backgroundColor: _Tema.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _Tema.teksUtama),
        title: Text(
          widget.namaLokasi,
          style: const TextStyle(color: _Tema.teksUtama, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _Tema.aksen))
          : error != null
          ? _stateGagal(pesan: error!, onRetry: _muatData)
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: _Tema.teksAbu),
              const SizedBox(width: 6),
              Text(
                _formatTanggalLengkap(widget.tanggal),
                style: const TextStyle(fontSize: 13, color: _Tema.teksAbu),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xff8B5CF6).withOpacity(.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Proyeksi",
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xff8B5CF6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (jamJam.isEmpty)
            _stateKosong("Tidak ada data prediksi per jam untuk tanggal ini")
          else
            ...jamJam.map((j) {
              final kategori = (j["kategori"] ?? "-").toString();
              return _KartuJam(
                jamLabel: _formatJam(j["waktu"]),
                kategori: kategori,
                aqi: (j["aqi"] is int) ? j["aqi"] : int.tryParse("${j["aqi"]}") ?? 0,
                warna: warnaKategoriAqiEpa(kategori),
                confidence: (j["confidence"] is num) ? (j["confidence"] as num).toDouble() : null,
                polutan: {
                  "PM2.5": j["pm25"],
                  "PM10": j["pm10"],
                  "CO": j["co"],
                  "NO2": j["no2"],
                  "SO2": j["so2"],
                  "O3": j["o3"],
                },
              );
            }),
        ],
      ),
    );
  }
}