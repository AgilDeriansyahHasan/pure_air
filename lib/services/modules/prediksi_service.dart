import 'dart:convert';
import 'package:http/http.dart' as http;
import '../session.dart';
import '../users.dart';

// =========================================================
// MODEL: 1 baris hasil prediksi (per slot jam) untuk 1 lokasi.
// Struktur field mengikuti pola yang sama dengan tabel `monitoring`
// (lihat DataPolutan di halaman Info Polutan) -- kalau nama kolom
// asli di `monitoring_prediksi` ternyata berbeda, cukup sesuaikan
// key di dalam fromJson ini saja, sisanya tidak perlu berubah.
// =========================================================
class PrediksiModel {
  final String id;
  final String monitoringId;
  final DateTime tanggal;
  final double aqi;
  final double pm25;
  final double pm10;
  final double co;
  final double no2;
  final double so2;
  final double o3;

  PrediksiModel({
    required this.id,
    required this.monitoringId,
    required this.tanggal,
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.co,
    required this.no2,
    required this.so2,
    required this.o3,
  });

  factory PrediksiModel.fromJson(Map<String, dynamic> j) {
    double d(String k) => double.tryParse((j[k] ?? "0").toString()) ?? 0;
    return PrediksiModel(
      id:            (j["id"] ?? "").toString(),
      monitoringId:  (j["monitoring_id"] ?? "").toString(),
      tanggal:       DateTime.tryParse((j["tanggal"] ?? "").toString()) ?? DateTime.now(),
      aqi:  d("aqi_prediksi"),
      pm25: d("pm25_prediksi"),
      pm10: d("pm10_prediksi"),
      co:   d("co_prediksi"),
      no2:  d("no2_prediksi"),
      so2:  d("so2_prediksi"),
      o3:   d("o3_prediksi"),
    );
  }
}

// =========================================================
// MODEL: info akurasi model Decision Tree per target (aqi, pm25, dst)
// =========================================================
class ModelPrediksiInfo {
  final String target;
  final double mape;
  final double akurasi;
  final int jumlahDataLatih;
  final String status;
  final String trainedAt;

  ModelPrediksiInfo({
    required this.target,
    required this.mape,
    required this.akurasi,
    required this.jumlahDataLatih,
    required this.status,
    required this.trainedAt,
  });

  factory ModelPrediksiInfo.fromJson(Map<String, dynamic> j) {
    double d(String k) => double.tryParse((j[k] ?? "0").toString()) ?? 0;
    return ModelPrediksiInfo(
      target:          (j["target"] ?? "").toString(),
      mape:            d("mape"),
      akurasi:         d("akurasi"),
      jumlahDataLatih: int.tryParse((j["jumlah_data_latih"] ?? "0").toString()) ?? 0,
      status:          (j["status"] ?? "").toString(),
      trainedAt:       (j["trained_at"] ?? "").toString(),
    );
  }
}

// =========================================================
// MODEL: hasil gabungan get_prediksi -- info model per target +
// daftar prediksi per slot jam.
// =========================================================
class PrediksiHasil {
  final Map<String, ModelPrediksiInfo> model;
  final List<PrediksiModel> data;

  PrediksiHasil({required this.model, required this.data});
}

// =========================================================
// MODEL: 1 item favorit prediksi (dipakai di favorit_list, juga bisa
// dipakai di halaman Tersimpan)
// =========================================================
class FavoritPrediksiItem {
  final String monitoringId;
  final String namaLokasi;

  FavoritPrediksiItem({required this.monitoringId, required this.namaLokasi});

  factory FavoritPrediksiItem.fromJson(Map<String, dynamic> j) {
    return FavoritPrediksiItem(
      monitoringId: (j["monitoring_id"] ?? "").toString(),
      namaLokasi:   (j["nama_lokasi"] ?? "").toString(),
    );
  }
}

// =========================================================
// SERVICE
// =========================================================
class PrediksiService {
  static const String _endpoint = "${ApiService.baseUrl}/user/user_prediksi.php";

