// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/data/models/model_data.dart
//  Fungsi : Semua model data (DTO) — merepresentasikan
//           struktur JSON dari API backend FastAPI Acakehan.
//  Catatan: Menggunakan fromJson manual (tanpa code generation)
//           agar mudah dipahami untuk keperluan tugas.
// ============================================================

// ============================================================
//  MODEL: Token JWT
// ============================================================
class ModelToken {
  final String tokenAkses;
  final String tokenRefresh;
  final String tipeToken;
  final int masaBerlakuDetik;

  const ModelToken({
    required this.tokenAkses,
    required this.tokenRefresh,
    required this.tipeToken,
    required this.masaBerlakuDetik,
  });

  factory ModelToken.dariJson(Map<String, dynamic> json) {
    return ModelToken(
      tokenAkses:       json['tokenAkses']       as String,
      tokenRefresh:     json['tokenRefresh']     as String,
      tipeToken:        json['tipeToken']        as String,
      masaBerlakuDetik: json['masaBerlakuDetik'] as int,
    );
  }
}

// ============================================================
//  MODEL: Pengguna
// ============================================================
class ModelPengguna {
  final int    penggunaId;
  final String namaLengkap;
  final String email;
  final String? nomorTelepon;
  final String? fotoProfil;
  final bool   statusAktif;
  final String peranUser;
  final DateTime tanggalDaftar;
  final DateTime? terakhirLogin;

  const ModelPengguna({
    required this.penggunaId,
    required this.namaLengkap,
    required this.email,
    this.nomorTelepon,
    this.fotoProfil,
    required this.statusAktif,
    required this.peranUser,
    required this.tanggalDaftar,
    this.terakhirLogin,
  });

  factory ModelPengguna.dariJson(Map<String, dynamic> json) {
    return ModelPengguna(
      penggunaId:    json['penggunaId']   as int,
      namaLengkap:   json['namaLengkap']  as String,
      email:         json['email']        as String,
      nomorTelepon:  json['nomorTelepon'] as String?,
      fotoProfil:    json['fotoProfil']   as String?,
      statusAktif:   json['statusAktif']  as bool,
      peranUser:     json['peranUser']    as String,
      tanggalDaftar: DateTime.parse(json['tanggalDaftar'] as String),
      terakhirLogin: json['terakhirLogin'] != null
          ? DateTime.parse(json['terakhirLogin'] as String)
          : null,
    );
  }

  /// Ambil inisial nama untuk avatar (contoh: "Budi Santoso" → "BS")
  String get inisialNama {
    final kata = namaLengkap.trim().split(' ');
    if (kata.length >= 2) {
      return '${kata[0][0]}${kata[1][0]}'.toUpperCase();
    }
    return namaLengkap.substring(0, 2).toUpperCase();
  }

  /// Nama depan saja
  String get namaPanggilan => namaLengkap.split(' ').first;
}

// ============================================================
//  MODEL: Respons Login/Registrasi
// ============================================================
class ModelResponLogin {
  final ModelPengguna pengguna;
  final ModelToken token;

  const ModelResponLogin({required this.pengguna, required this.token});

  factory ModelResponLogin.dariJson(Map<String, dynamic> json) {
    return ModelResponLogin(
      pengguna: ModelPengguna.dariJson(json['pengguna'] as Map<String, dynamic>),
      token:    ModelToken.dariJson(json['token'] as Map<String, dynamic>),
    );
  }
}

// ============================================================
//  MODEL: Kategori
// ============================================================
class ModelKategori {
  final int    kategoriId;
  final String namaKategori;
  final String? ikonKategori;
  final String tipeKategori;
  final bool   adalahGlobal;

  const ModelKategori({
    required this.kategoriId,
    required this.namaKategori,
    this.ikonKategori,
    required this.tipeKategori,
    required this.adalahGlobal,
  });

