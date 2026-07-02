import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../services/users.dart';
import '../../services/session.dart';

// =========================================================
// TEMA
// =========================================================
class _T {
  static const bg     = Color(0xFFF5F5F5);
  static const card   = Colors.white;
  static const border = Color(0xFFE0E0E0);
  static const abu    = Color(0xFF8A8A8E);
  static const hitam  = Color(0xFF1C1C1E);
  static const biru   = Color(0xFF2F80ED);
  static const merah  = Color(0xFFFF3B30);
}

// =========================================================
// SERVICE
// =========================================================
class _ProfileService {
  static const _ep = "${ApiService.baseUrl}/user/user_profile.php";

  static Future<Map<String, dynamic>> getProfil(int userId) async {
    final res = await http.post(Uri.parse(_ep), body: {
      "action":  "get_profile",
      "user_id": userId.toString(),
    }).timeout(const Duration(seconds: 15));
    final j = jsonDecode(res.body);
    if (j["status"] != true) throw Exception(j["message"]);
    return Map<String, dynamic>.from(j["data"]);
  }

  static Future<void> updateProfil({
    required int    userId,
    required String nama,
    required String email,
    String passLama = "",
    String passBaru = "",
  }) async {
    final res = await http.post(Uri.parse(_ep), body: {
      "action":        "update_profile",
      "user_id":       userId.toString(),
      "nama":          nama,
      "email":         email,
      "password_lama": passLama,
      "password_baru": passBaru,
    }).timeout(const Duration(seconds: 15));
    final j = jsonDecode(res.body);
    if (j["status"] != true) throw Exception(j["message"]);
  }

  static Future<String> uploadFoto(int userId, File file) async {
    final req = http.MultipartRequest("POST", Uri.parse(_ep));
    req.fields["action"]  = "upload_foto";
    req.fields["user_id"] = userId.toString();
    req.files.add(await http.MultipartFile.fromPath("foto", file.path));

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final res      = await http.Response.fromStream(streamed);
    final j        = jsonDecode(res.body);
    if (j["status"] != true) throw Exception(j["message"]);
    return j["foto_url"].toString();
  }
}

// =========================================================
// HALAMAN EDIT PROFILE
// =========================================================
class EditProfilePage extends StatefulWidget {
  // Kirim user_id dari session/SharedPreferences saat navigasi ke halaman ini
  // Contoh: Navigator.push(context, MaterialPageRoute(
  //   builder: (_) => EditProfilePage(userId: sessionUserId)));
  final int userId;

  const EditProfilePage({super.key, required this.userId});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey    = GlobalKey<FormState>();
  final _namaCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passLamaCtrl = TextEditingController();
  final _passBaru1Ctrl = TextEditingController();
  final _passBaru2Ctrl = TextEditingController();

  bool _loading    = true;
  bool _menyimpan  = false;
  bool _uploadFoto = false;
  String? _error;

  // Foto
  String? _fotoUrl;       // URL foto dari server
  File?   _fotoLokal;     // file baru yang dipilih tapi belum diupload
  bool _ubahPassword = false;
  bool _lihatPassLama  = false;
  bool _lihatPassBaru1 = false;
  bool _lihatPassBaru2 = false;