  // ============================================================
  // lastError -- pesan kegagalan TERAKHIR dari get_prediksi, diisi
  // tiap kali response dari server "status": false (mis. server
  // bilang "Lokasi \"X\" belum ada di monitoring") ATAU responsnya
  // ternyata bukan JSON valid (misal ada PHP warning/notice yang
  // ketercetak sebelum echo json_encode di user_prediksi.php).
  //
  // Ini SENGAJA ditambahkan sebagai field terpisah (bukan mengubah
  // return type getPrediksi) supaya tidak mengubah kontrak lama --
  // pemanggil yang sudah ada (mis. PrediksiPage) tetap jalan seperti
  // biasa (null = gagal), tapi pemanggil yang mau tahu ALASAN
  // pastinya (mis. DashboardGuest) tinggal baca
  // `PrediksiService.lastError` setelah getPrediksi() balikin null.
  // ============================================================
  static String? lastError;

  // ---- get_prediksi ----
  static Future<PrediksiHasil?> getPrediksi(String namaLokasi) async {
    lastError = null;

    final res = await http.post(Uri.parse(_endpoint), body: {
      "action":      "get_prediksi",
      "nama_lokasi": namaLokasi,
    }).timeout(const Duration(seconds: 15));

    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (_) {
      // Biasanya ini terjadi kalau PHP-nya sempat ngeprint warning/
      // notice SEBELUM echo json_encode(...) -- jadinya body bukan
      // JSON murni lagi. Cek response mentahnya (res.body) buat pastiin.
      lastError = "Respons server tidak valid (bukan JSON). "
          "Cek apakah ada error/warning PHP yang ikut tercetak di "
          "user_prediksi.php sebelum json_encode dipanggil.";
      return null;
    }

    if (body["status"] != true) {
      // Ini yang paling sering kejadian: nama_lokasi yang dikirim
      // tidak ditemukan oleh getMonitoringByNama() di PHP -- artinya
      // nama di tabel `lokasi` (dipakai di Peta) tidak sama persis
      // dengan nama di tabel `monitoring` (dipakai di Prediksi).
      lastError = (body["message"] ?? "Gagal memuat data prediksi").toString();
      return null;
    }

    final modelJson = Map<String, dynamic>.from(body["model"] ?? {});
    final model = modelJson.map(
          (target, v) => MapEntry(target, ModelPrediksiInfo.fromJson(Map<String, dynamic>.from(v))),
    );

    final List dataRaw = body["data"] ?? [];
    final data = dataRaw
        .map((e) => PrediksiModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return PrediksiHasil(model: model, data: data);
  }

  // ---- list_user ----
  static Future<List<String>> listUser() async {
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action": "list_user",
    }).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body);
    if (body["status"] != true) return [];

    final List data = body["data"] ?? [];
    return data.map((e) => (e["nama_lokasi"] ?? "").toString()).toList();
  }

  // ---- cek_favorit ----
  // user_id diambil otomatis dari Session, sama seperti pola di
  // LokasiService -- pemanggil tidak perlu tahu/kirim user_id manual.
  static Future<bool> cekFavorit(String namaLokasi) async {
    final userId = await Session.getUserId();
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action":      "cek_favorit",
      "nama_lokasi": namaLokasi,
      "user_id":     "$userId",
    }).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body);
    if (body["status"] != true) return false;
    return body["is_favorit"] == true;
  }

  // ---- toggle_favorit ----
  // Return status favorit yang BARU (setelah toggle), supaya UI di
  // pemanggil tinggal langsung setState tanpa perlu cek ulang.
  static Future<bool> toggleFavorit(String namaLokasi) async {
    final userId = await Session.getUserId();
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action":      "toggle_favorit",
      "nama_lokasi": namaLokasi,
      "user_id":     "$userId",
    }).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body);
    if (body["status"] != true) {
      throw Exception(body["message"] ?? "Gagal mengubah status favorit");
    }
    return body["is_favorit"] == true;
  }

  // ---- favorit_list ----
  // Daftar semua lokasi yang difavoritkan user khusus dari halaman
  // Prediksi. Dipakai di halaman "Tersimpan" (user_saved_page.dart)
  // untuk kategori tersendiri (terpisah dari favorit Peta/Histori).
  static Future<List<FavoritPrediksiItem>> favoritList() async {
    final userId = await Session.getUserId();
    final res = await http.post(Uri.parse(_endpoint), body: {
      "action":  "favorit_list",
      "user_id": "$userId",
    }).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body);
    if (body["status"] != true) return [];

    final List data = body["data"] ?? [];
    return data
        .map((e) => FavoritPrediksiItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}