  factory ModelKategori.dariJson(Map<String, dynamic> json) {
    return ModelKategori(
      kategoriId:   json['kategoriId']   as int,
      namaKategori: json['namaKategori'] as String,
      ikonKategori: json['ikonKategori'] as String?,
      tipeKategori: json['tipeKategori'] as String,
      adalahGlobal: json['adalahGlobal'] as bool,
    );
  }
}

// ============================================================
//  MODEL: Transaksi
// ============================================================
class ModelTransaksi {
  final int          transaksiId;
  final int          penggunaId;
  final ModelKategori? kategori;
  final double       jumlahNominal;
  final String       tipeTransaksi;
  final DateTime     tanggalTransaksi;
  final String?      catatanTambahan;
  final DateTime     tanggalDicatat;

  const ModelTransaksi({
    required this.transaksiId,
    required this.penggunaId,
    this.kategori,
    required this.jumlahNominal,
    required this.tipeTransaksi,
    required this.tanggalTransaksi,
    this.catatanTambahan,
    required this.tanggalDicatat,
  });

  factory ModelTransaksi.dariJson(Map<String, dynamic> json) {
    return ModelTransaksi(
      transaksiId:      json['transaksiId']    as int,
      penggunaId:       json['penggunaId']     as int,
      kategori:         json['kategori'] != null
          ? ModelKategori.dariJson(json['kategori'] as Map<String, dynamic>)
          : null,
      jumlahNominal:    (json['jumlahNominal'] as num).toDouble(),
      tipeTransaksi:    json['tipeTransaksi']  as String,
      tanggalTransaksi: DateTime.parse(json['tanggalTransaksi'] as String),
      catatanTambahan:  json['catatanTambahan'] as String?,
      tanggalDicatat:   DateTime.parse(json['tanggalDicatat'] as String),
    );
  }

  bool get adalahPemasukan   => tipeTransaksi == 'pemasukan';
  bool get adalahPengeluaran => tipeTransaksi == 'pengeluaran';
}

// ============================================================
//  MODEL: Dashboard — Ringkasan Bulanan
// ============================================================
class ModelRingkasanBulanan {
  final int    bulan;
  final int    tahun;
  final double totalPemasukan;
  final double totalPengeluaran;
  final double saldoBersih;
  final int    jumlahTransaksi;

  const ModelRingkasanBulanan({
    required this.bulan,
    required this.tahun,
    required this.totalPemasukan,
    required this.totalPengeluaran,
    required this.saldoBersih,
    required this.jumlahTransaksi,
  });

  factory ModelRingkasanBulanan.dariJson(Map<String, dynamic> json) {
    return ModelRingkasanBulanan(
      bulan:            json['bulan']            as int,
      tahun:            json['tahun']            as int,
      totalPemasukan:   (json['totalPemasukan']   as num).toDouble(),
      totalPengeluaran: (json['totalPengeluaran'] as num).toDouble(),
      saldoBersih:      (json['saldoBersih']      as num).toDouble(),
      jumlahTransaksi:  json['jumlahTransaksi']   as int,
    );
  }
}

// ============================================================
//  MODEL: Pengeluaran Per Kategori (Pie Chart)
// ============================================================
class ModelPengeluaranKategori {
  final String namaKategori;
  final String? ikonKategori;
  final double totalNominal;
  final int    jumlahTransaksi;
  final double persenDariTotal;

  const ModelPengeluaranKategori({
    required this.namaKategori,
    this.ikonKategori,
    required this.totalNominal,
    required this.jumlahTransaksi,
    required this.persenDariTotal,
  });

  factory ModelPengeluaranKategori.dariJson(Map<String, dynamic> json) {
    return ModelPengeluaranKategori(
      namaKategori:    json['namaKategori']   as String,
      ikonKategori:    json['ikonKategori']   as String?,
      totalNominal:    (json['totalNominal']  as num).toDouble(),
      jumlahTransaksi: json['jumlahTransaksi'] as int,
      persenDariTotal: (json['persenDariTotal'] as num).toDouble(),
    );
  }
}

