/// Model data User.
///
/// Dipakai oleh KelolaUserPage & UserService supaya tidak lagi
/// lempar-lempar `Map` mentah dari JSON. Semua akses field jadi
/// type-safe dan gampang di-debug.
class UserModel {
  final String id;
  final String username;
  final String email;
  final String role;
  final String createdAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '-').toString(),
      email: (json['email'] ?? '-').toString(),
      role: (json['role'] ?? 'user').toString(),
      createdAt: (json['created_at'] ?? '-').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'role': role,
    'created_at': createdAt,
  };

  /// Role yang sudah dinormalisasi ke huruf kecil, dipakai untuk
  /// pencocokan warna/ikon/filter supaya konsisten.
  String get roleNormalized => role.toLowerCase();

  UserModel copyWith({
    String? username,
    String? email,
    String? role,
  }) {
    return UserModel(
      id: id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt,
    );
  }
}