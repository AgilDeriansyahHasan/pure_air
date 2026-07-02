import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/users.dart';

class KelolaUserPage extends StatefulWidget {
  const KelolaUserPage({super.key});

  @override
  State<KelolaUserPage> createState() => _KelolaUserPageState();
}

class _KelolaUserPageState extends State<KelolaUserPage> {
  List users = [];
  List filteredUsers = [];

  bool isLoading = true;
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  // GET USERS
  Future<void> fetchUsers() async {
    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/users.php"),
        body: {
          "action": "get",
        },
      );

      if (response.statusCode == 200) {
        users = json.decode(response.body);

        setState(() {
          filteredUsers = users;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // DELETE
  Future<void> deleteUser(String id) async {
    await http.post(
      Uri.parse("${ApiService.baseUrl}/admin/users.php"),
      body: {
        "action": "delete",
        "id": id,
      },
    );

    fetchUsers();
  }

  // KIRIM KE LAPORAN (tombol "Export")
  // Mengirim kategori "user" ke tabel laporan_items di server,
  // sehingga muncul di halaman Laporan dan bisa di-download jadi PDF
  // bersama kategori lain.
  Future<void> kirimKeLaporan() async {
    setState(() {
      isExporting = true;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
        body: {
          "action": "kirim",
          "kategori": "user",
          "ringkasan": "${users.length} akun",
        },
      );

      if (!mounted) return;

      if (response.body.isEmpty) {
        throw "Server tidak mengirim response";
      }

      final data = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['status'] == "success"
                ? "Data user dikirim ke laporan"
                : (data['message'] ?? "Gagal mengirim ke laporan"),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  // SEARCH
  void search(String value) {
    setState(() {
      filteredUsers = users.where((u) {
        final username = u["username"].toString().toLowerCase();
        final email = u["email"].toString().toLowerCase();
        final query = value.toLowerCase();
        return username.contains(query) || email.contains(query);
      }).toList();
    });
  }

  // ROLE COLOR
  Color roleColor(String role) {
    switch (role.toLowerCase()) {
      case "admin":
        return const Color(0xff8B5CF6);
      default:
        return const Color(0xff3B82F6);
    }
  }

  // AVATAR COLOR (biar tiap user beda warna, konsisten berdasarkan nama)
  Color avatarColor(String name) {
    final colors = [
      const Color(0xff3B82F6),
      const Color(0xff10B981),
      const Color(0xffF59E0B),
      const Color(0xff8B5CF6),
      const Color(0xffEF4444),
      const Color(0xff06B6D4),
    ];
    final index = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    return colors[index];
  }

  // EDIT USER
  void editUserDialog(Map user) {
    final username = TextEditingController(text: user["username"]);
    final email = TextEditingController(text: user["email"]);
    String selectedRole = (user["role"] ?? "user").toString().toLowerCase();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text("Edit User"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: username,
                    decoration: const InputDecoration(
                      labelText: "Username",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: "Email",
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: "Role",
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "admin",
                        child: Text("Admin"),
                      ),
                      DropdownMenuItem(
                        value: "user",
                        child: Text("User"),
                      ),
                    ],
                    onChanged: (value) {
                      setLocalState(() {
                        selectedRole = value ?? selectedRole;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Batal"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text("Konfirmasi"),
                      content: const Text("Simpan perubahan user?"),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, false);
                          },
                          child: const Text("Tidak"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, true);
                          },
                          child: const Text("Ya"),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) return;

                  await http.post(
                    Uri.parse("${ApiService.baseUrl}/admin/users.php"),
                    body: {
                      "action": "update",
                      "id": user["id"].toString(),
                      "username": username.text,
                      "email": email.text,
                      "role": selectedRole,
                    },
                  );

                  Navigator.pop(context);
                  fetchUsers();
                },
                child: const Text("Update"),
              ),
            ],
          );
        },
      ),
    );
  }

  // DELETE CONFIRM
  void deleteConfirm(Map user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("Hapus User"),
        content: Text("Yakin ingin menghapus ${user["username"]}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              deleteUser(user["id"].toString());
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  // STAT CARD (tanpa grafik & tanpa persentase)
  Widget statCard(String title, String total, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black.withOpacity(.04),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              total,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // userCard sekarang menerima nomor urut TAMPILAN (1, 2, 3, ...)
  // bukan id dari database, supaya nomor selalu rapi berurutan
  // walau ada user yang sudah dihapus.
  Widget userCard(Map user, int urutan) {
    final username = (user["username"] ?? "-").toString();
    final email = (user["email"] ?? "-").toString();
    final role = (user["role"] ?? "-").toString();
    final createdAt = (user["created_at"] ?? "-").toString();
    final initial = username.isNotEmpty ? username[0].toUpperCase() : "?";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black.withOpacity(.03),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // NO (urutan tampilan, bukan id)
          SizedBox(
            width: 28,
            child: Text(
              urutan.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),

          // AVATAR
          CircleAvatar(
            backgroundColor: avatarColor(username).withOpacity(.15),
            child: Text(
              initial,
              style: TextStyle(
                color: avatarColor(username),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // USER, USERNAME, EMAIL, CREATED_AT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  createdAt,
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // PERAN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor(role).withOpacity(.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role,
              style: TextStyle(
                color: roleColor(role),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // AKSI (titik tiga, tidak diubah)
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == "edit") {
                editUserDialog(user);
              }
              if (value == "hapus") {
                deleteConfirm(user);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: "edit",
                child: Text("Edit"),
              ),
              const PopupMenuItem(
                value: "hapus",
                child: Text("Hapus"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUser = users.length;
    final totalAdmin = users
        .where((e) => (e["role"] ?? "").toString().toLowerCase() == "admin")
        .length;
    final totalRoleUser = users
        .where((e) => (e["role"] ?? "").toString().toLowerCase() == "user")
        .length;

    return Scaffold(
      backgroundColor: const Color(0xffF8F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xffF8F9FC),
        elevation: 0,
        title: const Text(
          "Kelola User",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: fetchUsers,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              // STAT CARDS
              Row(
                children: [
                  statCard(
                    "Total User",
                    totalUser.toString(),
                    const Color(0xff3B82F6),
                    Icons.people,
                  ),
                  const SizedBox(width: 10),
                  statCard(
                    "Admin",
                    totalAdmin.toString(),
                    const Color(0xff8B5CF6),
                    Icons.shield,
                  ),
                  const SizedBox(width: 10),
                  statCard(
                    "User",
                    totalRoleUser.toString(),
                    const Color(0xff10B981),
                    Icons.person,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // SEARCH + FILTER
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: search,
                      decoration: InputDecoration(
                        hintText: "Cari nama, email, atau username...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      onPressed: () {
                        // TODO: implementasi filter lanjutan
                      },
                      icon: const Icon(Icons.filter_list),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // EXPORT -> kirim data user ke halaman Laporan
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isExporting ? null : kirimKeLaporan,
                  icon: isExporting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.download),
                  label: Text(isExporting ? "Mengirim..." : "Export"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: Colors.black12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // HEADER TABEL
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 28,
                      child: Text(
                        "No",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 46),
                    const Expanded(
                      child: Text(
                        "User",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 40),
                      child: Text(
                        "Peran",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // LIST USER
              Expanded(
                child: filteredUsers.isEmpty
                    ? const Center(
                  child: Text("Tidak ada user ditemukan"),
                )
                    : ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    // nomor urut tampilan, selalu rapi 1, 2, 3, ...
                    // tidak lagi memakai id dari database
                    return userCard(user, index + 1);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}