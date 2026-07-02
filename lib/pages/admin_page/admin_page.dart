import 'package:flutter/material.dart';
import '../dashboard_guest.dart';
import 'admin_kualitas_udara_page.dart';
import 'admin_map_kualitas_udara.dart';
import 'admin_kelola_users.dart';
import 'admin_validasi_data.dart';
import 'admin_notifikasi.dart';
import 'admin_prediksi_udara.dart';
import 'admin_laporan_page.dart';

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
  bool isExpanded = false;

  Widget menuCard(String title, IconData icon) {
    return InkWell(
      onTap: () {
        // NAVIGASI MENU
        switch (title) {
          case "User":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const KelolaUserPage(),
              ),
            );
            break;
          case "Kualitas Udara":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const KualitasUdaraDashboardPage(
                  // ganti sesuai default yang kamu mau
                ),
              ),
            );
            break;
          case "Prediksi":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PrediksiKualitasUdaraPage(),
              ),
            );
            break;
          case "Laporan":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LaporanPage(),
              ),
            );
            break;
          case "Notifikasi":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotifikasiPage(
                  // ganti sesuai default yang kamu mau
                ),
              ),
            );
            break;
          case "Lokasi":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MapAirQualityPage(),
              ),
            );
            break;
          case "Validasi":
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminValidasiDataPage(),
              ),
            );
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("$title belum tersedia")),
            );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              blurRadius: 5,
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget smallCard(String title, String total, IconData icon) {
    return Expanded(
      child: Container(
        height: 75,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              blurRadius: 5,
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 24),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TAMBAHAN: dipanggil saat user pilih "Logout" dari popup akun.
  // Konfirmasi dulu sebelum benar-benar logout.
  // =========================================================
  void _konfirmasiLogout() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Apakah kamu yakin ingin keluar dari akun ini?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx); // tutup dialog
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DashboardGuest(),
                  ),
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

  // =========================================================
  // TAMBAHAN: ikon akun di pojok kanan atas (sebelah judul
  // "PureAir Admin"). Diklik -> muncul popup menu dengan opsi
  // "Pengaturan" dan "Logout".
  // =========================================================
  Widget _buildAccountMenu() {
    return PopupMenuButton<String>(
      tooltip: "Akun",
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      icon: const CircleAvatar(
        radius: 18,
        backgroundColor: Colors.blue,
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
      onSelected: (value) {
        switch (value) {
          case "pengaturan":
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Halaman Pengaturan belum tersedia")),
            );
            break;
          case "logout":
            _konfirmasiLogout();
            break;
        }
      },
      itemBuilder: (context) => [
        // Header kecil isi nama & email di dalam popup
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: "pengaturan",
          child: Row(
            children: [
              Icon(Icons.settings, size: 18, color: Colors.black87),
              SizedBox(width: 10),
              Text("Pengaturan"),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: "logout",
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: Colors.red),
              SizedBox(width: 10),
              Text("Logout", style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.username;

    final List<Map<String, dynamic>> menuItems = [
      {"title": "User", "icon": Icons.people},
      {"title": "Kualitas Udara", "icon": Icons.air},
      {"title": "Prediksi", "icon": Icons.auto_graph},
      {"title": "Laporan", "icon": Icons.article},
      {"title": "Notifikasi", "icon": Icons.notifications},
      {"title": "Validasi", "icon": Icons.verified},
      {"title": "Lokasi", "icon": Icons.location_on},
      {"title": "Dashboard", "icon": Icons.dashboard},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // HEADER
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() => isExpanded = true);
                          },
                          icon: const Icon(Icons.menu, size: 28),
                        ),
                        const Spacer(),
                        const Text(
                          "PureAir Admin",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // TAMBAHAN: ikon akun di kanan, sejajar judul.
                        // Diklik -> popup "Pengaturan" & "Logout".
                        _buildAccountMenu(),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Welcome $username 👋",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // GRID MENU (CLICKABLE)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: menuItems.length,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.1,
                      ),
                      itemBuilder: (context, index) {
                        return menuCard(
                          menuItems[index]["title"],
                          menuItems[index]["icon"],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // STATS
                    Row(
                      children: [
                        smallCard("Users", "240", Icons.people),
                        const SizedBox(width: 10),
                        smallCard("Laporan", "45", Icons.article),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        smallCard("Prediksi", "120", Icons.auto_graph),
                        const SizedBox(width: 10),
                        smallCard("Lokasi", "18", Icons.location_on),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}