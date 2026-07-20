import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/user_model.dart';
import '../users.dart'; // ApiService.baseUrl (sudah ada sebelumnya)

/// Hasil generik untuk aksi yang mengembalikan status sukses/gagal
/// beserta pesan (dipakai untuk kirim ke laporan, dsb).
class ServiceResult {
  final bool success;
  final String message;

  const ServiceResult({required this.success, required this.message});
}

/// Semua request HTTP terkait user ditarik ke sini.
///
/// Sebelumnya logic ini nyempil langsung di dalam KelolaUserPage
/// (fetchUsers, deleteUser, kirimKeLaporan). Sekarang dipisah supaya
/// page cuma fokus urusan UI, dan service ini bisa dipakai ulang
/// dari halaman lain kalau perlu.
class UserService {
  UserService._(); // no instance

  static Uri get _usersEndpoint =>
      Uri.parse("${ApiService.baseUrl}/admin/users.php");

  static Uri get _laporanEndpoint =>
      Uri.parse("${ApiService.baseUrl}/admin/laporan.php");

  /// Ambil semua user.
  static Future<List<UserModel>> getUsers() async {
    final response = await http.post(
      _usersEndpoint,
      body: {"action": "get"},
    );

    if (response.statusCode != 200) {
      throw Exception("Gagal memuat data user (status ${response.statusCode})");
    }

    final List data = json.decode(response.body);
    return data
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Hapus user berdasarkan id.
  static Future<void> deleteUser(String id) async {
    await http.post(
      _usersEndpoint,
      body: {
        "action": "delete",
        "id": id,
      },
    );
  }

  /// Update data user (username, email, role).
  static Future<void> updateUser({
    required String id,
    required String username,
    required String email,
    required String role,
  }) async {
    await http.post(
      _usersEndpoint,
      body: {
        "action": "update",
        "id": id,
        "username": username,
        "email": email,
        "role": role,
      },
    );
  }

  /// Kirim ringkasan data user ke laporan (tombol "Export ke Laporan").
  static Future<ServiceResult> kirimKeLaporan(int totalUser) async {
    final response = await http.post(
      _laporanEndpoint,
      body: {
        "action": "kirim",
        "kategori": "user",
        "ringkasan": "$totalUser akun",
      },
    );

    if (response.body.isEmpty) {
      throw "Server tidak mengirim response";
    }

    final data = jsonDecode(response.body);
    final isSuccess = data['status'] == "success";

    return ServiceResult(
      success: isSuccess,
      message: isSuccess
          ? "Data user dikirim ke laporan"
          : (data['message'] ?? "Gagal mengirim ke laporan").toString(),
    );
  }
}