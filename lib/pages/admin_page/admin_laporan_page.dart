import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/users.dart';

// Warna untuk label kategori AQI skala OpenWeather (1-5),
// dipakai di ringkasan harian maupun detail per jam.
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

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  // daftar kategori untuk GRID STATUS (atas) -- hanya kategori
  // yang "1 aktif per kategori". "kualitas_udara", "prediksi", dan
  // "validasi" TIDAK di sini karena bisa punya banyak entri aktif
  // sekaligus (per lokasi / per baris data), jadi ditampilkan
  // langsung di "Data terkumpul" di bawah.
  final List<Map<String, dynamic>> kategoriList = const [
    {"key": "user", "label": "User", "icon": Icons.people},
    {"key": "notifikasi", "label": "Notifikasi", "icon": Icons.notifications},
    {"key": "lokasi", "label": "Lokasi", "icon": Icons.location_on},
  ];

  // info tampilan (label, icon) untuk SEMUA kategori termasuk yang
  // multi-entry (kualitas_udara, prediksi, validasi), dipakai di
  // daftar "Data terkumpul"
  final Map<String, Map<String, dynamic>> semuaKategoriInfo = const {
    "user": {"label": "User", "icon": Icons.people},
    "kualitas_udara": {"label": "Kualitas Udara", "icon": Icons.air},
    "prediksi": {"label": "Prediksi", "icon": Icons.show_chart},
    "notifikasi": {"label": "Notifikasi", "icon": Icons.notifications},
    "lokasi": {"label": "Lokasi", "icon": Icons.location_on},
    "validasi": {"label": "Validasi", "icon": Icons.verified_outlined},
  };

  List items = [];
  bool isLoading = true;
  bool isDownloading = false;
  bool isLoadingDetail = false;

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
    } else if (kategori == "kualitas_udara") {
      // ringkasan menyimpan nama lokasi yang dikirim dari tombol Export
      final namaLokasi = (item["ringkasan"] ?? "").toString();
      tampilkanDetailKualitasUdara(namaLokasi);
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
          content: Text("Detail untuk kategori '$kategori' belum tersedia"),
        ),
      );
    }
  }

  // ambil data dari detail_laporan_user.php lalu tampilkan
  // sebagai dialog di atas halaman Laporan
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

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Detail laporan user"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Periode: ${data["periode"] ?? "7 hari terakhir"}",
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    "User baru daftar (${userBaru.length})",
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  if (userBaru.isEmpty)
                    const Text(
                      "Tidak ada user baru minggu ini",
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    )
                  else
                    ...userBaru.map((u) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u["username"] ?? "-",
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            u["email"] ?? "-",
                            style: const TextStyle(fontSize: 11, color: Colors.black45),
                          ),
                        ],
                      ),
                    )),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),

                  Text(
                    "Jadi admin (${jadiAdmin.length})",
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  if (jadiAdmin.isEmpty)
                    const Text(
                      "Tidak ada user yang jadi admin minggu ini",
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    )
                  else
                    ...jadiAdmin.map((u) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u["username"] ?? "-",
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            u["email"] ?? "-",
                            style: const TextStyle(fontSize: 11, color: Colors.black45),
                          ),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
          ],
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

      const bulan = [
        "Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
        "Jul", "Agu", "Sep", "Okt", "Nov", "Des",
      ];

      String formatTanggal(String? raw) {
        if (raw == null || raw.isEmpty) return "-";
        try {
          final dt = DateTime.parse(raw);
          return "${dt.day} ${bulan[dt.month - 1]}";
        } catch (_) {
          return raw;
        }
      }



      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Kualitas udara · $namaLokasi"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Periode: ${data["periode"] ?? "7 hari terakhir"}",
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),

                  if (harian.isEmpty)
                    Text(
                      data["message"] ?? "Belum ada data untuk lokasi ini",
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    )
                  else
                    ...harian.map((h) {
                      final kategori = (h["kategori"] ?? "-").toString();
                      final tanggalMentah = (h["tanggal"] ?? "").toString();
                      return InkWell(
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
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: Text(
                                  formatTanggal(h["tanggal"]),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: warnaKategoriAqi(kategori),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  kategori,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: warnaKategoriAqi(kategori),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                "AQI ${h["aqi"]}",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 16, color: Colors.black38),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
          ],
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
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
              Icon(
                ok ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: ok ? const Color(0xff10B981) : const Color(0xffEF4444),
              ),
              const SizedBox(width: 6),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Validasi · ${d["nama_lokasi"] ?? "-"}"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: warnaStatus(statusValidasi).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusValidasi,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: warnaStatus(statusValidasi),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("AQI ${d["aqi"]}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Diambil: ${d["created_at"] ?? "-"}",
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    lolos ? "Lolos validasi otomatis" : "Gagal validasi otomatis",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: lolos ? const Color(0xff10B981) : const Color(0xffEF4444),
                    ),
                  ),
                  const SizedBox(height: 6),
                  baris("Kelengkapan data", d["kelengkapan_ok"] == true ? "Lengkap" : "Ada yang kosong", ok: d["kelengkapan_ok"] == true),
                  baris("Tipe data", d["tipe_data_ok"] == true ? "Sesuai" : "Tidak sesuai", ok: d["tipe_data_ok"] == true),
                  baris("Rentang nilai", d["rentang_ok"] == true ? "Wajar" : "Di luar rentang", ok: d["rentang_ok"] == true),

                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text("Nilai polutan", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
          ],
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

  // cari item berdasarkan kategori (untuk ambil waktu kirim & ringkasan)
  Map? cariItem(String kategoriKey) {
    return items.firstWhere(
          (item) => item["kategori"] == kategoriKey,
      orElse: () => null,
    );
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
      const SnackBar(
        content: Text("Fitur download PDF belum tersedia"),
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
        title: const Text("Batalkan dari laporan"),
        content: Text(
          "Hapus '${item["kategori"]}' dari daftar data terkumpul?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Endpoint batal_laporan.php belum dibuat"),
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

    return Scaffold(
      backgroundColor: const Color(0xffF8F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xffF8F9FC),
        elevation: 0,
        title: const Text(
          "Laporan",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: fetchLaporan,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              "${kategoriList.length} kategori tersedia · $totalTerkirim sudah dikirim",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 14),

            // GRID STATUS KATEGORI
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: kategoriList.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
              ),
              itemBuilder: (context, index) {
                final kategori = kategoriList[index];
                final terkirim = sudahDikirim(kategori["key"]);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: terkirim
                        ? const Color(0xffE8F8EF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: terkirim
                          ? const Color(0xff10B981).withOpacity(.4)
                          : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        kategori["icon"],
                        size: 18,
                        color: terkirim
                            ? const Color(0xff10B981)
                            : Colors.black45,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              kategori["label"],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              terkirim ? "Terkirim" : "Belum dikirim",
                              style: TextStyle(
                                fontSize: 10,
                                color: terkirim
                                    ? const Color(0xff10B981)
                                    : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (terkirim)
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Color(0xff10B981),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            const Text(
              "Data terkumpul",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    "Belum ada data yang dikirim ke laporan",
                    style: TextStyle(color: Colors.black45),
                  ),
                ),
              )
            else
              ...items.map((item) {
                final kategoriInfo = semuaKategoriInfo[item["kategori"]] ?? {
                  "label": item["kategori"],
                  "icon": Icons.insert_drive_file,
                };

                return InkWell(
                  onTap: isLoadingDetail ? null : () => lihatDetail(item),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          kategoriInfo["icon"],
                          size: 20,
                          color: const Color(0xff3B82F6),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  "kualitas_udara",
                                  "prediksi",
                                  "validasi"
                                ].contains(item["kategori"]) &&
                                    item["ringkasan"] != null
                                    ? "${kategoriInfo["label"]} · ${item["ringkasan"]}"
                                    : kategoriInfo["label"],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "Dikirim ${formatWaktu(item["dikirim_at"])}"
                                    "${![
                                  "kualitas_udara",
                                  "prediksi",
                                  "validasi"
                                ].contains(item["kategori"]) && item["ringkasan"] != null ? " · ${item["ringkasan"]}" : ""}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isLoadingDetail)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: Colors.black38,
                          onPressed: () => batalkanItem(item),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: items.isEmpty || isDownloading
                    ? null
                    : downloadPdf,
                icon: isDownloading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  isDownloading ? "Menyiapkan..." : "Download PDF",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
// HALAMAN DETAIL PER JAM (kualitas udara, 1 lokasi, 1 tanggal)
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
        Uri.parse("${ApiService.baseUrl}/laporan.php"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xffF8F9FC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.namaLokasi,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _muatData,
                child: const Text("Coba lagi"),
              ),
            ],
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            _formatTanggalLengkap(widget.tanggal),
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),

          if (jamJam.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  "Tidak ada data per jam untuk tanggal ini",
                  style: TextStyle(color: Colors.black45),
                ),
              ),
            )
          else
            ...jamJam.map((j) {
              final kategori = (j["kategori"] ?? "-").toString();
              final warna = warnaKategoriAqi(kategori);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatJam(j["waktu"]),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: warna,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          kategori,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: warna,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "AQI ${j["aqi"]}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      children: [
                        _polutanKecil("PM2.5", j["pm25"]),
                        _polutanKecil("PM10", j["pm10"]),
                        _polutanKecil("CO", j["co"]),
                        _polutanKecil("NO2", j["no2"]),
                        _polutanKecil("SO2", j["so2"]),
                        _polutanKecil("O3", j["o3"]),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _polutanKecil(String label, dynamic nilai) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xffF8F9FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45)),
          Text(
            (nilai is num) ? nilai.toStringAsFixed(1) : "-",
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}