import 'dart:convert';
import 'package:http/http.dart' as http;
import '../users.dart';   // ApiService.baseUrl
import '../session.dart'; // Session.getUserId()

// =========================================================
// MODEL LOKASI -- merepresentasikan 1 baris dari tabel `lokasi`
// yang dikembalikan oleh user/user_peta.php.
//
// Field `kategori` TIDAK datang dari API (API cuma kirim angka AQI
// mentah), jadi kategori dihitung sendiri di app pakai fungsi
// `kategoriDariAqi()` supaya konsisten dengan tampilan yang sudah ada
// di dashboard.
// =========================================================
class LokasiModel {
  final int id;
  final String nama;
  final double latitude;
  final double longitude;
  final String status;
  final int aqi;
  final double? pm25;
  final double? pm10;
  final double? co;
  final double? no2;
  final double? so2;
  final double? o3;
  final String? updateTerakhir;
  final double? jarakKm; // hanya terisi kalau dari action "nearest"

  LokasiModel({
    required this.id,
    required this.nama,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.aqi,
    this.pm25,
    this.pm10,
    this.co,
    this.no2,
    this.so2,
    this.o3,
    this.updateTerakhir,
    this.jarakKm,
  });

  factory LokasiModel.fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) => v == null ? null : double.tryParse(v.toString());
    int i(dynamic v) => int.tryParse(v?.toString() ?? "") ?? 0;

    return LokasiModel(
      id: i(j["id"]),
      nama: j["nama"]?.toString() ?? "",
      latitude: d(j["latitude"]) ?? 0,
      longitude: d(j["longitude"]) ?? 0,
      status: j["status"]?.toString() ?? "",
      aqi: i(j["aqi"]),
      pm25: d(j["pm25"]),
      pm10: d(j["pm10"]),
      co: d(j["co"]),
      no2: d(j["no2"]),
      so2: d(j["so2"]),
      o3: d(j["o3"]),
      updateTerakhir: j["update_terakhir"]?.toString(),
      jarakKm: d(j["jarak_km"]),
    );
  }
}

// Konversi nilai AQI numerik -> label kategori. Sama batasnya dengan
// yang dipakai di user_dashboard.dart supaya warna/label konsisten.
String kategoriDariAqi(num nilai) {
  if (nilai <= 50) return "Baik";
  if (nilai <= 65) return "Cukup baik";
  if (nilai <= 100) return "Sedang";
  if (nilai <= 150) return "Buruk";
  return "Sangat buruk";
}

class LokasiService {
  static const String _endpoint = "${ApiService.baseUrl}/user/user_peta.php";

  // ---------------------------------------------------
  // LIST -- daftar lokasi aktif (opsional search)
  // ---------------------------------------------------
  static Future<List<LokasiModel>> list({String search = ""}) async {
    final res = await http.post(
      Uri.parse(_endpoint),
      body: {
        "action": "list",
        if (search.isNotEmpty) "search": search,
      },
    );

    final body = jsonDecode(res.body);
    if (body["status"] != true) return [];

    final List data = body["data"] ?? [];
    return data.map((e) => LokasiModel.fromJson(e)).toList();
  }

  // ---------------------------------------------------
  // DETAIL -- 1 lokasi berdasarkan id
  // ---------------------------------------------------
  static Future<LokasiModel?> detail(int id) async {
    final res = await http.post(
      Uri.parse(_endpoint),
      body: {"action": "detail", "id": "$id"},
    );

    final body = jsonDecode(res.body);
    if (body["status"] != true) return null;

    return LokasiModel.fromJson(body["data"]);
  }

  // ---------------------------------------------------
  // NEAREST -- lokasi terdekat dari koordinat user
  // ---------------------------------------------------
  static Future<List<LokasiModel>> nearest({
    required double latitude,
    required double longitude,
    int limit = 5,
  }) async {
    final res = await http.post(
      Uri.parse(_endpoint),
      body: {
        "action": "nearest",
        "latitude": "$latitude",
        "longitude": "$longitude",
        "limit": "$limit",
      },
    );

    final body = jsonDecode(res.body);
    if (body["status"] != true) return [];

    final List data = body["data"] ?? [];
    return data.map((e) => LokasiModel.fromJson(e)).toList();
  }

  // ---------------------------------------------------
  // FAVORIT -- tambah / hapus / list
  // user_id diambil otomatis dari Session, jadi pemanggilnya
  // tidak perlu tahu-menahu soal login sama sekali.
  // ---------------------------------------------------
  static Future<bool> favoritTambah(int lokasiId) async {
    final userId = await Session.getUserId();
    final res = await http.post(
      Uri.parse(_endpoint),
      body: {
        "action": "favorit_tambah",
        "user_id": "$userId",
        "lokasi_id": "$lokasiId",
      },
    );
    final body = jsonDecode(res.body);
    return body["status"] == true;
  }

  static Future<bool> favoritHapus(int lokasiId) async {
    final userId = await Session.getUserId();
    final res = await http.post(
      Uri.parse(_endpoint),
      body: {
        "action": "favorit_hapus",
        "user_id": "$userId",
        "lokasi_id": "$lokasiId",
      },
    );
    final body = jsonDecode(res.body);
    return body["status"] == true;
  }

  static Future<List<LokasiModel>> favoritList() async {
    final userId = await Session.getUserId();
    final res = await http.post(
      Uri.parse(_endpoint),
      body: {
        "action": "favorit_list",
        "user_id": "$userId",
      },
    );

    final body = jsonDecode(res.body);
    if (body["status"] != true) return [];

    final List data = body["data"] ?? [];
    return data.map((e) => LokasiModel.fromJson(e)).toList();
  }
}