import 'package:flutter/material.dart';
import '../../services/session.dart';

// =========================================================
// WARNA TEMA -- selaras dengan halaman lain PureAir
// =========================================================
class _Tema {
  static const bg         = Color(0xFFF5F5F5);
  static const card       = Colors.white;
  static const cardBorder = Color(0xFFE0E0E0);
  static const teksAbu    = Color(0xFF8A8A8E);
  static const teksHitam  = Color(0xFF1C1C1E);
  static const aksen      = Color(0xFF2F80ED);
}

// =========================================================
// MODEL: data edukasi 1 polutan
// =========================================================
class _PolutanEdukasi {
  final String label;
  final String namaLengkap;
  final IconData icon;
  final Color warna;
  final String deskripsi;
  final List<String> sumber;
  final List<String> dampakKesehatan;

  const _PolutanEdukasi({
    required this.label,
    required this.namaLengkap,
    required this.icon,
    required this.warna,
    required this.deskripsi,
    required this.sumber,
    required this.dampakKesehatan,
  });
}

const List<_PolutanEdukasi> _daftarPolutan = [
  _PolutanEdukasi(
    label: "PM2.5",
    namaLengkap: "Partikulat Halus (PM2.5)",
    icon: Icons.blur_on,
    warna: Color(0xFFFF3B30),
    deskripsi:
    "Partikel udara berukuran sangat halus, kurang dari 2,5 mikrometer, sehingga bisa masuk jauh ke dalam paru-paru bahkan tembus ke aliran darah. Karena ukurannya, PM2.5 termasuk polutan yang paling berbahaya bagi kesehatan.",
    sumber: [
      "Asap kendaraan bermotor",
      "Pembakaran biomassa dan sampah",
      "Emisi cerobong industri",
      "Asap rokok",
    ],
    dampakKesehatan: [
      "Infeksi saluran pernapasan akut (ISPA)",
      "Memperburuk gejala asma",
      "Meningkatkan risiko penyakit jantung koroner dan stroke",
      "Berpotensi meningkatkan risiko kanker paru-paru",
      "Mengganggu perkembangan paru-paru pada anak",
    ],
  ),
  _PolutanEdukasi(
    label: "PM10",
    namaLengkap: "Partikulat Kasar (PM10)",
    icon: Icons.grain,
    warna: Color(0xFFFF9500),
    deskripsi:
    "Partikel udara berukuran lebih besar dari PM2.5, kurang dari 10 mikrometer. Umumnya tersaring di saluran napas bagian atas, tetapi tetap dapat mengiritasi dan memicu gangguan pernapasan.",
    sumber: [
      "Debu jalan raya",
      "Aktivitas konstruksi dan bongkar-muat",
      "Kegiatan pertanian",
      "Angin yang membawa debu tanah",
    ],
    dampakKesehatan: [
      "Iritasi hidung dan tenggorokan",
      "Batuk dan sesak ringan",
      "Memperburuk asma dan bronkitis",
    ],
  ),
  _PolutanEdukasi(
    label: "CO",
    namaLengkap: "Karbon Monoksida (CO)",
    icon: Icons.local_fire_department,
    warna: Color(0xFF8B0000),
    deskripsi:
    "Gas tidak berwarna dan tidak berbau, dihasilkan dari pembakaran bahan bakar yang tidak sempurna. CO berbahaya karena mengikat hemoglobin darah lebih kuat dibanding oksigen.",
    sumber: [
      "Knalpot kendaraan bermotor",
      "Kompor dan pemanas berbahan bakar gas/minyak",
      "Pembakaran arang di ruang tertutup",
    ],
    dampakKesehatan: [
      "Sakit kepala dan pusing",
      "Menurunkan kadar oksigen dalam darah",
      "Memperberat kerja jantung",
      "Kadar tinggi di ruang tertutup bisa berakibat fatal",
    ],
  ),
  _PolutanEdukasi(
    label: "NO2",
    namaLengkap: "Nitrogen Dioksida (NO₂)",
    icon: Icons.directions_car_filled,
    warna: Color(0xFFAF52DE),
    deskripsi:
    "Gas berwarna coklat kemerahan yang terbentuk dari pembakaran bahan bakar fosil pada suhu tinggi. NO₂ juga berperan dalam pembentukan ozon permukaan dan hujan asam.",
    sumber: [
      "Emisi kendaraan bermotor",
      "Pembangkit listrik tenaga fosil",
      "Kompor gas di dalam rumah",
    ],
    dampakKesehatan: [
      "Iritasi saluran pernapasan",
      "Memperburuk gejala asma",
      "Meningkatkan risiko infeksi paru, terutama pada anak-anak",
    ],
  ),
  _PolutanEdukasi(
    label: "SO2",
    namaLengkap: "Sulfur Dioksida (SO₂)",
    icon: Icons.factory,
    warna: Color(0xFFFFC107),
    deskripsi:
    "Gas berbau tajam yang dihasilkan dari pembakaran bahan bakar yang mengandung sulfur, seperti batu bara dan minyak bumi. Merupakan salah satu penyebab utama hujan asam.",
    sumber: [
      "Pembangkit listrik tenaga batu bara",
      "Aktivitas industri dan peleburan logam",
      "Kapal berbahan bakar bunker",
    ],
    dampakKesehatan: [
      "Iritasi mata dan tenggorokan",
      "Memperburuk penyakit pernapasan seperti bronkitis",
      "Berkontribusi pada hujan asam yang merusak lingkungan",
    ],
  ),
  _PolutanEdukasi(
    label: "O3",
    namaLengkap: "Ozon Permukaan (O₃)",
    icon: Icons.wb_sunny,
    warna: Color(0xFF34C759),
    deskripsi:
    "Berbeda dari lapisan ozon pelindung di stratosfer, ozon permukaan terbentuk dari reaksi kimia antara NOx dan senyawa organik volatil di bawah sinar matahari, dan bersifat merugikan kesehatan.",
    sumber: [
      "Reaksi sekunder dari emisi kendaraan",
      "Emisi industri di siang hari bersuhu tinggi",
      "Uap bahan bakar dan pelarut kimia",
    ],
    dampakKesehatan: [
      "Iritasi paru-paru dan sesak napas",
      "Memperburuk asma",
      "Menurunkan fungsi paru saat beraktivitas berat di luar ruangan",
    ],
  ),
];

