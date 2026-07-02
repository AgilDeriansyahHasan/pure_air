import 'package:shared_preferences/shared_preferences.dart';

/// =========================================================
/// SESSION -- simpan & baca data user yang sedang login.
/// Dipanggil setelah login berhasil, dan dibaca dari halaman
/// mana saja yang butuh info user (dashboard, edit profil, dll).
///
/// PERUBAHAN dari versi sebelumnya:
/// - Menambahkan penyimpanan "token" (dari login.php), karena
///   sekarang endpoint seperti user_profile.php mengidentifikasi
///   user lewat token di header Authorization, bukan lewat user_id
///   yang dikirim manual.
/// =========================================================
class Session {
  // Key yang dipakai di SharedPreferences
  static const _kId    = "user_id";
  static const _kNama  = "user_nama";
  static const _kEmail = "user_email";
  static const _kFoto  = "user_foto";
  static const _kToken = "user_token";

  /// Simpan data user setelah login berhasil.
  /// Dipanggil di halaman login setelah response PHP sukses.
  static Future<void> simpan({
    required int    id,
    required String nama,
    required String email,
    required String token,
    String?         foto,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(   _kId,    id);
    await prefs.setString(_kNama,  nama);
    await prefs.setString(_kEmail, email);
    await prefs.setString(_kToken, token);
    if (foto != null) await prefs.setString(_kFoto, foto);
  }

  /// Ambil ID user yang sedang login.
  /// Mengembalikan 0 kalau belum ada session.
  static Future<int> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kId) ?? 0;
  }

  /// Ambil token login yang sedang aktif.
  /// Mengembalikan null kalau belum ada session -- dipakai oleh
  /// semua service (mis. user_profile) untuk header Authorization.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  /// Ambil semua data user sekaligus.
  static Future<Map<String, dynamic>> getData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "id":    prefs.getInt(_kId)       ?? 0,
      "nama":  prefs.getString(_kNama)  ?? "",
      "email": prefs.getString(_kEmail) ?? "",
      "foto":  prefs.getString(_kFoto),
      "token": prefs.getString(_kToken),
    };
  }

  /// Update nama & email di session (dipanggil setelah edit profil berhasil).
  static Future<void> updateProfil({
    required String nama,
    required String email,
    String?         foto,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNama,  nama);
    await prefs.setString(_kEmail, email);
    if (foto != null) await prefs.setString(_kFoto, foto);
  }

  /// Hapus semua session (dipanggil saat logout).
  /// Idealnya dipanggil SETELAH memanggil endpoint logout.php,
  /// supaya token juga dicabut di server -- bukan cuma di HP.
  static Future<void> hapus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Cek apakah user sedang login (ada session aktif).
  static Future<bool> sudahLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    return (prefs.getInt(_kId) ?? 0) > 0 && token != null && token.isNotEmpty;
  }
}