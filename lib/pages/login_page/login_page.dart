import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/users.dart';
import '../../services/session.dart';
import '../admin_page/admin_page.dart';
import '../users_page/user_dashboard_page.dart';
import 'register_page.dart';

// =========================================================
// WARNA & KONSTANTA TEMA -- disamakan gayanya dengan tema di
// dashboard user (biru aksen, abu teks, dst) supaya halaman login
// terasa satu kesatuan dengan sisa aplikasi.
// =========================================================
class _Tema {
  static const bg          = Color(0xFFF6F7FB);
  static const card        = Color(0xFFFFFFFF);
  static const teksAbu     = Color(0xFF6B7280);
  static const teksUtama   = Color(0xFF111827);
  static const aksen       = Color(0xFF2F6FED);
  static const fieldBg     = Color(0xFFF8F9FC);
  static const fieldBorder = Color(0xFFE5E7EF);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController email    = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool isLoading = false;
  bool _sandiTersembunyi = true; // ← status tampil/sembunyi password

  Future<void> login() async {
    final emailText    = email.text.trim();
    final passwordText = password.text.trim();

    if (emailText.isEmpty || passwordText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan password harus diisi")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/auth/login.php"),
        body: {
          "email":    emailText,
          "password": passwordText,
        },
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error (${response.statusCode})")),
        );
        return;
      }

      final data = jsonDecode(response.body);

      if (data["status"] == "success") {
        // Simpan semua data session termasuk foto_url
        await Session.simpan(
          userId:   data["id"],
          username: data["username"],
          email:    data["email"],
          role:     data["role"],
        );

        // Simpan foto_url jika ada
        if (data["foto_url"] != null) {
          await Session.simpanFotoUrl(data["foto_url"]);
        }

        if (!mounted) return;

        if (data["role"] == "admin") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardPage(
                username: data["username"],
                email:    data["email"],
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => UserDashboardPage(
                username: data["username"],
                email:    data["email"],
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Login Failed")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Tema.bg,
      body: SafeArea(
        child: Column(
          children: [
            // TOMBOL KEMBALI
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.maybePop(context),
                    borderRadius: BorderRadius.circular(24),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _Tema.teksUtama),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(
                  children: [
                    // LOGO PUREAIR
                    Image.asset(
                      'assets/logo/pureair_logo_icon.png',
                      width: 90,
                      height: 90,
                    ),
                    const SizedBox(height: 6),
                    Image.asset(
                      'assets/logo/pureair_logo_text.png',
                      height: 34,
                      fit: BoxFit.fitHeight,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "SMART AIR QUALITY MONITORING",
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w600,
                        color: _Tema.teksAbu,
                      ),
                    ),
                    const SizedBox(height: 26),

                    // KARTU FORM LOGIN
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _Tema.card,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                            color: Colors.black.withOpacity(0.05),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Welcome Back\nto PureAir",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: _Tema.teksUtama,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 22),

                          // EMAIL / USERNAME
                          _kolomInput(
                            controller: email,
                            hint: "Email or Username",
                            icon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),

                          // PASSWORD
                          _kolomSandi(),
                          const SizedBox(height: 10),

                          // LUPA SANDI / BUAT AKUN
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () {},
                                child: const Text(
                                  "Lupa Kata Sandi?",
                                  style: TextStyle(color: _Tema.aksen, fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                                ),
                                child: const Text(
                                  "Buat Akun ?",
                                  style: TextStyle(color: _Tema.aksen, fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // TOMBOL LOGIN
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 150,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _Tema.aksen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                                onPressed: isLoading ? null : login,
                                child: isLoading
                                    ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                                )
                                    : const Text(
                                  "Login",
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // FITUR UNGGULAN
                    Row(
                      children: [
                        Expanded(child: _fiturKecil(
                          Icons.show_chart_rounded,
                          "Real-Time\nMonitoring",
                          "Pantau kualitas udara secara langsung dan akurat di berbagai lokasi.",
                        )),
                        Expanded(child: _fiturKecil(
                          Icons.cloud_outlined,
                          "Accurate\nPrediction",
                          "Dapatkan prediksi kualitas udara cerdas berbasis analitik data.",
                        )),
                        Expanded(child: _fiturKecil(
                          Icons.shield_outlined,
                          "Health\nProtection",
                          "Tetap terlindungi dengan peringatan dini polusi udara.",
                        )),
                      ],
                    ),
                    const SizedBox(height: 22),

                    const Text(
                      "©2026 PureAir - Real Time Air Quality Monitoring System",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9.5, color: _Tema.teksAbu),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // KOLOM INPUT TEKS GENERIK (email/username) -- rounded pill,
  // ikon di depan, tanpa border tebal biar senada sama mockup.
  // ============================================================
  Widget _kolomInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _Tema.fieldBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _Tema.fieldBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13.5, color: _Tema.teksUtama),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: _Tema.teksAbu, size: 20),
          hintText: hint,
          hintStyle: const TextStyle(color: _Tema.teksAbu, fontSize: 13.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ============================================================
  // KOLOM PASSWORD -- ikon gembok di depan, ikon mata (toggle
  // tampil/sembunyi) di belakang.
  // ============================================================
  Widget _kolomSandi() {
    return Container(
      decoration: BoxDecoration(
        color: _Tema.fieldBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _Tema.fieldBorder),
      ),
      child: TextField(
        controller: password,
        obscureText: _sandiTersembunyi,
        style: const TextStyle(fontSize: 13.5, color: _Tema.teksUtama),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: _Tema.teksAbu, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              _sandiTersembunyi ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _Tema.teksAbu,
              size: 20,
            ),
            onPressed: () => setState(() => _sandiTersembunyi = !_sandiTersembunyi),
          ),
          hintText: "Password",
          hintStyle: const TextStyle(color: _Tema.teksAbu, fontSize: 13.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ============================================================
  // 3 FITUR UNGGULAN DI BAWAH KARTU LOGIN -- murni informatif,
  // tidak ada aksi di baliknya.
  // ============================================================
  Widget _fiturKecil(IconData icon, String judul, String deskripsi) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _Tema.teksUtama, width: 1.2),
            ),
            child: Icon(icon, size: 20, color: _Tema.teksUtama),
          ),
          const SizedBox(height: 8),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _Tema.teksUtama, height: 1.25),
          ),
          const SizedBox(height: 4),
          Text(
            deskripsi,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 8.5, color: _Tema.teksAbu, height: 1.3),
          ),
        ],
      ),
    );
  }
}