import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';
import '../../models/user_model.dart';
import '../../services/modules/user_service.dart';

class KelolaUserPage extends StatefulWidget {
  const KelolaUserPage({super.key});

  @override
  State<KelolaUserPage> createState() => _KelolaUserPageState();
}

class _KelolaUserPageState extends State<KelolaUserPage> {
  List<UserModel> users = [];
  List<UserModel> filteredUsers = [];

  bool isLoading = true;
  bool isExporting = false;

  final TextEditingController searchController = TextEditingController();

  // FILTER ROLE: "semua" | "admin" | "user"
  String roleFilter = "semua";

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // GET USERS
  Future<void> fetchUsers() async {
    try {
      final data = await UserService.getUsers();
      if (!mounted) return;
      setState(() {
        users = data;
        isLoading = false;
      });
      applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // DELETE
  Future<void> deleteUser(String id) async {
    await UserService.deleteUser(id);
    fetchUsers();
  }

  // KIRIM KE LAPORAN (tombol "Export")
  Future<void> kirimKeLaporan() async {
    setState(() {
      isExporting = true;
    });

    try {
      final result = await UserService.kirimKeLaporan(users.length);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor:
          result.success ? const Color(0xff1F2937) : AdminTheme.danger,
          content: Text(result.message),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AdminTheme.danger,
          content: Text("Error: $e"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  // SEARCH + FILTER ROLE (digabung jadi satu sumber kebenaran)
  void search(String value) {
    applyFilter();
  }

  void setRoleFilter(String value) {
    setState(() {
      roleFilter = value;
    });
    applyFilter();
  }

  void applyFilter() {
    final query = searchController.text.toLowerCase();

    setState(() {
      filteredUsers = users.where((u) {
        final matchQuery = u.username.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query);
        final matchRole = roleFilter == "semua" || u.roleNormalized == roleFilter;

        return matchQuery && matchRole;
      }).toList();
    });
  }

  // EDIT USER
  void editUserDialog(UserModel user) {
    final username = TextEditingController(text: user.username);
    final email = TextEditingController(text: user.email);
    String selectedRole = user.roleNormalized == "admin" ? "admin" : "user";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) {
          final themeColor = AdminTheme.roleColor(selectedRole);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            title: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_rounded, color: themeColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Edit User",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  _dialogField(username, "Username", Icons.badge_outlined, themeColor),
                  const SizedBox(height: 14),
                  _dialogField(email, "Email", Icons.mail_outline_rounded, themeColor),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: "Role",
                      prefixIcon:
                      Icon(AdminTheme.roleIcon(selectedRole), size: 20, color: themeColor),
                      filled: true,
                      fillColor: themeColor.withOpacity(.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: themeColor, width: 1.4),
                      ),
                      labelStyle: TextStyle(color: themeColor.withOpacity(.9)),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: "admin",
                        child: Row(
                          children: [
                            Icon(Icons.shield_rounded, size: 16, color: AdminTheme.admin),
                            const SizedBox(width: 8),
                            const Text("Admin"),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: "user",
                        child: Row(
                          children: [
                            Icon(Icons.person_rounded, size: 16, color: AdminTheme.regularUser),
                            const SizedBox(width: 8),
                            const Text("User"),
                          ],
                        ),
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
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.black54),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(context, true);
                          },
                          child: const Text("Ya"),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) return;

                  await UserService.updateUser(
                    id: user.id,
                    username: username.text,
                    email: email.text,
                    role: selectedRole,
                  );

                  if (!mounted) return;
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

  Widget _dialogField(
      TextEditingController c, String label, IconData icon, Color themeColor) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: themeColor),
        filled: true,
        fillColor: themeColor.withOpacity(.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: themeColor, width: 1.4),
        ),
        labelStyle: TextStyle(color: themeColor.withOpacity(.9)),
      ),
    );
  }

  // DELETE CONFIRM
  void deleteConfirm(UserModel user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminTheme.danger.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AdminTheme.danger, size: 20),
            ),
            const SizedBox(width: 12),
            const Text("Hapus User", style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text("Yakin ingin menghapus ${user.username}?"),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.black54),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              deleteUser(user.id);
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  // STAT CARD
  Widget statCard(String title, String total, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AdminTheme.cardDecoration(shadowOpacity: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: AdminTheme.teksAbu,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              total,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AdminTheme.teksUtama,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget userCard(UserModel user, int urutan) {
    final initial = user.username.isNotEmpty ? user.username[0].toUpperCase() : "?";
    final aColor = AdminTheme.avatarColor(user.username);
    final rColor = AdminTheme.roleColor(user.role);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AdminTheme.cardDecoration(shadowOpacity: 0.035),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => editUserDialog(user),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    urutan.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black38,
                      fontSize: 13,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 21,
                  backgroundColor: aColor.withOpacity(.14),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: aColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: AdminTheme.teksUtama,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.email,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 11, color: Colors.black38),
                          const SizedBox(width: 3),
                          Text(
                            user.createdAt,
                            style: const TextStyle(
                                fontSize: 10.5, color: Colors.black38),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: rColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AdminTheme.roleIcon(user.role), size: 12, color: rColor),
                      const SizedBox(width: 4),
                      Text(
                        user.role,
                        style: TextStyle(
                          color: rColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert, color: Colors.black45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Colors.black54),
                          SizedBox(width: 10),
                          Text("Edit"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: "hapus",
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: AdminTheme.danger),
                          SizedBox(width: 10),
                          Text("Hapus", style: TextStyle(color: AdminTheme.danger)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // FILTER BUTTON (Semua / Admin / User)
  Widget _buildFilterButton() {
    final isActive = roleFilter != "semua";
    final activeColor = isActive ? AdminTheme.roleColor(roleFilter) : const Color(0xff374151);

    return Container(
      decoration: BoxDecoration(
        color: isActive ? activeColor.withOpacity(.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: activeColor.withOpacity(.4)) : null,
        boxShadow: isActive ? [] : AdminTheme.cardShadow(opacity: 0.03),
      ),
      child: PopupMenuButton<String>(
        tooltip: "Filter peran",
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: setRoleFilter,
        icon: Icon(Icons.tune_rounded, color: activeColor),
        itemBuilder: (_) => [
          _filterMenuItem("semua", "Semua", Icons.groups_rounded, const Color(0xff374151)),
          _filterMenuItem("admin", "Admin", Icons.shield_rounded, AdminTheme.admin),
          _filterMenuItem("user", "User", Icons.person_rounded, AdminTheme.regularUser),
        ],
      ),
    );
  }

  PopupMenuItem<String> _filterMenuItem(
      String value, String label, IconData icon, Color color) {
    final selected = roleFilter == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? color : const Color(0xff374151),
            ),
          ),
          if (selected) ...[
            const Spacer(),
            Icon(Icons.check_rounded, size: 16, color: color),
          ],
        ],
      ),
    );
  }

  Widget emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AdminTheme.primary.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search_rounded,
                size: 40, color: AdminTheme.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            "Tidak ada user ditemukan",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Coba kata kunci lain",
            style: TextStyle(color: Colors.black38, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUser = users.length;
    final totalAdmin = users.where((e) => e.roleNormalized == "admin").length;
    final totalRoleUser = users.where((e) => e.roleNormalized == "user").length;

    return Scaffold(
      backgroundColor: AdminTheme.bg,
      appBar: AppBar(
        backgroundColor: AdminTheme.bg,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          "Kelola User",
          style: TextStyle(
            color: AdminTheme.teksUtama,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: AdminTheme.teksUtama),
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(color: AdminTheme.primary),
      )
          : RefreshIndicator(
        color: AdminTheme.primary,
        onRefresh: fetchUsers,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            children: [
              // STAT CARDS
              Row(
                children: [
                  statCard(
                    "Total User",
                    totalUser.toString(),
                    AdminTheme.primary,
                    Icons.people_alt_rounded,
                  ),
                  const SizedBox(width: 10),
                  statCard(
                    "Admin",
                    totalAdmin.toString(),
                    AdminTheme.admin,
                    Icons.shield_rounded,
                  ),
                  const SizedBox(width: 10),
                  statCard(
                    "User",
                    totalRoleUser.toString(),
                    AdminTheme.regularUser,
                    Icons.person_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // SEARCH + FILTER
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AdminTheme.cardShadow(opacity: 0.03),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: search,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Cari nama, email, atau username...",
                          hintStyle: const TextStyle(
                              fontSize: 13.5, color: Colors.black38),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: Colors.black45),
                          suffixIcon: searchController.text.isEmpty
                              ? null
                              : IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: Colors.black45),
                            onPressed: () {
                              searchController.clear();
                              search("");
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildFilterButton(),
                ],
              ),

              if (roleFilter != "semua") ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    onDeleted: () => setRoleFilter("semua"),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    deleteIconColor: AdminTheme.roleColor(roleFilter),
                    avatar: Icon(
                      AdminTheme.roleIcon(roleFilter),
                      size: 15,
                      color: AdminTheme.roleColor(roleFilter),
                    ),
                    label: Text(
                      "Peran: ${roleFilter == "admin" ? "Admin" : "User"}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminTheme.roleColor(roleFilter),
                      ),
                    ),
                    backgroundColor: AdminTheme.roleColor(roleFilter).withOpacity(.1),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // EXPORT
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isExporting ? null : kirimKeLaporan,
                  icon: isExporting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.upload_file_rounded, size: 19),
                  label: Text(
                    isExporting ? "Mengirim..." : "Export ke Laporan",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // HEADER TABEL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 26,
                      child: Text(
                        "No",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          letterSpacing: .3,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 42),
                    const Expanded(
                      child: Text(
                        "USER",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          letterSpacing: .3,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 44),
                      child: Text(
                        "PERAN",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          letterSpacing: .3,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // LIST USER
              Expanded(
                child: filteredUsers.isEmpty
                    ? emptyState()
                    : ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
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