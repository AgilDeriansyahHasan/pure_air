import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../models/kualitas_udara.dart';
import '../../services/modules/kualitas_udara.dart';
import '../../theme/admin_theme.dart';

// =========================================================
// HALAMAN DASHBOARD
// =========================================================
class KualitasUdaraDashboardPage extends StatefulWidget {
  final String lokasiAwal;
  final String judul;
  const KualitasUdaraDashboardPage({
    super.key,
    this.lokasiAwal = "Pilih Lokasi",
    this.judul      = "Validasi Data Kualitas Udara",
  });

  @override
  State<KualitasUdaraDashboardPage> createState() => _KualitasUdaraDashboardPageState();
}

class _KualitasUdaraDashboardPageState extends State<KualitasUdaraDashboardPage> {
  String              _lokasiAktif  = "";
  List<String>        _daftarLokasi = [];
  List<CatatanUdara>  _histori      = [];

  // Data grafik (7 hari) dihitung SEKALI setiap kali _histori berubah,
  // bukan setiap kali widget di-rebuild. Sebelumnya kelompokkanPerHari()
  // dipanggil di dalam build() sehingga ikut jalan tiap drag di grafik.
  List<RingkasanHarian> _tujuhHari = [];

  bool                _loading      = true;

  // Tombol "refresh data terkini" (action=refresh)
  bool               _mengambilHistori       = false;
  // Tombol "ambil histori 7 hari" (action=ambil_historis)
  bool               _mengambilHistoriManual = false;
  // Tombol "Export" (kirim ke laporan)
  bool               _mengekspor             = false;

  String?            _error;
  int?               _hariDipilih;
  bool               _cardJamTerbuka   = false;
  int?               _jamDetailTerbuka;

  @override
  void initState() {
    super.initState();
    _lokasiAktif = widget.lokasiAwal;
    _muatDaftarLokasi();
    _muatData();
  }

  String _pesanError(Object e) => e.toString().replaceFirst("Exception: ", "");

  /// Terapkan data baru ke state: simpan histori mentah, kelompokkan per
  /// hari di sini saja, lalu ambil 7 hari terakhir untuk grafik & reset
  /// pilihan hari/jam yang sedang terbuka.
  void _terapkanHistori(List<CatatanUdara> data) {
    final semuaHari = kelompokkanPerHari(data);
    setState(() {
      _histori          = data;
      _tujuhHari        = semuaHari.length > 7
          ? semuaHari.sublist(semuaHari.length - 7)
          : semuaHari;
      _hariDipilih      = null;
      _cardJamTerbuka   = false;
      _jamDetailTerbuka = null;
    });
  }

  Future<void> _muatDaftarLokasi() async {
    try {
      final daftar = await KualitasUdaraHistoryService.getDaftarLokasi();
      if (!mounted) return;
      setState(() => _daftarLokasi = daftar);
    } catch (_) {
      // Daftar lokasi gagal dimuat bukan error fatal untuk halaman ini,
      // dropdown lokasi cukup jatuh balik ke [_lokasiAktif] saja.
    }
  }

  /// Load data dari DB. Kalau kosong & lokasi sudah dipilih,
  /// otomatis fetch 7 hari historis dari OpenWeather.
  Future<void> _muatData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final hasil = await KualitasUdaraHistoryService.getByLokasi(_lokasiAktif);
      if (!mounted) return;

      if (hasil.isEmpty && _lokasiAktif != "Pilih Lokasi") {
        // Data kosong → otomatis ambil historis dari OpenWeather
        await _ambilHistoriOtomatis();
        return; // _ambilHistoriOtomatis sudah atur histori & _loading
      }

      _terapkanHistori(hasil);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _pesanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Dipanggil otomatis oleh _muatData() saat data DB kosong.
  /// Fetch 7 hari historis dari OpenWeather lewat action=ambil_historis.
  Future<void> _ambilHistoriOtomatis() async {
    try {
      final hasil = await KualitasUdaraHistoryService.ambilHistoris(_lokasiAktif);
      if (!mounted) return;
      _terapkanHistori(hasil);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _pesanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Guard bersama untuk tombol-tombol yang butuh lokasi terpilih.
  bool _pastikanLokasiDipilih() {
    if (_lokasiAktif == "Pilih Lokasi") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih lokasi terlebih dahulu")),
      );
      return false;
    }
    return true;
  }