// ============================================================
//  MODEL: Tren Bulanan (Line Chart)
// ============================================================
class ModelTrenBulanan {
  final int    bulan;
  final int    tahun;
  final String labelBulan;
  final double totalPemasukan;
  final double totalPengeluaran;
  final double saldoBersih;

  const ModelTrenBulanan({
    required this.bulan,
    required this.tahun,
    required this.labelBulan,
    required this.totalPemasukan,
    required this.totalPengeluaran,
    required this.saldoBersih,
  });

  factory ModelTrenBulanan.dariJson(Map<String, dynamic> json) {
    return ModelTrenBulanan(
      bulan:            json['bulan']            as int,
      tahun:            json['tahun']            as int,
      labelBulan:       json['labelBulan']       as String,
      totalPemasukan:   (json['totalPemasukan']   as num).toDouble(),
      totalPengeluaran: (json['totalPengeluaran'] as num).toDouble(),
      saldoBersih:      (json['saldoBersih']      as num).toDouble(),
    );
  }
}

// ============================================================
//  MODEL: Status Anggaran
// ============================================================
class ModelStatusAnggaran {
  final String namaKategori;
  final double batasMaksimal;
  final double totalTerpakai;
  final double persenTerpakai;
  final double sisaAnggaran;
  final bool   statusAman;

  const ModelStatusAnggaran({
    required this.namaKategori,
    required this.batasMaksimal,
    required this.totalTerpakai,
    required this.persenTerpakai,
    required this.sisaAnggaran,
    required this.statusAman,
  });

  factory ModelStatusAnggaran.dariJson(Map<String, dynamic> json) {
    return ModelStatusAnggaran(
      namaKategori:   json['namaKategori']   as String,
      batasMaksimal:  (json['batasMaksimal']  as num).toDouble(),
      totalTerpakai:  (json['totalTerpakai']  as num).toDouble(),
      persenTerpakai: (json['persenTerpakai'] as num).toDouble(),
      sisaAnggaran:   (json['sisaAnggaran']   as num).toDouble(),
      statusAman:     json['statusAman']     as bool,
    );
  }
}

// ============================================================
//  MODEL: Data Dashboard Lengkap
// ============================================================
class ModelDashboard {
  final ModelRingkasanBulanan       ringkasanBulanIni;
  final List<ModelPengeluaranKategori> pengeluaranPerKategori;
  final List<ModelTrenBulanan>      trenEnamBulanTerakhir;
  final List<ModelStatusAnggaran>   statusSemuaAnggaran;
  final int                         notifikasiBelumDibaca;

  const ModelDashboard({
    required this.ringkasanBulanIni,
    required this.pengeluaranPerKategori,
    required this.trenEnamBulanTerakhir,
    required this.statusSemuaAnggaran,
    required this.notifikasiBelumDibaca,
  });

  factory ModelDashboard.dariJson(Map<String, dynamic> json) {
    return ModelDashboard(
      ringkasanBulanIni: ModelRingkasanBulanan.dariJson(
        json['ringkasanBulanIni'] as Map<String, dynamic>,
      ),
      pengeluaranPerKategori: (json['pengeluaranPerKategori'] as List)
          .map((e) => ModelPengeluaranKategori.dariJson(e as Map<String, dynamic>))
          .toList(),
      trenEnamBulanTerakhir: (json['trenEnamBulanTerakhir'] as List)
          .map((e) => ModelTrenBulanan.dariJson(e as Map<String, dynamic>))
          .toList(),
      statusSemuaAnggaran: (json['statusSemuaAnggaran'] as List)
          .map((e) => ModelStatusAnggaran.dariJson(e as Map<String, dynamic>))
          .toList(),
      notifikasiBelumDibaca: json['notifikasiBelumDibaca'] as int,
    );
  }
}
