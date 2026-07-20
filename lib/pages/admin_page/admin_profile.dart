import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../services/users.dart'; // Pastikan ApiService.baseUrl ada di sini

class UserModel {
  final int id;
  final String username;
  final String email;
  final String? fotoUrl;
  final String role;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.fotoUrl,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fotoUrl: json['foto_url'],
      role: json['role'] ?? 'user',
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final int userId;

  const EditProfileScreen({super.key, required this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const String _endpoint = "${ApiService.baseUrl}/user/user_profile.php";

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordLamaController = TextEditingController();
  final _passwordBaruController = TextEditingController();

  File? _fotoBaru;
  String? _fotoUrlLama;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordLamaController.dispose();
    _passwordBaruController.dispose();
    super.dispose();
  }

  // ==================== GET PROFILE ====================
  Future<void> _loadProfile() async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        body: {
          "action": "get_profile",
          "user_id": widget.userId.toString(),
        },
      );

      final data = jsonDecode(response.body);

      if (data['status'] == true && data['data'] != null) {
        final user = UserModel.fromJson(data['data']);
        setState(() {
          _usernameController.text = user.username;
          _emailController.text = user.email;
          _fotoUrlLama = user.fotoUrl;
          _isLoading = false;
        });
      } else {
        _showSnackBar(data['message'] ?? 'Gagal memuat profile');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan koneksi: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pilihFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _fotoBaru = File(picked.path);
      });
    }
  }

  // ==================== UPLOAD FOTO ====================
  Future<bool> _uploadFotoJikaAda() async {
    if (_fotoBaru == null) return true;

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_endpoint));
      request.fields['action'] = 'upload_foto';
      request.fields['user_id'] = widget.userId.toString();
      request.files.add(
        await http.MultipartFile.fromPath('foto', _fotoBaru!.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (data['status'] == true) {
        _fotoUrlLama = data['foto_url'];
        return true;
      } else {
        _showSnackBar(data['message'] ?? 'Gagal upload foto');
        return false;
      }
    } catch (e) {
      _showSnackBar('Gagal upload foto: $e');
      return false;
    }
  }

  // ==================== UPDATE DATA ====================
  Future<bool> _updateDataProfile() async {
    final body = {
      "action": "update_profile",
      "user_id": widget.userId.toString(),
      "username": _usernameController.text.trim(),
      "email": _emailController.text.trim(),
    };

    if (_passwordBaruController.text.trim().isNotEmpty) {
      body["password_lama"] = _passwordLamaController.text.trim();
      body["password_baru"] = _passwordBaruController.text.trim();
    }

    try {
      final response = await http.post(Uri.parse(_endpoint), body: body);
      final data = jsonDecode(response.body);

      if (data['status'] == true) {
        return true;
      } else {
        _showSnackBar(data['message'] ?? 'Gagal update profile');
        return false;
      }
    } catch (e) {
      _showSnackBar('Terjadi kesalahan: $e');
      return false;
    }
  }

  // ==================== SIMPAN PROFILE ====================
  Future<void> _simpanProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final fotoOk = await _uploadFotoJikaAda();
    if (!fotoOk) {
      setState(() => _isSaving = false);
      return;
    }

    final dataOk = await _updateDataProfile();
    setState(() => _isSaving = false);

    if (dataOk) {
      _showSnackBar('Profile berhasil diperbarui');
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey, // Membungkus form dengan valid yang benar
          child: Column(
            children: [
              GestureDetector(
                onTap: _pilihFoto,
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: _fotoBaru != null
                      ? FileImage(_fotoBaru!) as ImageProvider
                      : (_fotoUrlLama != null && _fotoUrlLama!.isNotEmpty
                      ? NetworkImage(_fotoUrlLama!)
                      : null),
                  child: (_fotoBaru == null && _fotoUrlLama == null)
                      ? const Icon(Icons.camera_alt, size: 32, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _pilihFoto,
                child: const Text('Ganti Foto'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email wajib diisi';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
                    return 'Format email tidak valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ganti Password (opsional)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordLamaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password Lama',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_passwordBaruController.text.trim().isNotEmpty &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Masukkan password lama';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordBaruController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password Baru (kosongkan jika tidak diubah)',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 6) {
                    return 'Password minimal 6 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _simpanProfile,
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Simpan Perubahan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}