  @override
  void initState() {
    super.initState();
    _muatProfil();
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _passLamaCtrl.dispose();
    _passBaru1Ctrl.dispose();
    _passBaru2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _muatProfil() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _ProfileService.getProfil(widget.userId);
      if (!mounted) return;
      setState(() {
        _namaCtrl.text  = data["nama"]  ?? "";
        _emailCtrl.text = data["email"] ?? "";
        _fotoUrl        = data["foto_url"];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- Pilih foto dari galeri / kamera ----
  Future<void> _pilihFoto(ImageSource source) async {
    Navigator.pop(context); // tutup bottom sheet pilihan sumber
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _fotoLokal = File(picked.path));
    } catch (_) {
      _snack("Gagal memilih foto", error: true);
    }
  }

  void _tampilkanPilihFoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _T.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: _T.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text("Ubah Foto Profil",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _T.biru.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.photo_library_outlined, color: _T.biru),
            ),
            title: const Text("Pilih dari Galeri"),
            onTap: () => _pilihFoto(ImageSource.gallery),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _T.biru.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_outlined, color: _T.biru),
            ),
            title: const Text("Ambil Foto"),
            onTap: () => _pilihFoto(ImageSource.camera),
          ),
          if (_fotoUrl != null || _fotoLokal != null)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _T.merah.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline, color: _T.merah),
              ),
              title: const Text("Hapus Foto",
                  style: TextStyle(color: _T.merah)),
              onTap: () {
                Navigator.pop(context);
                setState(() { _fotoLokal = null; _fotoUrl = null; });
              },
            ),
        ]),
      ),
    );
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi password baru kalau mode ubah password aktif
    if (_ubahPassword) {
      if (_passLamaCtrl.text.isEmpty) {
        _snack("Masukkan password lama", error: true);
        return;
      }
      if (_passBaru1Ctrl.text.length < 6) {
        _snack("Password baru minimal 6 karakter", error: true);
        return;
      }
      if (_passBaru1Ctrl.text != _passBaru2Ctrl.text) {
        _snack("Konfirmasi password tidak cocok", error: true);
        return;
      }
    }

    setState(() => _menyimpan = true);
    try {
      // 1. Upload foto baru kalau ada
      if (_fotoLokal != null) {
        setState(() => _uploadFoto = true);
        final url = await _ProfileService.uploadFoto(widget.userId, _fotoLokal!);
        setState(() { _fotoUrl = url; _fotoLokal = null; _uploadFoto = false; });
      }

      // 2. Update data profil
      await _ProfileService.updateProfil(
        userId:   widget.userId,
        nama:     _namaCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
        passLama: _ubahPassword ? _passLamaCtrl.text : "",
        passBaru: _ubahPassword ? _passBaru1Ctrl.text : "",
      );

      if (!mounted) return;

      // Bersihkan field password
      _passLamaCtrl.clear();
      _passBaru1Ctrl.clear();
      _passBaru2Ctrl.clear();
      setState(() => _ubahPassword = false);

      _snack("Profil berhasil disimpan ✓");

      // Kasih tahu halaman sebelumnya kalau ada update (opsional)
      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), error: true);
    } finally {
      if (mounted) setState(() { _menyimpan = false; _uploadFoto = false; });
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _T.merah : Colors.green,
    ));
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.card,
        foregroundColor: _T.hitam,
        elevation: 0.5,
        title: const Text("Edit Profil",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _menyimpan ? null : _simpan,
              child: _menyimpan
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _T.biru))
                  : const Text("Simpan",
                  style: TextStyle(color: _T.biru, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _buildForm(),
    );
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 40, color: _T.abu),
      const SizedBox(height: 8),
      Text(_error!, textAlign: TextAlign.center,
          style: const TextStyle(color: _T.abu)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _muatProfil, child: const Text("Coba lagi")),
    ]));
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ---- FOTO PROFIL ----
          Center(child: Stack(
            children: [
              // Lingkaran foto
              GestureDetector(
                onTap: _tampilkanPilihFoto,
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _T.border,
                    border: Border.all(color: _T.biru, width: 3),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08),
                          blurRadius: 10)
                    ],
                  ),
                  child: ClipOval(
                    child: _uploadFoto
                        ? const Center(child: CircularProgressIndicator())
                        : _fotoLokal != null
                        ? Image.file(_fotoLokal!, fit: BoxFit.cover)
                        : _fotoUrl != null
                        ? Image.network(_fotoUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatarDefault())
                        : _avatarDefault(),
                  ),
                ),
              ),
              // Tombol kamera kecil di pojok bawah kanan
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _tampilkanPilihFoto,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: _T.biru,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          )),

          if (_fotoLokal != null) ...[
            const SizedBox(height: 8),
            const Center(
              child: Text("Foto baru dipilih, akan diupload saat simpan",
                  style: TextStyle(fontSize: 11, color: _T.abu)),
            ),
          ],

          const SizedBox(height: 28),

          // ---- INFORMASI AKUN ----
          _sectionLabel("Informasi Akun"),
          const SizedBox(height: 10),
          _kartu(children: [
            _fieldTeks(
              controller: _namaCtrl,
              label: "Nama Lengkap",
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? "Nama tidak boleh kosong" : null,
            ),
            const Divider(height: 1, color: _T.border),
            _fieldTeks(
              controller: _emailCtrl,
              label: "Email",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Email tidak boleh kosong";
                if (!v.contains("@")) return "Format email tidak valid";
                return null;
              },
            ),
          ]),

          const SizedBox(height: 20),

          // ---- UBAH PASSWORD ----
          _sectionLabel("Keamanan"),
          const SizedBox(height: 10),
          _kartu(children: [
            InkWell(
              onTap: () => setState(() {
                _ubahPassword = !_ubahPassword;
                if (!_ubahPassword) {
                  _passLamaCtrl.clear();
                  _passBaru1Ctrl.clear();
                  _passBaru2Ctrl.clear();
                }
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  const Icon(Icons.lock_outline, size: 20, color: _T.abu),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text("Ubah Password",
                        style: TextStyle(fontSize: 14, color: _T.hitam)),
                  ),
                  Icon(_ubahPassword
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                      color: _T.abu),
                ]),
              ),
            ),

            // Field password (muncul kalau toggle aktif)
            if (_ubahPassword) ...[
              const Divider(height: 1, color: _T.border),
              _fieldPassword(
                controller: _passLamaCtrl,
                label: "Password Lama",
                lihat: _lihatPassLama,
                onToggle: () => setState(() => _lihatPassLama = !_lihatPassLama),
              ),
              const Divider(height: 1, color: _T.border),
              _fieldPassword(
                controller: _passBaru1Ctrl,
                label: "Password Baru",
                lihat: _lihatPassBaru1,
                onToggle: () => setState(() => _lihatPassBaru1 = !_lihatPassBaru1),
              ),
              const Divider(height: 1, color: _T.border),
              _fieldPassword(
                controller: _passBaru2Ctrl,
                label: "Konfirmasi Password Baru",
                lihat: _lihatPassBaru2,
                onToggle: () => setState(() => _lihatPassBaru2 = !_lihatPassBaru2),
              ),
            ],
          ]),

          const SizedBox(height: 28),

          // ---- TOMBOL SIMPAN ----
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _menyimpan ? null : _simpan,
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.biru,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _menyimpan
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Simpan Perubahan",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // =========================================================
  // WIDGET HELPERS
  // =========================================================
  Widget _avatarDefault() {
    return Container(
      color: _T.biru.withOpacity(0.1),
      child: const Icon(Icons.person, size: 52, color: _T.biru),
    );
  }

  Widget _sectionLabel(String teks) {
    return Text(teks,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: _T.abu, letterSpacing: 0.5));
  }

  Widget _kartu({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _T.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _fieldTeks({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   controller,
      keyboardType: keyboardType,
      validator:    validator,
      decoration: InputDecoration(
        labelText:    label,
        prefixIcon:   Icon(icon, size: 20, color: _T.abu),
        border:       InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle:   const TextStyle(color: _T.abu, fontSize: 14),
      ),
    );
  }

  Widget _fieldPassword({
    required TextEditingController controller,
    required String label,
    required bool lihat,
    required VoidCallback onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !lihat,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: _T.abu),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            lihat ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20, color: _T.abu,
          ),
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: _T.abu, fontSize: 14),
      ),
    );
  }
}