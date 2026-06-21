"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : models/model_database.py
  Fungsi : Definisi Model / Entitas Database (ORM)
  Pola   : MVT — Layer Model
============================================================
"""

from datetime import datetime
from extensions import db   # Instance SQLAlchemy dari app factory


# ============================================================
#  MODEL: Pengguna
# ============================================================
class Pengguna(db.Model):
    """
    Merepresentasikan akun pengguna aplikasi Acakehan.
    Relasi:
      - 1 Pengguna → Banyak Transaksi
      - 1 Pengguna → Banyak Anggaran
      - 1 Pengguna → Banyak Kategori (custom)
    """
    __tablename__ = "tbl_pengguna"

    pengguna_id    = db.Column(db.Integer,      primary_key=True, autoincrement=True)
    namaLengkap    = db.Column(db.String(100),  nullable=False)
    email          = db.Column(db.String(150),  nullable=False, unique=True, index=True)
    passwordHash   = db.Column(db.String(255),  nullable=False)
    nomorTelepon   = db.Column(db.String(20),   nullable=True)
    fotoProfil     = db.Column(db.String(255),  nullable=True)
    statusAktif    = db.Column(db.SmallInteger, nullable=False, default=1)
    peranUser      = db.Column(db.Enum("pengguna", "admin"), nullable=False, default="pengguna")
    tanggalDaftar  = db.Column(db.DateTime,     nullable=False, default=datetime.utcnow)
    terakhirLogin  = db.Column(db.DateTime,     nullable=True)

    # Relasi ke tabel lain (lazy="dynamic" agar query lebih efisien)
    daftar_transaksi = db.relationship("Transaksi",  backref="pemilik",   lazy="dynamic",
                                        foreign_keys="Transaksi.pengguna_id")
    daftar_anggaran  = db.relationship("Anggaran",   backref="pemilik",   lazy="dynamic",
                                        foreign_keys="Anggaran.pengguna_id")
    daftar_kategori  = db.relationship("Kategori",   backref="pembuat",   lazy="dynamic",
                                        foreign_keys="Kategori.pengguna_id")

    def ke_dict(self):
        """Konversi objek ke dictionary (untuk respons JSON). Password TIDAK disertakan."""
        return {
            "penggunaId":   self.pengguna_id,
            "namaLengkap":  self.namaLengkap,
            "email":        self.email,
            "nomorTelepon": self.nomorTelepon,
            "fotoProfil":   self.fotoProfil,
            "statusAktif":  bool(self.statusAktif),
            "peranUser":    self.peranUser,
            "tanggalDaftar": self.tanggalDaftar.isoformat() if self.tanggalDaftar else None,
            "terakhirLogin": self.terakhirLogin.isoformat()  if self.terakhirLogin  else None,
        }

    def __repr__(self):
        return f"<Pengguna id={self.pengguna_id} email={self.email}>"


# ============================================================
#  MODEL: Kategori
# ============================================================
class Kategori(db.Model):
    """
    Kategori transaksi (contoh: Makanan, Gaji, Transportasi).
    pengguna_id = NULL  → kategori global buatan Admin
    pengguna_id = <id>  → kategori custom buatan pengguna
    """
    __tablename__ = "tbl_kategori"

    kategori_id    = db.Column(db.Integer,     primary_key=True, autoincrement=True)
    namaKategori   = db.Column(db.String(80),  nullable=False)
    ikonKategori   = db.Column(db.String(100), nullable=True)
    tipeKategori   = db.Column(db.Enum("pemasukan", "pengeluaran"), nullable=False)
    pengguna_id    = db.Column(db.Integer,     db.ForeignKey("tbl_pengguna.pengguna_id",
                               ondelete="CASCADE"), nullable=True)
    tanggalDibuat  = db.Column(db.DateTime,    nullable=False, default=datetime.utcnow)

    def ke_dict(self):
        return {
            "kategoriId":    self.kategori_id,
            "namaKategori":  self.namaKategori,
            "ikonKategori":  self.ikonKategori,
            "tipeKategori":  self.tipeKategori,
            "adalahGlobal":  self.pengguna_id is None,
        }

    def __repr__(self):
        return f"<Kategori id={self.kategori_id} nama={self.namaKategori}>"


# ============================================================
#  MODEL: Transaksi
# ============================================================
class Transaksi(db.Model):
    """
    Mencatat setiap transaksi keuangan pengguna.
    statusHapus = 1 → soft delete (data tidak benar-benar dihapus dari DB)
    """
    __tablename__ = "tbl_transaksi"

    transaksi_id       = db.Column(db.Integer,      primary_key=True, autoincrement=True)
    pengguna_id        = db.Column(db.Integer,       db.ForeignKey("tbl_pengguna.pengguna_id",
                                   ondelete="CASCADE"), nullable=False, index=True)
    kategori_id        = db.Column(db.Integer,       db.ForeignKey("tbl_kategori.kategori_id",
                                   ondelete="RESTRICT"), nullable=False)
    jumlahNominal      = db.Column(db.Numeric(15, 2), nullable=False)
    tipeTransaksi      = db.Column(db.Enum("pemasukan", "pengeluaran"), nullable=False)
    tanggalTransaksi   = db.Column(db.Date,           nullable=False)
    catatanTambahan    = db.Column(db.Text,            nullable=True)
    buktiStruk         = db.Column(db.String(255),    nullable=True)
    tanggalDicatat     = db.Column(db.DateTime,       nullable=False, default=datetime.utcnow)
    statusHapus        = db.Column(db.SmallInteger,   nullable=False, default=0)

    # Relasi ke Kategori
    kategori = db.relationship("Kategori", backref="transaksi_list", lazy="joined")

    def ke_dict(self):
        return {
            "transaksiId":      self.transaksi_id,
            "penggunaId":       self.pengguna_id,
            "kategori":         self.kategori.ke_dict() if self.kategori else None,
            "jumlahNominal":    float(self.jumlahNominal),
            "tipeTransaksi":    self.tipeTransaksi,
            "tanggalTransaksi": self.tanggalTransaksi.isoformat() if self.tanggalTransaksi else None,
            "catatanTambahan":  self.catatanTambahan,
            "tanggalDicatat":   self.tanggalDicatat.isoformat()   if self.tanggalDicatat   else None,
        }

    def __repr__(self):
        return f"<Transaksi id={self.transaksi_id} tipe={self.tipeTransaksi} jumlah={self.jumlahNominal}>"


# ============================================================
#  MODEL: Anggaran
# ============================================================
class Anggaran(db.Model):
    """
    Anggaran bulanan pengguna per kategori pengeluaran.
    Constraint UNIQUE mencegah duplikasi anggaran di bulan & tahun yang sama.
    """
    __tablename__ = "tbl_anggaran"
    __table_args__ = (
        db.UniqueConstraint(
            "pengguna_id", "kategori_id", "periodesBulan", "periodeTahun",
            name="uq_anggaran_per_periode"
        ),
    )

    anggaran_id       = db.Column(db.Integer,       primary_key=True, autoincrement=True)
    pengguna_id       = db.Column(db.Integer,        db.ForeignKey("tbl_pengguna.pengguna_id",
                                  ondelete="CASCADE"),  nullable=False, index=True)
    kategori_id       = db.Column(db.Integer,        db.ForeignKey("tbl_kategori.kategori_id",
                                  ondelete="RESTRICT"), nullable=False)
    batasMaksimal     = db.Column(db.Numeric(15, 2), nullable=False)
    periodesBulan     = db.Column(db.SmallInteger,   nullable=False)  # 1–12
    periodeTahun      = db.Column(db.SmallInteger,   nullable=False)  # e.g. 2024
    totalTerpakai     = db.Column(db.Numeric(15, 2), nullable=False, default=0.00)
    statusNotifikasi  = db.Column(db.SmallInteger,   nullable=False, default=0)
    tanggalDibuat     = db.Column(db.DateTime,       nullable=False, default=datetime.utcnow)

    # Relasi
    kategori = db.relationship("Kategori", backref="anggaran_list", lazy="joined")

    @property
    def persenTerpakai(self):
        """Hitung persentase anggaran yang sudah terpakai."""
        if not self.batasMaksimal or float(self.batasMaksimal) == 0:
            return 0.0
        return round((float(self.totalTerpakai) / float(self.batasMaksimal)) * 100, 2)

    def ke_dict(self):
        return {
            "anggaranId":      self.anggaran_id,
            "kategori":        self.kategori.ke_dict() if self.kategori else None,
            "batasMaksimal":   float(self.batasMaksimal),
            "periodesBulan":   self.periodesBulan,
            "periodeTahun":    self.periodeTahun,
            "totalTerpakai":   float(self.totalTerpakai),
            "persenTerpakai":  self.persenTerpakai,
            "statusNotifikasi": bool(self.statusNotifikasi),
        }

    def __repr__(self):
        return (f"<Anggaran id={self.anggaran_id} "
                f"bulan={self.periodesBulan}/{self.periodeTahun} "
                f"terpakai={self.persenTerpakai}%>")


# ============================================================
#  MODEL: Notifikasi
# ============================================================
class Notifikasi(db.Model):
    """Menyimpan riwayat notifikasi yang dikirim ke pengguna."""
    __tablename__ = "tbl_notifikasi"

    notifikasi_id    = db.Column(db.Integer,    primary_key=True, autoincrement=True)
    pengguna_id      = db.Column(db.Integer,    db.ForeignKey("tbl_pengguna.pengguna_id",
                                 ondelete="CASCADE"), nullable=False, index=True)
    anggaran_id      = db.Column(db.Integer,    db.ForeignKey("tbl_anggaran.anggaran_id",
                                 ondelete="SET NULL"), nullable=True)
    judulPesan       = db.Column(db.String(150), nullable=False)
    isiPesan         = db.Column(db.Text,        nullable=False)
    tipeNotifikasi   = db.Column(db.Enum("peringatan", "info", "sukses"), nullable=False)
    statusBaca       = db.Column(db.SmallInteger, nullable=False, default=0)
    tanggalKirim     = db.Column(db.DateTime,    nullable=False, default=datetime.utcnow)

    def ke_dict(self):
        return {
            "notifikasiId":  self.notifikasi_id,
            "judulPesan":    self.judulPesan,
            "isiPesan":      self.isiPesan,
            "tipeNotifikasi": self.tipeNotifikasi,
            "sudahDibaca":   bool(self.statusBaca),
            "tanggalKirim":  self.tanggalKirim.isoformat() if self.tanggalKirim else None,
        }
