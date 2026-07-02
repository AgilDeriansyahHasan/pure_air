import 'package:flutter/material.dart';
import '../dashboard_guest.dart';
import '../../services/session.dart';           // ← Session (SharedPreferences)
import 'user_profile_page.dart';               // ← EditProfilePage
import 'user_prediksi_page.dart';
import 'user_history_page.dart';
import 'user_peta_page.dart';
import 'user_polutan_page.dart';

class UserDashboardPage extends StatefulWidget {
  final String username;
  final String email;

  const UserDashboardPage({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  bool isExpanded = false;

  // ============================================================
  // NAVIGASI MENU SIDEBAR
  // ============================================================
  void _onMenuTap(String menu) {
    setState(() => isExpanded = false);

    switch (menu) {
      case "Dashboard":
        break;
      case "Prediksi":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PrediksiPage()));
        break;
      case "Historis":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HistoriUserPage()));
        break;
      case "Map":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MapAirQualityUserPage()));
        break;
      case "Polutan":
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InfoPolutanPage()));
        break;
    }
  }

  // ============================================================
  // WIDGET MENU ITEM SIDEBAR
  // ============================================================
  Widget menuItem(IconData icon, String title) {
    return InkWell(
      onTap: () => _onMenuTap(title),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            const SizedBox(width: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT DIALOG -- sekarang pakai Session.hapus() dulu
  // ============================================================
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Apakah kamu yakin ingin keluar?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);           // tutup dialog
              await Session.hapus();        // ← hapus session
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
      ),
    );
  }

  // ============================================================
  // PROFILE AVATAR + DROPDOWN MENU
  // ============================================================
  Widget _profileMenuButton() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        switch (value) {
          case 'edit_profile':
          // Ambil userId dari session, baru buka EditProfilePage
            Session.getUserId().then((userId) {
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfilePage(userId: userId),
                ),
              );
            });
            break;

          case 'settings':
          // TODO: Navigator.push ke halaman Pengaturan
            break;

          case 'logout':
            _showLogoutDialog();
            break;
        }
      },
      itemBuilder: (context) => [
        // Header popup -- nama & email
        PopupMenuItem(
          value: 'header',
          enabled: false,
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.username,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black)),
                    Text(widget.email,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),

        const PopupMenuItem(
          value: 'edit_profile',
          child: Row(children: [
            Icon(Icons.person_outline, size: 20, color: Colors.black87),
            SizedBox(width: 12),
            Text("Edit Profile"),
          ]),
        ),

        const PopupMenuItem(
          value: 'settings',
          child: Row(children: [
            Icon(Icons.settings_outlined, size: 20, color: Colors.black87),
            SizedBox(width: 12),
            Text("Pengaturan"),
          ]),
        ),

        const PopupMenuDivider(),

        const PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout, size: 20, color: Colors.red),
            SizedBox(width: 12),
            Text("Logout", style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.08))
          ],
        ),
        child: const CircleAvatar(
          radius: 22,
          backgroundColor: Colors.blue,
          child: Icon(Icons.person, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  // ============================================================
  // NOTIFIKASI ICON
  // ============================================================
  Widget _notificationButton() {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.08))
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: () {
              // TODO: Navigator.push ke halaman Notifikasi
            },
            icon: const Icon(Icons.notifications_none, size: 26),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final username = widget.username;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // ==================== KONTEN UTAMA ====================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // HEADER
                  Row(
                    children: [
                      // Tombol menu (kiri)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                                blurRadius: 8,
                                color: Colors.black.withOpacity(0.08))
                          ],
                        ),
                        child: IconButton(
                          onPressed: () =>
                              setState(() => isExpanded = true),
                          icon: const Icon(Icons.menu, size: 32),
                        ),
                      ),

                      const Spacer(),

                      // Logo (tengah)
                      const Row(
                        children: [
                          Icon(Icons.air, color: Colors.blue, size: 40),
                          SizedBox(width: 8),
                          Text("PureAir",
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ],
                      ),

                      const Spacer(),

                      // Notifikasi + Profil (kanan)
                      _notificationButton(),
                      _profileMenuButton(),
                    ],
                  ),

                  const SizedBox(height: 70),

                  // GREETING
                  const Text("Welcome Back 👋",
                      style: TextStyle(
                          fontSize: 30, fontStyle: FontStyle.italic)),

                  const SizedBox(height: 8),

                  Text(username,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w500)),

                  const SizedBox(height: 60),

                  // SEARCH
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            blurRadius: 8,
                            color: Colors.black.withOpacity(0.05))
                      ],
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search),
                        hintText: "Cari Lokasi",
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // AQI CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.lightBlueAccent]),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Column(
                      children: [
                        Text("Air Quality Index",
                            style:
                            TextStyle(color: Colors.white, fontSize: 18)),
                        SizedBox(height: 10),
                        Text("75",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 50,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        Text("Good",
                            style:
                            TextStyle(color: Colors.white, fontSize: 20)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // MAP PLACEHOLDER
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Center(
                        child: Icon(Icons.map, size: 100, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ==================== OVERLAY GELAP ====================
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isExpanded ? 1 : 0,
            child: isExpanded
                ? GestureDetector(
              onTap: () => setState(() => isExpanded = false),
              child: Container(color: Colors.black.withOpacity(0.4)),
            )
                : const SizedBox(),
          ),

          // ==================== SIDEBAR ====================
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: isExpanded ? 0 : -300,
            top: 0,
            bottom: 0,
            child: Container(
              width: 270,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 25, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tombol tutup sidebar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: IconButton(
                          onPressed: () =>
                              setState(() => isExpanded = false),
                          icon: const Icon(Icons.close, size: 30),
                        ),
                      ),

                      const SizedBox(height: 45),

                      // Logo di sidebar
                      const Row(
                        children: [
                          Icon(Icons.air, color: Colors.blue, size: 42),
                          SizedBox(width: 10),
                          Text("PureAir",
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ],
                      ),

                      const SizedBox(height: 60),

                      // Menu item
                      menuItem(Icons.dashboard_outlined, "Dashboard"),
                      menuItem(Icons.auto_graph, "Prediksi"),
                      menuItem(Icons.history, "Historis"),
                      menuItem(Icons.map_outlined, "Map"),
                      menuItem(Icons.cloud_outlined, "Polutan"),

                      const Spacer(),
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