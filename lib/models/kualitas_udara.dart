import 'dart:math' as math;
import 'package:flutter/material.dart';

// =========================================================
// SKALA AQI (US-EPA 0–500)
// =========================================================
class AqiKategori {
  final String label;
  final Color  warna;
  AqiKategori(this.label, this.warna);
}

AqiKategori kategoriDariAqi(int aqi) {
  if (aqi <= 50)  return AqiKategori("Baik",               const Color(0xFF22C55E));
  if (aqi <= 100) return AqiKategori("Sedang",             const Color(0xFFEAB308));
  if (aqi <= 150) return AqiKategori("Tidak sehat (SG)",   const Color(0xFFF97316));
  if (aqi <= 200) return AqiKategori("Tidak sehat",        const Color(0xFFEF4444));
  if (aqi <= 300) return AqiKategori("Sangat tidak sehat", const Color(0xFFA855F7));
  return             AqiKategori("Berbahaya",               const Color(0xFF7F1D1D));
}

int _subIndex(double c, List<List<double>> bp) {
  for (final b in bp) {
    if (c >= b[0] && c <= b[1]) {
      return (((b[3] - b[2]) / (b[1] - b[0])) * (c - b[0]) + b[2]).round();
    }
  }
  return bp.last[3].round();
}

const _bpPm25 = [
  [0.0, 12.0, 0.0, 50.0],
  [12.1, 35.4, 51.0, 100.0],
  [35.5, 55.4, 101.0, 150.0],
  [55.5, 150.4, 151.0, 200.0],
  [150.5, 250.4, 201.0, 300.0],
  [250.5, 500.4, 301.0, 500.0],
];

const _bpPm10 = [
  [0.0, 54.0, 0.0, 50.0],
  [55.0, 154.0, 51.0, 100.0],
  [155.0, 254.0, 101.0, 150.0],
  [255.0, 354.0, 151.0, 200.0],
  [355.0, 424.0, 201.0, 300.0],
  [425.0, 604.0, 301.0, 500.0],
];

int hitungAqi(double pm25, double pm10) =>
    math.max(_subIndex(pm25, _bpPm25), _subIndex(pm10, _bpPm10));

// =========================================================
// EVALUASI PER-POLUTAN
// =========================================================
class EvalPolutan {
  final String kategori;
  final Color  warna;
  EvalPolutan(this.kategori, this.warna);
}

EvalPolutan _evalSederhana(double v, List<double> batas) {
  if (v <= batas[0]) return EvalPolutan("Baik",               const Color(0xFF22C55E));
  if (v <= batas[1]) return EvalPolutan("Sedang",             const Color(0xFFEAB308));
  if (v <= batas[2]) return EvalPolutan("Tidak sehat (SG)",   const Color(0xFFF97316));
  if (v <= batas[3]) return EvalPolutan("Tidak sehat",        const Color(0xFFEF4444));
  return                    EvalPolutan("Sangat tidak sehat", const Color(0xFFA855F7));
}

EvalPolutan evalPm25(double v) => _evalSederhana(v, [12, 35.4, 55.4, 150.4]);
EvalPolutan evalPm10(double v) => _evalSederhana(v, [54, 154, 254, 354]);
EvalPolutan evalO3(double v)   => _evalSederhana(v, [54, 70, 85, 105]);
EvalPolutan evalNo2(double v)  => _evalSederhana(v, [53, 100, 360, 649]);
EvalPolutan evalSo2(double v)  => _evalSederhana(v, [35, 75, 185, 304]);
EvalPolutan evalCo(double v)   => _evalSederhana(v, [4.4, 9.4, 12.4, 15.4]);

// =========================================================
// MODEL: 1 BARIS dari tabel monitoring (1 slot jam)
// =========================================================
class CatatanUdara {
  final int      id;
  final String   namaLokasi;
  final double   latitude, longitude;
  final double   pm25, pm10, co, no2, so2, o3;
  final String   status;
  final DateTime waktu;

  CatatanUdara({
    required this.id,
    required this.namaLokasi,
    required this.latitude,
    required this.longitude,
    required this.pm25,
    required this.pm10,
    required this.co,
    required this.no2,
    required this.so2,
    required this.o3,
    required this.status,
    required this.waktu,
  });

  int get aqi => hitungAqi(pm25, pm10);

  // Parser angka yang lebih aman: terima num langsung dari JSON (int/double)
  // maupun string, tanpa memaksa konversi ke-String dulu.
  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory CatatanUdara.fromJson(Map<String, dynamic> j) {
    return CatatanUdara(
      id:         _asInt(j["id"]),
      namaLokasi: (j["nama_lokasi"] ?? "-").toString(),
      latitude:   _asDouble(j["latitude"]),
      longitude:  _asDouble(j["longitude"]),
      pm25:       _asDouble(j["pm25"]),
      pm10:       _asDouble(j["pm10"]),
      co:         _asDouble(j["co"]),
      no2:        _asDouble(j["no2"]),
      so2:        _asDouble(j["so2"]),
      o3:         _asDouble(j["o3"]),
      status:     (j["status"] ?? "-").toString(),
      waktu:      DateTime.tryParse((j["created_at"] ?? "").toString()) ?? DateTime.now(),
    );
  }
}

// =========================================================
// MODEL: RINGKASAN 1 HARI (titik grafik 7 hari)
// =========================================================
class RingkasanHarian {
  final DateTime tanggal;
  final List<CatatanUdara> jamJam;
  RingkasanHarian({required this.tanggal, required this.jamJam});

  int get aqiRataRata {
    if (jamJam.isEmpty) return 0;
    return (jamJam.fold<int>(0, (s, c) => s + c.aqi) / jamJam.length).round();
  }
}

List<RingkasanHarian> kelompokkanPerHari(List<CatatanUdara> data) {
  final Map<String, List<CatatanUdara>> grup = {};
  for (final c in data) {
    final key =
        "${c.waktu.year}-${c.waktu.month.toString().padLeft(2, '0')}-${c.waktu.day.toString().padLeft(2, '0')}";
    grup.putIfAbsent(key, () => []).add(c);
  }
  final hasil = grup.entries.map((e) {
    final jamJam = [...e.value]..sort((a, b) => a.waktu.compareTo(b.waktu));
    final tgl = jamJam.first.waktu;
    return RingkasanHarian(tanggal: DateTime(tgl.year, tgl.month, tgl.day), jamJam: jamJam);
  }).toList();
  hasil.sort((a, b) => a.tanggal.compareTo(b.tanggal));
  return hasil;
}

// =========================================================
// HASIL REFRESH
// =========================================================
class HasilRefresh {
  final bool   status;
  final bool   skipped;
  final String message;
  final List<CatatanUdara> data;
  HasilRefresh({required this.status, required this.skipped, required this.message, required this.data});
}