  /// Tombol "refresh" (ikon download) di area grafik: fetch data TERKINI
  /// dari OpenWeather (current) lewat action=refresh, simpan ke slot jam
  /// terdekat. TIDAK menarik histori 7 hari -- cuma 1 titik data baru.
  Future<void> _ambilDataHistori() async {
    if (!_pastikanLokasiDipilih() || _mengambilHistori) return;

    setState(() => _mengambilHistori = true);
    try {
      final hasil = await KualitasUdaraHistoryService.refreshLokasi(_lokasiAktif);
      if (!mounted) return;
      _terapkanHistori(hasil.data);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(hasil.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_pesanError(e))));
    } finally {
      if (mounted) setState(() => _mengambilHistori = false);
    }
  }

  /// Tombol BARU "ambil histori" (ikon jam mundur) di area grafik:
  /// fetch HISTORI 7 HARI dari OpenWeather Historical API lewat
  /// action=ambil_historis. Bisa dipencet kapan saja sebagai
  /// retry/refresh manual, terlepas dari auto-fetch saat lokasi baru
  /// pertama kali dibuat di validasi.php.
  Future<void> _ambilHistoriManual() async {
    if (!_pastikanLokasiDipilih() || _mengambilHistoriManual) return;

    setState(() => _mengambilHistoriManual = true);
    try {
      final hasil = await KualitasUdaraHistoryService.ambilHistoris(_lokasiAktif);
      if (!mounted) return;
      _terapkanHistori(hasil);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Histori 7 hari berhasil diperbarui")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_pesanError(e))));
    } finally {
      if (mounted) setState(() => _mengambilHistoriManual = false);
    }
  }

  /// Tombol "Export" -> kirim kategori "kualitas_udara" ke laporan,
  /// khusus untuk lokasi yang sedang aktif di dashboard ini.
  Future<void> _kirimKeLaporan() async {
    if (!_pastikanLokasiDipilih() || _mengekspor) return;

    setState(() => _mengekspor = true);
    try {
      final data = await KualitasUdaraHistoryService.kirimKeLaporan(_lokasiAktif);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['status'] == "success"
                ? "Data kualitas udara ($_lokasiAktif) dikirim ke laporan"
                : (data['message'] ?? "Gagal mengirim ke laporan"),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${_pesanError(e)}")),
      );
    } finally {
      if (mounted) setState(() => _mengekspor = false);
    }
  }

  void _pilihLokasi() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AdminTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final daftar = _daftarLokasi.isNotEmpty ? _daftarLokasi : [_lokasiAktif];
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: daftar.map((nama) => ListTile(
            leading: Icon(Icons.location_on_outlined,
                color: nama == _lokasiAktif ? AdminTheme.aksen : AdminTheme.teksAbu),
            title: Text(nama, style: const TextStyle(color: AdminTheme.teksUtama)),
            trailing: nama == _lokasiAktif
                ? const Icon(Icons.check_circle_rounded, color: AdminTheme.aksen)
                : null,
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _lokasiAktif = nama);
              _muatData();
            },
          )).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                color: AdminTheme.aksen,
                onRefresh: _muatData,
                child: _loading
                    ? const Center(
                  child: CircularProgressIndicator(color: AdminTheme.aksen),
                )
                    : _error != null
                    ? _buildError()
                    : _buildKonten(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return ListView(children: [
      Padding(
        padding: const EdgeInsets.only(top: 120, left: 24, right: 24),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminTheme.aksen.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off_rounded, size: 32, color: AdminTheme.aksen),
          ),
          const SizedBox(height: 14),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: AdminTheme.teksAbu, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _muatData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.aksen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Coba lagi"),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildKonten() {
    if (_lokasiAktif == "Pilih Lokasi" || _histori.isEmpty) {
      return ListView(padding: const EdgeInsets.all(14), children: [
        _buildLokasiBar(),
        const SizedBox(height: 60),
        Center(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AdminTheme.aksen.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _lokasiAktif == "Pilih Lokasi" ? Icons.location_searching_rounded : Icons.inbox_rounded,
                size: 30,
                color: AdminTheme.aksen,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _lokasiAktif == "Pilih Lokasi"
                  ? "Pilih lokasi terlebih dahulu"
                  : "Belum ada data untuk lokasi ini",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AdminTheme.teksAbu, fontSize: 13),
            ),
          ]),
        ),
      ]);
    }

    // _tujuhHari sudah dihitung sekali di _terapkanHistori(), tidak perlu
    // dikelompokkan ulang di sini setiap build.
    final tujuhHari = _tujuhHari;
    if (tujuhHari.isEmpty) return const SizedBox.shrink();

    final aqiList   = tujuhHari.map((h) => h.aqiRataRata).toList();
    final tertinggi = aqiList.reduce(math.max);
    final terendah  = aqiList.reduce(math.min);
    final rataRata  = (aqiList.reduce((a, b) => a + b) / aqiList.length).round();

    final int indexAktif = (_hariDipilih != null && _hariDipilih! < tujuhHari.length)
        ? _hariDipilih!
        : tujuhHari.length - 1;
    final hariAktif    = tujuhHari[indexAktif];
    final kategoriAktif = kategoriDariAqi(hariAktif.aqiRataRata);

    return ListView(padding: const EdgeInsets.all(14), children: [
      _buildLokasiBar(),
      const SizedBox(height: 6),
      Text(_formatTanggalLengkap(hariAktif.tanggal),
          style: const TextStyle(fontSize: 12, color: AdminTheme.teksAbu)),
      const SizedBox(height: 14),

      // ===== GAUGE AQI =====
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AdminTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdminTheme.cardBorder),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(.04),
            ),
          ],
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
            Text("Indeks kualitas udara (rata-rata harian)",
                style: TextStyle(fontSize: 13, color: AdminTheme.teksAbu)),
            SizedBox(width: 4),
            Icon(Icons.info_outline, size: 13, color: AdminTheme.teksAbu),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 110,
            child: CustomPaint(
              painter: _GaugePainter(aqi: hariAktif.aqiRataRata),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(children: [
                    Text("${hariAktif.aqiRataRata}",
                        style: TextStyle(fontSize: 38,
                            fontWeight: FontWeight.w700, color: kategoriAktif.warna)),
                    Text(kategoriAktif.label,
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600, color: kategoriAktif.warna)),
                  ]),
                ),
              ),
            ),
          ),
          if (hariAktif.aqiRataRata > 100) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEA580C)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  "Kelompok sensitif: anak-anak, lansia, dan penderita penyakit "
                      "pernapasan disarankan tetap di dalam ruangan.",
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF9A3412)),
                )),
              ]),
            ),
          ] else if (hariAktif.aqiRataRata > 50) ...[
            const SizedBox(height: 6),
            const Text(
              "Tidak sehat bagi kelompok sensitif. Hindari aktivitas luar ruangan terlalu lama.",
              style: TextStyle(fontSize: 11.5, color: AdminTheme.teksAbu),
              textAlign: TextAlign.center,
            ),
          ],
        ]),
      ),
      const SizedBox(height: 12),

      // ===== STAT BOXES =====
      Row(children: [
        Expanded(child: _statBox("Tertinggi", "$tertinggi", const Color(0xFFEF4444))),
        const SizedBox(width: 8),
        Expanded(child: _statBox("Terendah",  "$terendah", const Color(0xFF22C55E))),
        const SizedBox(width: 8),
        Expanded(child: _statBox("Rata-rata", "$rataRata", AdminTheme.aksen)),
      ]),
      const SizedBox(height: 12),

      // ===== TOMBOL EXPORT (kirim ke laporan) =====
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _mengekspor ? null : _kirimKeLaporan,
          icon: _mengekspor
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : const Icon(Icons.ios_share, size: 16),
          label: Text(
            _mengekspor ? "Mengirim..." : "Export ke Laporan",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F2937),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),

      // ===== GRAFIK 7 HARI =====
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Grafik AQI (7 hari terakhir)",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AdminTheme.teksUtama)),
        Row(children: [
          const Text("Ketuk untuk detail", style: TextStyle(fontSize: 11, color: AdminTheme.teksAbu)),
          const SizedBox(width: 8),

          // TOMBOL BARU: ambil histori 7 hari dari OpenWeather Historical
          // (action=ambil_historis). Bisa dipakai sebagai retry manual
          // kapan saja, terlepas dari auto-fetch saat lokasi baru dibuat.
          Tooltip(
            message: "Ambil histori 7 hari dari OpenWeather",
            child: InkWell(
              onTap: _mengambilHistoriManual ? null : _ambilHistoriManual,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 28, height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminTheme.aksen.withOpacity(.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminTheme.aksen.withOpacity(.2)),
                ),
                child: _mengambilHistoriManual
                    ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AdminTheme.aksen),
                    ),
                  ),
                )
                    : const Icon(Icons.history, size: 16, color: AdminTheme.aksen),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Tombol lama: refresh data TERKINI (action=refresh)
          Tooltip(
            message: "Ambil data terkini",
            child: InkWell(
              onTap: _mengambilHistori ? null : _ambilDataHistori,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 28, height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminTheme.aksen.withOpacity(.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminTheme.aksen.withOpacity(.2)),
                ),
                child: _mengambilHistori
                    ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AdminTheme.aksen),
                    ),
                  ),
                )
                    : const Icon(Icons.download_rounded, size: 16, color: AdminTheme.aksen),
              ),
            ),
          ),
        ]),
      ]),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 14, 14, 8),
        decoration: BoxDecoration(
          color: AdminTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdminTheme.cardBorder),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(.04),
            ),
          ],
        ),
        child: SizedBox(
          height: 170,
          child: LayoutBuilder(builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _pilihHariTerdekat(d.localPosition, size, tujuhHari.length),
              onPanUpdate: (d) => _pilihHariTerdekat(d.localPosition, size, tujuhHari.length),
              child: CustomPaint(
                painter: _LineChartPainter(tujuhHari, indexAktif: indexAktif),
                child: Container(),
              ),
            );
          }),
        ),
      ),
      const SizedBox(height: 14),

      // ===== BREAKDOWN PER-JAM (accordion) =====
      _buildCardBreakdownJam(hariAktif, tujuhHari.length),
      const SizedBox(height: 18),

      // ===== INFO LOKASI =====
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AdminTheme.cardBorder),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(.04),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Informasi lokasi",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminTheme.teksUtama)),
          const SizedBox(height: 10),
          _baris("Koordinat",
              "${hariAktif.jamJam.last.latitude.toStringAsFixed(5)}, ${hariAktif.jamJam.last.longitude.toStringAsFixed(4)}"),
          _baris("Sumber data",     "OpenWeatherMap"),
          _baris("Update terakhir", _formatJam(_histori.last.waktu)),
        ]),
      ),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildCardBreakdownJam(RingkasanHarian hari, int totalHari) {
    final kategori = kategoriDariAqi(hari.aqiRataRata);

    // Cari jam yang lagi dipilih; kalau id-nya nggak ada di hari ini
    // (misalnya baru pindah tanggal), fallback ke jam terakhir.
    final jamTerpilih = hari.jamJam.firstWhere(
          (c) => c.id == _jamDetailTerbuka,
      orElse: () => hari.jamJam.last,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AdminTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminTheme.aksen.withOpacity(.3)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 6),
            color: AdminTheme.aksen.withOpacity(.08),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // HEADER: ikon kalender + judul + badge total hari
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AdminTheme.aksen.withOpacity(.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.calendar_today_rounded, size: 14, color: AdminTheme.aksen),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text("Detail per hari",
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AdminTheme.teksUtama)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AdminTheme.aksen.withOpacity(.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("$totalHari hari",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminTheme.aksen)),
            ),
          ]),
        ),

        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Divider(height: 1, color: AdminTheme.cardBorder),
        ),
        const SizedBox(height: 10),

        // SUBHEADER: tanggal + status + AQI + tombol buka/tutup
        InkWell(
          onTap: () => setState(() => _cardJamTerbuka = !_cardJamTerbuka),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Text(_formatTanggalSingkat(hari.tanggal),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AdminTheme.teksUtama)),
              const SizedBox(width: 10),
              Container(width: 7, height: 7,
                  decoration: BoxDecoration(color: kategori.warna, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(kategori.label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kategori.warna)),
              const Spacer(),
              Text("AQI ${hari.aqiRataRata}",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminTheme.teksUtama)),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _cardJamTerbuka ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: AdminTheme.teksAbu),
              ),
            ]),
          ),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _cardJamTerbuka
              ? Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // GRID JAM: setiap slot menampilkan jam + AQI-nya, disusun
              // rapi memenuhi lebar card (bukan scroll horizontal lagi)
              // supaya semua jam kelihatan sekaligus.
              LayoutBuilder(builder: (context, constraints) {
                const spacing  = 8.0;
                const minWidth = 66.0;
                final kolom = (constraints.maxWidth / (minWidth + spacing))
                    .floor()
                    .clamp(1, hari.jamJam.length);
                final lebarItem =
                    (constraints.maxWidth - spacing * (kolom - 1)) / kolom;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: hari.jamJam.map((c) {
                    final terpilih = c.id == jamTerpilih.id;
                    final kategoriJam = kategoriDariAqi(c.aqi);
                    return SizedBox(
                      width: lebarItem,
                      child: InkWell(
                        onTap: () => setState(() => _jamDetailTerbuka = c.id),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: terpilih ? AdminTheme.aksen : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                              _formatJam(c.waktu),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: terpilih ? FontWeight.w700 : FontWeight.w600,
                                color: terpilih ? Colors.white : AdminTheme.teksUtama,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 5, height: 5,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: terpilih ? Colors.white : kategoriJam.warna,
                                ),
                              ),
                              Text(
                                "AQI ${c.aqi}",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: terpilih ? Colors.white70 : AdminTheme.teksAbu,
                                ),
                              ),
                            ]),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 12),

              // GRID POLUTAN UNTUK JAM YANG DIPILIH
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.95,
                children: [
                  _kartuPolutanKecil("PM2.5", jamTerpilih.pm25.toStringAsFixed(1), evalPm25(jamTerpilih.pm25)),
                  _kartuPolutanKecil("PM10",  jamTerpilih.pm10.toStringAsFixed(1), evalPm10(jamTerpilih.pm10)),
                  _kartuPolutanKecil("CO",    jamTerpilih.co.toStringAsFixed(1),   evalCo(jamTerpilih.co)),
                  _kartuPolutanKecil("NO2",   jamTerpilih.no2.toStringAsFixed(1),  evalNo2(jamTerpilih.no2)),
                  _kartuPolutanKecil("SO2",   jamTerpilih.so2.toStringAsFixed(1),  evalSo2(jamTerpilih.so2)),
                  _kartuPolutanKecil("O3",    jamTerpilih.o3.toStringAsFixed(1),   evalO3(jamTerpilih.o3)),
                ],
              ),
            ]),
          )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ]),
    );
  }

  void _pilihHariTerdekat(Offset pos, Size size, int jumlah) {
    if (jumlah <= 0) return;
    final stepX = jumlah > 1 ? size.width / (jumlah - 1) : size.width;
    final index = (pos.dx / stepX).round().clamp(0, jumlah - 1);
    if (_hariDipilih != index) {
      setState(() { _hariDipilih = index; _jamDetailTerbuka = null; });
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(children: [
        InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36, height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                  color: Colors.black.withOpacity(.05),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 18, color: AdminTheme.teksUtama),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(widget.judul,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AdminTheme.teksUtama),
            overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _buildLokasiBar() {
    return Row(children: [
      Expanded(child: InkWell(
        onTap: _pilihLokasi,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AdminTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 3),
                color: Colors.black.withOpacity(.03),
              ),
            ],
          ),
          child: Row(children: [
            const Icon(Icons.location_on_rounded, size: 16, color: AdminTheme.aksen),
            const SizedBox(width: 8),
            Text(_lokasiAktif,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AdminTheme.teksUtama)),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: AdminTheme.teksAbu),
          ]),
        ),
      )),
      const SizedBox(width: 8),
      // Refresh: cuma reload dari DB (tidak hit OpenWeather)
      InkWell(
        onTap: _muatData,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AdminTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 3),
                color: Colors.black.withOpacity(.03),
              ),
            ],
          ),
          child: const Icon(Icons.refresh_rounded, size: 18, color: AdminTheme.teksUtama),
        ),
      ),
    ]);
  }

  Widget _statBox(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AdminTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 4),
            color: accent.withOpacity(.06),
          ),
        ],
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: accent)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.teksAbu)),
      ]),
    );
  }

  Widget _kartuPolutanKecil(String label, String nilai, EvalPolutan info) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.teksAbu, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(nilai, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AdminTheme.teksUtama)),
          const SizedBox(height: 6),
          Container(width: 6, height: 6,
              decoration: BoxDecoration(color: info.warna, shape: BoxShape.circle)),
        ],
      ),
    );
  }

  Widget _baris(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.teksAbu))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AdminTheme.teksUtama)),
      ]),
    );
  }

  String _formatTanggalLengkap(DateTime t) {
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    return "${t.day} ${b[t.month - 1]} ${t.year}";
  }

  String _formatTanggalSingkat(DateTime t) {
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];
    return "${t.day} ${b[t.month - 1]}";
  }

  String _formatJam(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
}

