import 'package:flutter/material.dart';

/// Tema warna & style UNIVERSAL untuk semua halaman admin.
///
/// Sebelumnya tiap halaman punya palet sendiri-sendiri
/// (`_Tema` di dashboard, konstanta static di KelolaUserPage, dst).
/// Sekarang semua ditarik ke satu tempat ini supaya konsisten &
/// gampang diubah dari satu titik saja.
class AdminTheme {
  AdminTheme._(); // no instance

  // ---- WARNA DASAR ----
  static const bg          = Color(0xFFF6F7FB);
  static const card        = Color(0xFFFFFFFF);
  static const cardBorder  = Color(0xFFE9EAF0);

  // ---- WARNA TEKS ----
  static const teksUtama   = Color(0xFF111827);
  static const teksAbu     = Color(0xFF6B7280);

  // ---- WARNA AKSEN / BRAND ----
  static const primary     = Color(0xFF6366F1); // indigo (dipakai di Kelola User)
  static const primaryDark = Color(0xFF4F46E5);
  static const aksen       = Color(0xFFFB7155); // oranye (dipakai di Dashboard)

  // ---- WARNA STATUS / ROLE ----
  static const admin       = Color(0xFF8B5CF6);
  static const regularUser = Color(0xFF10B981);
  static const danger      = Color(0xFFEF4444);
  static const warning     = Color(0xFFEAB308);
  static const success     = Color(0xFF22C55E);
  static const info        = Color(0xFF3B82F6);

  /// Kategori AQI skala OpenWeather (1-5) -- dipakai di halaman mana pun
  /// yang menampilkan status kualitas udara (dashboard, kualitas udara,
  /// peta, validasi, dst) supaya warna & labelnya selalu sama.
  static const Map<String, Color> warnaKategoriAqi = {
    "Baik":         Color(0xFF22C55E),
    "Cukup baik":   Color(0xFF84CC16),
    "Sedang":       Color(0xFFEAB308),
    "Buruk":        Color(0xFFF97316),
    "Sangat buruk": Color(0xFFEF4444),
    "Tidak sehat":  Color(0xFFF97316), // alias lama
    "Berbahaya":    Color(0xFFEF4444), // alias lama
  };

  static String kategoriAqiOpenWeather(int? aqi) {
    switch (aqi) {
      case 1: return "Baik";
      case 2: return "Cukup baik";
      case 3: return "Sedang";
      case 4: return "Buruk";
      case 5: return "Sangat buruk";
      default: return "Tidak diketahui";
    }
  }

  static Color warnaAqi(int? aqi) =>
      warnaKategoriAqi[kategoriAqiOpenWeather(aqi)] ?? teksAbu;

  // ---- HELPER SHADOW & DEKORASI KARTU ----
  static List<BoxShadow> cardShadow({double opacity = 0.05}) => [
    BoxShadow(
      blurRadius: 14,
      offset: const Offset(0, 5),
      color: Colors.black.withOpacity(opacity),
    ),
  ];

  static BoxDecoration cardDecoration({double shadowOpacity = 0.04}) =>
      BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: cardShadow(opacity: shadowOpacity),
      );

  // ---- WARNA BERDASARKAN ROLE USER ----
  static Color roleColor(String role) {
    switch (role.toLowerCase()) {
      case "admin":
        return admin;
      default:
        return primary;
    }
  }

  static IconData roleIcon(String role) {
    switch (role.toLowerCase()) {
      case "admin":
        return Icons.shield_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  // ---- WARNA AVATAR (dari inisial nama, biar tiap user beda warna) ----
  static const List<Color> _paletteAvatar = [
    primary,
    regularUser,
    Color(0xFFF59E0B),
    admin,
    danger,
    Color(0xFF06B6D4),
  ];

  static Color avatarColor(String name) {
    if (name.isEmpty) return _paletteAvatar[0];
    return _paletteAvatar[name.codeUnitAt(0) % _paletteAvatar.length];
  }

  // ---- WARNA STATUS VALIDASI ----
  static Color warnaStatusValidasi(String status) {
    switch (status) {
      case "Valid":
      case "Diambil":
        return success;
      case "Ditolak":
        return danger;
      default:
        return warning;
    }
  }

  // ---- WARNA SEVERITY NOTIFIKASI ----
  static Color warnaSeverity(String severity) {
    switch (severity.toUpperCase()) {
      case "DANGER":
        return danger;
      case "WARNING":
        return warning;
      default:
        return aksen;
    }
  }
}