// =========================================================
// MODEL: kategori AQI untuk edukasi
// =========================================================
class _KategoriAqiInfo {
  final String range;
  final String label;
  final Color warna;
  final String saran;
  const _KategoriAqiInfo(this.range, this.label, this.warna, this.saran);
}

const List<_KategoriAqiInfo> _kategoriAqiList = [
  _KategoriAqiInfo("0 – 50", "Baik", Color(0xFF34C759),
      "Kualitas udara memuaskan, aktivitas luar ruangan aman untuk semua orang."),
  _KategoriAqiInfo("51 – 100", "Sedang", Color(0xFFFFC107),
      "Kelompok yang sangat sensitif sebaiknya mengurangi aktivitas berat di luar ruangan."),
  _KategoriAqiInfo("101 – 150", "Tidak Sehat (Kelompok Sensitif)",
      Color(0xFFFF9500),
      "Anak-anak, lansia, dan penderita asma/jantung disarankan mengurangi aktivitas luar ruangan."),
  _KategoriAqiInfo("151 – 200", "Tidak Sehat", Color(0xFFFF3B30),
      "Semua orang mulai dapat merasakan dampak kesehatan; kurangi aktivitas luar ruangan."),
  _KategoriAqiInfo("201 – 300", "Sangat Tidak Sehat", Color(0xFFAF52DE),
      "Peringatan kesehatan darurat, seluruh populasi berisiko terdampak."),
  _KategoriAqiInfo("300+", "Berbahaya", Color(0xFF8B0000),
      "Kondisi darurat kesehatan, hindari semua aktivitas di luar ruangan."),
];

