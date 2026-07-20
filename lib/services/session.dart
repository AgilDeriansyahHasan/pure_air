import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static const _keyUserId   = 'user_id';
  static const _keyUsername = 'username';
  static const _keyEmail    = 'email';
  static const _keyRole     = 'role';
  static const _keyFotoUrl  = 'foto_url';

  static Future<void> simpan({
    required int userId,
    required String username,
    required String email,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyRole, role);
  }

  static Future<void> simpanFotoUrl(String fotoUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFotoUrl, fotoUrl);
  }

  static Future<int> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId) ?? 0;
  }

  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername) ?? '';
  }

  // TAMBAHAN: getter untuk email, sebelumnya belum ada padahal
  // datanya sudah disimpan lewat Session.simpan(...).
  static Future<String> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail) ?? '';
  }

  // TAMBAHAN: getter untuk role, sebelumnya belum ada padahal
  // datanya sudah disimpan lewat Session.simpan(...).
  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole) ?? '';
  }

  static Future<String?> getFotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFotoUrl);
  }

  static Future<void> hapus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}