// =========================================================
// GAUGE
// =========================================================
class _GaugePainter extends CustomPainter {
  final int aqi;
  _GaugePainter({required this.aqi});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 4);
    final radius = math.min(size.width / 2, size.height) - 10;
    const sw = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, math.pi, math.pi, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = sw
          ..strokeCap = StrokeCap.round..color = const Color(0xFFEDEEF2));

    final progress = (aqi / 200).clamp(0.0, 1.0);
    canvas.drawArc(rect, math.pi, math.pi * progress, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = sw
          ..strokeCap = StrokeCap.round
          ..shader = const SweepGradient(
            startAngle: math.pi, endAngle: 2 * math.pi,
            colors: [Color(0xFF22C55E),Color(0xFFEAB308),Color(0xFFF97316),Color(0xFFEF4444),Color(0xFF7F1D1D)],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ).createShader(rect));

    final sudut = math.pi + (math.pi * progress);
    canvas.drawCircle(
        Offset(center.dx + radius * math.cos(sudut), center.dy + radius * math.sin(sudut)),
        6,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset(center.dx + radius * math.cos(sudut), center.dy + radius * math.sin(sudut)),
        6,
        Paint()..color = Colors.black.withOpacity(.15)..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.aqi != aqi;
}

// =========================================================
// GRAFIK GARIS 7 HARI
// =========================================================
class _LineChartPainter extends CustomPainter {
  final List<RingkasanHarian> data;
  final int? indexAktif;
  _LineChartPainter(this.data, {this.indexAktif});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final nilai  = data.map((e) => e.aqiRataRata.toDouble()).toList();
    final maxV   = nilai.reduce(math.max);
    final minV   = nilai.reduce(math.min);
    final range  = (maxV - minV).clamp(1, double.infinity);