// =========================================================
// MODEL: tips sehat
// =========================================================
class _TipsSehat {
  final IconData icon;
  final String judul;
  final String deskripsi;
  const _TipsSehat(this.icon, this.judul, this.deskripsi);
}

const List<_TipsSehat> _daftarTips = [
  _TipsSehat(Icons.masks_outlined, "Gunakan masker",
      "Gunakan masker N95 atau KN95 saat kualitas udara buruk, terutama di luar ruangan."),
  _TipsSehat(Icons.home_outlined, "Tetap di dalam ruangan",
      "Tutup jendela dan pintu saat AQI tinggi. Gunakan penyaring udara (air purifier) jika tersedia."),
  _TipsSehat(Icons.directions_run_outlined, "Hindari aktivitas berat di luar",
      "Tunda olahraga di luar ruangan ketika AQI di atas 100, terutama bagi kelompok sensitif."),
  _TipsSehat(Icons.water_drop_outlined, "Perbanyak minum air putih",
      "Hidrasi yang cukup membantu tubuh membuang racun dan menjaga kesehatan saluran napas."),
  _TipsSehat(Icons.local_hospital_outlined, "Perhatikan gejala",
      "Segera konsultasi ke dokter jika mengalami sesak napas, batuk berkepanjangan, atau iritasi mata."),
  _TipsSehat(Icons.eco_outlined, "Tanam tanaman penyaring udara",
      "Beberapa tanaman seperti lidah mertua dan peace lily dapat membantu menyaring polutan dalam ruangan."),
];

// =========================================================
// MODEL: artikel edukasi
// =========================================================
class _ArtikelEdukasi {
  final String kategori;
  final String judul;
  final String ringkasan;
  final String isi;
  final IconData icon;
  const _ArtikelEdukasi({
    required this.kategori,
    required this.judul,
    required this.ringkasan,
    required this.isi,
    required this.icon,
  });
}

