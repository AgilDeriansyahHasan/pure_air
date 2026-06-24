import 'package:flutter/material.dart';
import '../dashboard_guest.dart';
import 'admin_kualitas_udara_page.dart';
import 'admin_map_kualitas_udara.dart';
import 'admin_kelola_users.dart';
import 'admin_validasi_data.dart';
import 'admin_notifikasi.dart';


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

  @override
  Widget build(BuildContext context) {
    final username = widget.username;
    final email = widget.email;

    final List<Map<String, dynamic>> menuItems = [
      {"title": "User", "icon": Icons.people},
      {"title": "Kualitas Udara", "icon": Icons.air},
      {"title": "Prediksi", "icon": Icons.auto_graph},
      {"title": "Laporan", "icon": Icons.article},
      {"title": "Notifikasi", "icon": Icons.notifications},
      {"title": "Polutan", "icon": Icons.science},
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
                        crossAxisCount: 3,
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

          // SIDEBAR
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: isExpanded ? 0 : -300,
            top: 0,
            bottom: 0,
            child: Container(
              width: 280,
              color: Colors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [

                      IconButton(
                        onPressed: () {
                          setState(() => isExpanded = false);
                        },
                        icon: const Icon(Icons.close),
                      ),

                      const Spacer(),

                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.admin_panel_settings),
                        ),
                        title: Text(username),
                        subtitle: Text(email),
                      ),

                      const SizedBox(height: 15),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DashboardGuest(),
                              ),
                                  (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text("Logout"),
                        ),
                      ),
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
}