    const paddingBottom = 22.0;
    final chartH = size.height - paddingBottom;
    final stepX  = data.length > 1 ? size.width / (data.length - 1) : size.width;

    final linePaint = Paint()..color = AdminTheme.aksen..strokeWidth = 2.4..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [AdminTheme.aksen.withOpacity(0.18), AdminTheme.aksen.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartH));
    final dotPaint = Paint()..color = AdminTheme.aksen;

    final path = Path(), fillPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = chartH - ((nilai[i] - minV) / range * chartH);
      points.add(Offset(x, y));
      if (i == 0) { path.moveTo(x, y); fillPath.moveTo(x, chartH); fillPath.lineTo(x, y); }
      else { path.lineTo(x, y); fillPath.lineTo(x, y); }
    }
    fillPath.lineTo(points.last.dx, chartH);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    if (indexAktif != null && indexAktif! < points.length) {
      final p = points[indexAktif!];
      final dashP = Paint()..color = AdminTheme.aksen.withOpacity(0.35)..strokeWidth = 1;
      double y = 0;
      while (y < chartH) {
        canvas.drawLine(Offset(p.dx, y), Offset(p.dx, math.min(y + 4, chartH)), dashP);
        y += 7;
      }
      canvas.drawCircle(p, 7, Paint()..color = AdminTheme.aksen.withOpacity(0.2));
      canvas.drawCircle(p, 5, Paint()..color = AdminTheme.aksen);
      canvas.drawCircle(p, 5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

    const styleN = TextStyle(color: AdminTheme.teksAbu, fontSize: 10);
    const styleA = TextStyle(color: AdminTheme.teksUtama, fontSize: 10, fontWeight: FontWeight.w700);
    const b = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"];

    for (int i = 0; i < points.length; i++) {
      final aktif = i == indexAktif;
      if (!aktif) canvas.drawCircle(points[i], 3, dotPaint);
      final tp = TextPainter(
        text: TextSpan(text: "${data[i].tanggal.day} ${b[data[i].tanggal.month - 1]}", style: aktif ? styleA : styleN),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.data != data || old.indexAktif != indexAktif;
}