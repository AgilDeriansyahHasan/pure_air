// lib/services/modules/histori_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../session.dart';
import '../users.dart';
// TODO: sesuaikan import/constant base URL dengan punyamu di lokasi_service.dart / prediksi_service.dart

class HistoriModel {
  final int id;
  final DateTime waktu;
  final double aqi, pm25, pm10, co, no2, so2, o3;

  HistoriModel({
    required this.id,
    required this.waktu,
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.co,
    required this.no2,
    required this.so2,
    required this.o3,
  });

  factory HistoriModel.fromJson(Map<String, dynamic> j) => HistoriModel(
    id: int.tryParse("${j['id']}") ?? 0,
    waktu: DateTime.parse(j['waktu']),
    aqi: double.tryParse("${j['aqi']}") ?? 0,
    pm25: double.tryParse("${j['pm25']}") ?? 0,
    pm10: double.tryParse("${j['pm10']}") ?? 0,
    co: double.tryParse("${j['co']}") ?? 0,
    no2: double.tryParse("${j['no2']}") ?? 0,
    so2: double.tryParse("${j['so2']}") ?? 0,
    o3: double.tryParse("${j['o3']}") ?? 0,
  );
}

class RingkasanHistori {
  final double aqiRata, aqiTertinggi, aqiTerendah;
  final String kondisiDominan;
  final int jumlahData;

  RingkasanHistori({
    required this.aqiRata,
    required this.aqiTertinggi,
    required this.aqiTerendah,
    required this.kondisiDominan,
    required this.jumlahData,
  });

  factory RingkasanHistori.fromJson(Map<String, dynamic> j) => RingkasanHistori(
    aqiRata: double.tryParse("${j['aqi_rata']}") ?? 0,
    aqiTertinggi: double.tryParse("${j['aqi_tertinggi']}") ?? 0,
    aqiTerendah: double.tryParse("${j['aqi_terendah']}") ?? 0,
    kondisiDominan: "${j['kondisi_dominan']}",
    jumlahData: int.tryParse("${j['jumlah_data']}") ?? 0,
  );
}

class HistoriResult {
  final List<HistoriModel> data;
  final RingkasanHistori? ringkasan;
  HistoriResult({required this.data, required this.ringkasan});
}

class HistoriService {
  // TODO: ganti sesuai constant endpoint yang kamu pakai, mis:
  // static const String _url = "${ApiConfig.baseUrl}/user/user_history.php";
  static const String _url = "${ApiService.baseUrl}/user/user_history.php";

  static Future<HistoriResult?> getHistori(
      String namaLokasi, {
        String? tanggalMulai,
        String? tanggalSelesai,
      }) async {
    final res = await http.post(Uri.parse(_url), body: {
      "action": "get_histori",
      "nama_lokasi": namaLokasi,
      if (tanggalMulai != null) "tanggal_mulai": tanggalMulai,
      if (tanggalSelesai != null) "tanggal_selesai": tanggalSelesai,
    });
    final body = jsonDecode(res.body);
    if (body["status"] != true) return null;
    final list = (body["data"] as List? ?? [])
        .map((e) => HistoriModel.fromJson(e))
        .toList();
    final ringkasan = body["ringkasan"] != null
        ? RingkasanHistori.fromJson(body["ringkasan"])
        : null;
    return HistoriResult(data: list, ringkasan: ringkasan);
  }

  static Future<bool> cekFavorit(String namaLokasi) async {
    final userId = await Session.getUserId();
    final res = await http.post(Uri.parse(_url), body: {
      "action": "cek_favorit",
      "nama_lokasi": namaLokasi,
      "user_id": "$userId",
    });
    final body = jsonDecode(res.body);
    return body["is_favorit"] == true;
  }

  static Future<bool> toggleFavorit(String namaLokasi) async {
    final userId = await Session.getUserId();
    final res = await http.post(Uri.parse(_url), body: {
      "action": "toggle_favorit",
      "nama_lokasi": namaLokasi,
      "user_id": "$userId",
    });
    final body = jsonDecode(res.body);
    return body["is_favorit"] == true;
  }

  static Future<List<Map<String, dynamic>>> favoritList() async {
    final userId = await Session.getUserId();
    final res = await http.post(Uri.parse(_url), body: {
      "action": "favorit_list",
      "user_id": "$userId",
    });
    final body = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(body["data"] ?? []);
  }
}