const List<_ArtikelEdukasi> _daftarArtikel = [
  _ArtikelEdukasi(
    kategori: "Lingkungan",
    icon: Icons.location_city,
    judul: "Mengapa Kualitas Udara di Kota Besar Sering Memburuk?",
    ringkasan:
    "Kepadatan kendaraan, aktivitas industri, dan kondisi cuaca sama-sama berperan dalam menurunkan kualitas udara kota.",
    isi:
    "Kualitas udara di kota-kota besar cenderung memburuk karena kombinasi beberapa faktor: tingginya volume kendaraan bermotor, aktivitas industri dan konstruksi, serta kepadatan penduduk yang meningkatkan konsumsi energi. "
        "Faktor cuaca juga berperan penting — pada musim kemarau atau saat terjadi inversi suhu, polutan cenderung terperangkap di dekat permukaan tanah sehingga konsentrasinya meningkat. "
        "Topografi kota yang dikelilingi perbukitan juga dapat menghambat sirkulasi udara, membuat polutan lebih lama bertahan di atmosfer sekitar kota. "
        "Memahami pola ini membantu kita mengantisipasi hari-hari dengan risiko polusi tinggi dan mengambil langkah pencegahan yang tepat.",
  ),
  _ArtikelEdukasi(
    kategori: "Kesehatan",
    icon: Icons.child_care,
    judul: "Polusi Udara dan Kesehatan Anak: Yang Perlu Diketahui Orang Tua",
    ringkasan:
    "Anak-anak lebih rentan terhadap polusi udara karena paru-paru mereka masih berkembang dan laju napas lebih cepat.",
    isi:
    "Anak-anak menghirup udara lebih banyak per kilogram berat badan dibanding orang dewasa, dan sistem pernapasan mereka masih dalam tahap perkembangan. Hal ini membuat mereka lebih rentan terhadap dampak polusi udara, mulai dari batuk, infeksi saluran pernapasan, hingga risiko berkembangnya asma di kemudian hari. "
        "Paparan polusi dalam jangka panjang pada masa kanak-kanak juga dikaitkan dengan gangguan pertumbuhan fungsi paru-paru. "
        "Orang tua disarankan untuk memantau indeks kualitas udara sebelum mengajak anak beraktivitas di luar ruangan, membatasi aktivitas fisik berat saat AQI tinggi, serta memastikan ventilasi rumah tetap baik namun terkendali saat udara luar sedang buruk.",
  ),
  _ArtikelEdukasi(
    kategori: "Tips",
    icon: Icons.masks_outlined,
    judul: "Masker Apa yang Efektif Menyaring Polutan?",
    ringkasan:
    "Tidak semua masker sama efektifnya dalam menyaring partikel halus seperti PM2.5.",
    isi:
    "Masker kain biasa umumnya kurang efektif menyaring partikel halus seperti PM2.5 karena pori-porinya relatif besar. Masker dengan standar filtrasi seperti N95 atau KN95 dirancang untuk menyaring setidaknya 95% partikel kecil, termasuk PM2.5, sehingga lebih direkomendasikan saat kualitas udara memburuk. "
        "Agar efektif, masker perlu menutup rapat area hidung dan dagu tanpa celah. Masker sebaiknya diganti secara berkala, terutama jika sudah lembap atau kotor, karena efektivitas filtrasi menurun seiring pemakaian. "
        "Bagi kelompok rentan seperti lansia, ibu hamil, dan penderita gangguan pernapasan, penggunaan masker saat AQI tinggi sangat dianjurkan.",
  ),
  _ArtikelEdukasi(
    kategori: "Lingkungan",
    icon: Icons.eco,
    judul: "Hubungan Polusi Udara dengan Perubahan Iklim",
    ringkasan:
    "Sebagian besar sumber polusi udara juga merupakan sumber utama gas rumah kaca.",
    isi:
    "Polusi udara dan perubahan iklim memiliki keterkaitan yang erat karena berasal dari sumber yang sama, yaitu pembakaran bahan bakar fosil. Aktivitas seperti transportasi, pembangkit listrik, dan industri tidak hanya melepaskan polutan berbahaya seperti PM2.5 dan NO₂, tetapi juga gas rumah kaca seperti karbon dioksida. "
        "Beberapa polutan, seperti ozon permukaan dan partikel hitam (black carbon), bahkan turut berkontribusi langsung terhadap pemanasan global. "
        "Karena itu, upaya menekan emisi kendaraan dan industri tidak hanya memperbaiki kualitas udara jangka pendek, tetapi juga berkontribusi pada mitigasi perubahan iklim dalam jangka panjang.",
  ),
  _ArtikelEdukasi(
    kategori: "Kesehatan",
    icon: Icons.home_outlined,
    judul: "Indoor Air Quality: Udara di Rumah Juga Bisa Tercemar",
    ringkasan:
    "Sumber polusi tidak hanya dari luar rumah — aktivitas memasak dan produk rumah tangga juga berkontribusi.",
    isi:
    "Banyak orang berasumsi bahwa berada di dalam rumah selalu lebih aman dari polusi udara, padahal kualitas udara dalam ruangan juga bisa tercemar. Aktivitas memasak menggunakan kompor gas, asap rokok, penggunaan produk pembersih tertentu, hingga jamur akibat kelembapan berlebih dapat menurunkan kualitas udara dalam rumah. "
        "Ventilasi yang buruk membuat polutan tersebut terperangkap dan terakumulasi di dalam ruangan. "
        "Beberapa langkah sederhana seperti memastikan sirkulasi udara yang baik saat memasak, rutin membersihkan rumah dari debu, serta menghindari merokok di dalam ruangan dapat membantu menjaga kualitas udara dalam rumah tetap lebih sehat.",
  ),
];

