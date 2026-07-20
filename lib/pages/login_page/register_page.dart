import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/users.dart';
import 'login_page.dart';

// =========================================================
// WARNA & KONSTANTA TEMA -- disamakan persis dengan tema di
// login_page.dart supaya halaman register terasa satu kesatuan
// dengan sisa aplikasi.
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

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController username = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool isLoading = false;
  bool _sandiTersembunyi = true; // ← status tampil/sembunyi password

  Future<void> register() async {
    final user = username.text.trim();
    final mail = email.text.trim();
    final pass = password.text;

    // =====================
    // VALIDASI FRONTEND
    // =====================
    if (user.isEmpty || mail.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semua field harus diisi")),
      );
      return;
    }

    if (!mail.endsWith("@gmail.com")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email harus @gmail.com")),
      );
      return;
    }

    if (pass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password minimal 8 karakter")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/auth/register.php"),
        body: {
          "username": user,
          "email": mail,
          "password": pass,
        },
      );

      print("STATUS CODE: ${response.statusCode}");
      print("BODY: ${response.body}");

      // kalau server error / HTML balik
      if (response.body.isEmpty) {
        throw "Server tidak mengirim response";
      }

      final data = jsonDecode(response.body);

      // pastikan widget masih ada di tree sebelum pakai context
      if (!mounted) return;

      if (data['status'] == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Register gagal")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    username.dispose();
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
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: _Tema.teksUtama),
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

                    // KARTU FORM REGISTER
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
                            "Create Your Account",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: _Tema.teksUtama,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 22),

                          // USERNAME
                          _kolomInput(
                            controller: username,
                            hint: "Username",
                            icon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.name,
                          ),
                          const SizedBox(height: 14),

                          // EMAIL
                          _kolomInput(
                            controller: email,
                            hint: "Email (@gmail.com)",
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),

                          // PASSWORD
                          _kolomSandi(),
                          const SizedBox(height: 4),
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Text(
                              "Minimal 8 karakter",
                              style: TextStyle(
                                  fontSize: 11, color: _Tema.teksAbu),
                            ),
                          ),
                          const SizedBox(height: 22),

                          // TOMBOL REGISTER
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
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(30)),
                                ),
                                onPressed: isLoading ? null : register,
                                child: isLoading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.4),
                                )
                                    : const Text(
                                  "Register",
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      fontStyle: FontStyle.italic),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // SUDAH PUNYA AKUN
                          Center(
                            child: InkWell(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginPage()),
                                );
                              },
                              child: const Text.rich(
                                TextSpan(
                                  text: "Sudah punya akun? ",
                                  style: TextStyle(
                                      color: _Tema.teksAbu, fontSize: 12.5),
                                  children: [
                                    TextSpan(
                                      text: "Login",
                                      style: TextStyle(
                                          color: _Tema.aksen,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

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
  // KOLOM INPUT TEKS GENERIK (username/email) -- rounded pill,
  // ikon di depan, senada sama login_page.dart.
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
  // tampil/sembunyi) di belakang, sama seperti di login_page.dart.
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
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: _Tema.teksAbu, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              _sandiTersembunyi
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _Tema.teksAbu,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _sandiTersembunyi = !_sandiTersembunyi),
          ),
          hintText: "Password",
          hintStyle: const TextStyle(color: _Tema.teksAbu, fontSize: 13.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}