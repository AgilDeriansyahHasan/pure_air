import 'dart:convert';
import 'package:http/http.dart' as http;

// NOTE: sesuaikan path import ini kalau lokasi file users.dart beda.
import '../users.dart';
import '../../models/kualitas_udara.dart';

class KualitasUdaraHistoryService {
  static const String _endpoint = "${ApiService.baseUrl}/admin/monitoring.php";

  static Future<Map<String, dynamic>> _post(
      Map<String, String> body, {
        Duration timeout = const Duration(seconds: 15),
      }) async {
    final res = await http.post(Uri.parse(_endpoint), body: body).timeout(timeout);
    final Map<String, dynamic> decoded = jsonDecode(res.body);
    return decoded;
  }

  /// Ambil histori dari DB untuk satu lokasi (action=list_riwayat)
  static Future<List<CatatanUdara>> getByLokasi(String namaLokasi) async {
    if (namaLokasi == "Pilih Lokasi") return [];
    final body = await _post({
      "action":      "list_riwayat",
      "nama_lokasi": namaLokasi,
    });
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal mengambil data");

    final List data = body["data"] ?? [];
    return data.map((e) => CatatanUdara.fromJson(e)).toList()
      ..sort((a, b) => a.waktu.compareTo(b.waktu));
  }

  /// Ambil histori 7 hari dari OpenWeather → simpan ke DB (action=ambil_historis)
  static Future<List<CatatanUdara>> ambilHistoris(String namaLokasi) async {
    final body = await _post({
      "action":      "ambil_historis",
      "nama_lokasi": namaLokasi,
    }, timeout: const Duration(seconds: 60));
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal mengambil histori");

    final List data = body["data"] ?? [];
    return data.map((e) => CatatanUdara.fromJson(e)).toList()
      ..sort((a, b) => a.waktu.compareTo(b.waktu));
  }

  /// Daftar nama lokasi unik untuk dropdown (action=list)
  static Future<List<String>> getDaftarLokasi() async {
    final body = await _post({"action": "list"});
    if (body["status"] != true) return [];

    final List data = body["data"] ?? [];
    final nama = data
        .map((e) => (e["nama_lokasi"] ?? "").toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    nama.sort();
    return nama;
  }

  /// Fetch OpenWeather current → simpan ke slot jam terdekat (action=refresh)
  static Future<HasilRefresh> refreshLokasi(String namaLokasi) async {
    final body = await _post({
      "action":      "refresh",
      "nama_lokasi": namaLokasi,
    }, timeout: const Duration(seconds: 20));
    if (body["status"] != true) throw Exception(body["message"] ?? "Gagal memperbarui data");

    final List data = body["data"] ?? [];
    return HasilRefresh(
      status:  true,
      skipped: body["skipped"] == true,
      message: (body["message"] ?? "").toString(),
      data:    data.map((e) => CatatanUdara.fromJson(e)).toList()
        ..sort((a, b) => a.waktu.compareTo(b.waktu)),
    );
  }

  /// Kirim ringkasan lokasi ke halaman laporan (action=kirim, kategori=kualitas_udara)
  static Future<Map<String, dynamic>> kirimKeLaporan(String namaLokasi) async {
    final response = await http.post(
      Uri.parse("${ApiService.baseUrl}/admin/laporan.php"),
      body: {
        "action": "kirim",
        "kategori": "kualitas_udara",
        "ringkasan": namaLokasi,
      },
    );

    if (response.body.isEmpty) {
      throw Exception("Server tidak mengirim response");
    }
    return jsonDecode(response.body);
  }
}