// =========================================================
// HALAMAN INFO POLUTAN (EDUKASI)
//
// DIUBAH: dari StatelessWidget -> StatefulWidget supaya bisa
// memuat foto profil user dari Session dan menampilkannya di
// header, sama seperti halaman Peta/Histori/Prediksi/Tersimpan.
// =========================================================
class InfoPolutanPage extends StatefulWidget {
  const InfoPolutanPage({super.key});

  @override
  State<InfoPolutanPage> createState() => _InfoPolutanPageState();
}

class _InfoPolutanPageState extends State<InfoPolutanPage> {
  // TAMBAHAN: foto profil user, diambil dari Session supaya avatar
  // di header menampilkan foto asli, bukan placeholder.
  String? _fotoUrl;

  @override
  void initState() {
    super.initState();
    _muatFotoProfil();
  }

  Future<void> _muatFotoProfil() async {
    final foto = await Session.getFotoUrl();
    if (mounted) setState(() => _fotoUrl = foto);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Tema.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _buildIntroCard(),
                  const SizedBox(height: 18),
                  _buildLabelSection("Jenis-jenis Polutan yang Dipantau"),
                  const SizedBox(height: 10),
                  ..._daftarPolutan.map(_buildKartuPolutan),
                  const SizedBox(height: 18),
                  _buildLabelSection("Kategori Indeks Kualitas Udara (AQI)"),
                  const SizedBox(height: 10),
                  _buildKategoriAqiCard(),
                  const SizedBox(height: 18),
                  _buildLabelSection("Tips Melindungi Diri"),
                  const SizedBox(height: 10),
                  ..._daftarTips.map(_buildKartuTips),
                  const SizedBox(height: 18),
                  _buildLabelSection("Artikel & Edukasi"),
                  const SizedBox(height: 10),
                  ..._daftarArtikel
                      .map((a) => _buildKartuArtikel(context, a)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header sekarang menampilkan logo asli PureAir (bukan Icon bawaan)
  // serta avatar foto profil user, mengikuti pola header di halaman
  // Peta/Histori/Prediksi/Tersimpan.
  Widget _buildHeader(BuildContext context) {
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
              boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black.withOpacity(0.08))],
            ),
            child: const Icon(Icons.arrow_back, size: 18, color: _Tema.teksHitam),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text("Info Polutan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
            Text("Edukasi kualitas udara & kesehatan",
                style: TextStyle(fontSize: 11.5, color: _Tema.teksAbu)),
          ]),
        ),
        const SizedBox(width: 8),
        // Logo asli PureAir (icon + text)
        Row(children: [
          Image.asset(
            'assets/logo/pureair_logo_icon.png',
            width: 26,
            height: 26,
          ),
          const SizedBox(width: 5),
          Image.asset(
            'assets/logo/pureair_logo_text.png',
            height: 16,
            fit: BoxFit.fitHeight,
          ),
        ]),
        const SizedBox(width: 10),
        // Avatar -- menampilkan foto profil asli user (dari Session),
        // fallback ke ikon polos kalau belum ada foto / gagal dimuat.
        GestureDetector(
          onTap: () {
            // TODO: arahkan ke halaman profil
          },
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _Tema.cardBorder),
              boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black.withOpacity(0.06))],
            ),
            child: ClipOval(
              child: (_fotoUrl != null && _fotoUrl!.isNotEmpty)
                  ? Image.network(
                _fotoUrl!,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.person_outline, size: 18, color: _Tema.teksHitam),
              )
                  : const Icon(Icons.person_outline, size: 18, color: _Tema.teksHitam),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Tema.aksen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tema.aksen.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.school_outlined, color: _Tema.aksen, size: 20),
          SizedBox(width: 8),
          Text("Apa itu Polusi Udara?",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
        ]),
        const SizedBox(height: 8),
        const Text(
          "Polusi udara terjadi ketika zat-zat berbahaya seperti partikel debu, gas, dan senyawa kimia terlepas ke atmosfer dalam jumlah yang dapat membahayakan kesehatan manusia dan lingkungan. "
              "PureAir memantau enam parameter utama untuk membantu kamu memahami kondisi udara di sekitarmu dan mengambil langkah pencegahan yang tepat.",
          style: TextStyle(fontSize: 12.5, color: _Tema.teksHitam, height: 1.5),
        ),
      ]),
    );
  }

  Widget _buildLabelSection(String label) {
    return Text(label,
        style: const TextStyle(fontSize: 13, color: _Tema.teksHitam, fontWeight: FontWeight.w700));
  }

  Widget _buildKartuPolutan(_PolutanEdukasi p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Tema.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          leading: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: p.warna.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(p.icon, size: 19, color: p.warna),
          ),
          title: Text(p.label,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
          subtitle: Text(p.namaLengkap,
              style: const TextStyle(fontSize: 11.5, color: _Tema.teksAbu)),
          children: [
            Text(p.deskripsi,
                style: const TextStyle(fontSize: 12.5, color: _Tema.teksHitam, height: 1.5)),
            const SizedBox(height: 12),
            Text("Sumber Utama",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.warna)),
            const SizedBox(height: 6),
            ...p.sumber.map((s) => _buildBullet(s, p.warna)),
            const SizedBox(height: 12),
            Text("Dampak Kesehatan",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.warna)),
            const SizedBox(height: 6),
            ...p.dampakKesehatan.map((s) => _buildBullet(s, p.warna)),
          ],
        ),
      ),
    );
  }

  Widget _buildBullet(String teks, Color warna) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 5, height: 5,
            decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(teks,
              style: const TextStyle(fontSize: 12, color: _Tema.teksHitam, height: 1.4)),
        ),
      ]),
    );
  }

  Widget _buildKategoriAqiCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Column(
        children: _kategoriAqiList.map((k) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: k.warna, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(k.range,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _Tema.teksAbu)),
                  const SizedBox(width: 8),
                  Text(k.label,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: k.warna)),
                ]),
                const SizedBox(height: 3),
                Text(k.saran,
                    style: const TextStyle(fontSize: 11.5, color: _Tema.teksHitam, height: 1.4)),
              ]),
            ),
          ]),
        )).toList(),
      ),
    );
  }

  Widget _buildKartuTips(_TipsSehat t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Tema.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Tema.cardBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _Tema.aksen.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(t.icon, size: 18, color: _Tema.aksen),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.judul,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _Tema.teksHitam)),
          const SizedBox(height: 4),
          Text(t.deskripsi,
              style: const TextStyle(fontSize: 12, color: _Tema.teksAbu, height: 1.5)),
        ])),
      ]),
    );
  }

  Widget _buildKartuArtikel(BuildContext context, _ArtikelEdukasi a) {
    return InkWell(
      onTap: () => _showArtikelSheet(context, a),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _Tema.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _Tema.cardBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _Tema.aksen.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(a.icon, size: 19, color: _Tema.aksen),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _Tema.aksen.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(a.kategori,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _Tema.aksen)),
            ),
            const SizedBox(height: 6),
            Text(a.judul,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
            const SizedBox(height: 4),
            Text(a.ringkasan,
                style: const TextStyle(fontSize: 11.5, color: _Tema.teksAbu, height: 1.4)),
          ])),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18, color: _Tema.teksAbu),
        ]),
      ),
    );
  }

  void _showArtikelSheet(BuildContext context, _ArtikelEdukasi a) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _Tema.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _Tema.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _Tema.aksen.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(a.kategori,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _Tema.aksen)),
            ),
            const SizedBox(height: 10),
            Text(a.judul,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _Tema.teksHitam)),
            const SizedBox(height: 12),
            Text(a.isi,
                style: const TextStyle(fontSize: 13, color: _Tema.teksHitam, height: 1.6)),
          ],
        ),
      ),
    );
  }
}