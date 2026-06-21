"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : app/models/model_db.py
  Fungsi : Definisi seluruh Model / Entitas Database (ORM)
  Standar: PascalCase untuk nama class, camelCase untuk kolom
============================================================
"""

import enum
from datetime import datetime, date
from decimal import Decimal
from typing import Optional, List

from sqlalchemy import (
    Integer, String, Text, Numeric, Date, DateTime,
    SmallInteger, Enum as SAEnum, ForeignKey,
    UniqueConstraint, Index, Boolean
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.config.database import ModelDasar


# ============================================================
#  ENUM: Tipe-tipe yang digunakan di database
# ============================================================
class TipeKategoriEnum(str, enum.Enum):
    PEMASUKAN   = "pemasukan"
    PENGELUARAN = "pengeluaran"


class PeranUserEnum(str, enum.Enum):
    PENGGUNA = "pengguna"
    ADMIN    = "admin"


class TipeNotifikasiEnum(str, enum.Enum):
    PERINGATAN = "peringatan"
    INFO       = "info"
    SUKSES     = "sukses"


# ============================================================
#  MODEL: Pengguna
# ============================================================
class Pengguna(ModelDasar):
    """
    Akun pengguna aplikasi Acakehan.
    Relasi:
        1 Pengguna → Banyak Transaksi
        1 Pengguna → Banyak Anggaran
        1 Pengguna → Banyak Kategori (custom)
        1 Pengguna → Banyak Notifikasi
    """
    __tablename__ = "tbl_pengguna"

    # Primary Key
    penggunaId:     Mapped[int]           = mapped_column("pengguna_id", Integer, primary_key=True, autoincrement=True)

    # Kolom data
    namaLengkap:    Mapped[str]           = mapped_column(String(100),  nullable=False)
    email:          Mapped[str]           = mapped_column(String(150),  nullable=False, unique=True, index=True)
    passwordHash:   Mapped[str]           = mapped_column(String(255),  nullable=False)
    nomorTelepon:   Mapped[Optional[str]] = mapped_column(String(20),   nullable=True)
    fotoProfil:     Mapped[Optional[str]] = mapped_column(String(255),  nullable=True)
    statusAktif:    Mapped[bool]          = mapped_column(Boolean,      nullable=False, default=True)
    peranUser:      Mapped[str]           = mapped_column(
                        SAEnum(PeranUserEnum, values_callable=lambda e: [x.value for x in e]),
                        nullable=False, default=PeranUserEnum.PENGGUNA.value
                    )
    tanggalDaftar:  Mapped[datetime]      = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    terakhirLogin:  Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Relasi ke tabel lain
    daftarTransaksi: Mapped[List["Transaksi"]]  = relationship("Transaksi",  back_populates="pemilik",
                                                                foreign_keys="Transaksi.penggunaId",
                                                                cascade="all, delete-orphan")
    daftarAnggaran:  Mapped[List["Anggaran"]]   = relationship("Anggaran",   back_populates="pemilik",
                                                                foreign_keys="Anggaran.penggunaId",
                                                                cascade="all, delete-orphan")
    daftarKategori:  Mapped[List["Kategori"]]   = relationship("Kategori",   back_populates="pembuat",
                                                                foreign_keys="Kategori.penggunaId")
    daftarNotifikasi: Mapped[List["Notifikasi"]] = relationship("Notifikasi", back_populates="penerima",
                                                                 cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<Pengguna id={self.penggunaId} email={self.email}>"


# ============================================================
#  MODEL: Kategori
# ============================================================
class Kategori(ModelDasar):
    """
    Kategori transaksi keuangan.
    - penggunaId = NULL  → kategori global buatan Admin
    - penggunaId = <id>  → kategori custom buatan pengguna
    """
    __tablename__ = "tbl_kategori"

    kategoriId:     Mapped[int]           = mapped_column("kategori_id", Integer, primary_key=True, autoincrement=True)
    namaKategori:   Mapped[str]           = mapped_column(String(80),  nullable=False)
    ikonKategori:   Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    tipeKategori:   Mapped[str]           = mapped_column(
                        SAEnum(TipeKategoriEnum, values_callable=lambda e: [x.value for x in e]),
                        nullable=False
                    )
    # NULL = kategori global sistem
    penggunaId:     Mapped[Optional[int]] = mapped_column(
                        "pengguna_id", Integer,
                        ForeignKey("tbl_pengguna.pengguna_id", ondelete="CASCADE"),
                        nullable=True, index=True
                    )
    tanggalDibuat:  Mapped[datetime]      = mapped_column(DateTime, nullable=False, default=datetime.utcnow)

    # Relasi
    pembuat:         Mapped[Optional["Pengguna"]]  = relationship("Pengguna", back_populates="daftarKategori",
                                                                   foreign_keys=[penggunaId])
    daftarTransaksi: Mapped[List["Transaksi"]]     = relationship("Transaksi", back_populates="kategori")
    daftarAnggaran:  Mapped[List["Anggaran"]]      = relationship("Anggaran",  back_populates="kategori")

    def __repr__(self) -> str:
        return f"<Kategori id={self.kategoriId} nama={self.namaKategori} tipe={self.tipeKategori}>"


# ============================================================
#  MODEL: Transaksi
# ============================================================
class Transaksi(ModelDasar):
    """
    Catatan transaksi keuangan harian pengguna.
    statusHapus = True → soft delete (data tetap ada di DB untuk audit)
    """
    __tablename__ = "tbl_transaksi"
    __table_args__ = (
        # Index gabungan untuk mempercepat query filter umum
        Index("idx_transaksi_pengguna_tanggal", "pengguna_id", "tanggal_transaksi"),
        Index("idx_transaksi_tipe",             "tipe_transaksi"),
    )

    transaksiId:      Mapped[int]           = mapped_column("transaksi_id",     Integer, primary_key=True, autoincrement=True)
    penggunaId:       Mapped[int]           = mapped_column("pengguna_id",      Integer,
                                                ForeignKey("tbl_pengguna.pengguna_id", ondelete="CASCADE"),
                                                nullable=False, index=True)
    kategoriId:       Mapped[int]           = mapped_column("kategori_id",      Integer,
                                                ForeignKey("tbl_kategori.kategori_id", ondelete="RESTRICT"),
                                                nullable=False)
    jumlahNominal:    Mapped[Decimal]       = mapped_column("jumlah_nominal",   Numeric(15, 2), nullable=False)
    tipeTransaksi:    Mapped[str]           = mapped_column("tipe_transaksi",
                                                SAEnum(TipeKategoriEnum, values_callable=lambda e: [x.value for x in e]),
                                                nullable=False)
    tanggalTransaksi: Mapped[date]          = mapped_column("tanggal_transaksi", Date, nullable=False)
    catatanTambahan:  Mapped[Optional[str]] = mapped_column("catatan_tambahan",  Text, nullable=True)
    buktiStruk:       Mapped[Optional[str]] = mapped_column("bukti_struk",       String(255), nullable=True)
    tanggalDicatat:   Mapped[datetime]      = mapped_column("tanggal_dicatat",   DateTime, nullable=False, default=datetime.utcnow)
    statusHapus:      Mapped[bool]          = mapped_column("status_hapus",      Boolean, nullable=False, default=False)

    # Relasi
    pemilik:  Mapped["Pengguna"]  = relationship("Pengguna",  back_populates="daftarTransaksi",
                                                   foreign_keys=[penggunaId])
    kategori: Mapped["Kategori"]  = relationship("Kategori",  back_populates="daftarTransaksi",
                                                   lazy="joined")  # Selalu join saat query

    def __repr__(self) -> str:
        return f"<Transaksi id={self.transaksiId} tipe={self.tipeTransaksi} nominal={self.jumlahNominal}>"


# ============================================================
#  MODEL: Anggaran
# ============================================================
class Anggaran(ModelDasar):
    """
    Anggaran bulanan per kategori pengeluaran.
    Constraint UNIQUE mencegah duplikasi anggaran pada periode yang sama.
    """
    __tablename__ = "tbl_anggaran"
    __table_args__ = (
        UniqueConstraint(
            "pengguna_id", "kategori_id", "periodes_bulan", "periode_tahun",
            name="uq_anggaran_per_periode"
        ),
    )

    anggaranId:       Mapped[int]     = mapped_column("anggaran_id",     Integer, primary_key=True, autoincrement=True)
    penggunaId:       Mapped[int]     = mapped_column("pengguna_id",     Integer,
                                            ForeignKey("tbl_pengguna.pengguna_id", ondelete="CASCADE"),
                                            nullable=False, index=True)
    kategoriId:       Mapped[int]     = mapped_column("kategori_id",     Integer,
                                            ForeignKey("tbl_kategori.kategori_id", ondelete="RESTRICT"),
                                            nullable=False)
    batasMaksimal:    Mapped[Decimal] = mapped_column("batas_maksimal",  Numeric(15, 2), nullable=False)
    periodesBulan:    Mapped[int]     = mapped_column("periodes_bulan",  SmallInteger,   nullable=False)
    periodeTahun:     Mapped[int]     = mapped_column("periode_tahun",   SmallInteger,   nullable=False)
    totalTerpakai:    Mapped[Decimal] = mapped_column("total_terpakai",  Numeric(15, 2), nullable=False, default=Decimal("0.00"))
    statusNotifikasi: Mapped[bool]    = mapped_column("status_notifikasi", Boolean,      nullable=False, default=False)
    tanggalDibuat:    Mapped[datetime] = mapped_column("tanggal_dibuat", DateTime,       nullable=False, default=datetime.utcnow)

    # Relasi
    pemilik:  Mapped["Pengguna"] = relationship("Pengguna",  back_populates="daftarAnggaran",
                                                 foreign_keys=[penggunaId])
    kategori: Mapped["Kategori"] = relationship("Kategori",  back_populates="daftarAnggaran",
                                                 lazy="joined")
    daftarNotifikasi: Mapped[List["Notifikasi"]] = relationship("Notifikasi", back_populates="anggaran")

    @property
    def persenTerpakai(self) -> float:
        """Hitung persentase pemakaian anggaran secara real-time."""
        batas = float(self.batasMaksimal)
        if batas == 0:
            return 0.0
        return round((float(self.totalTerpakai) / batas) * 100, 2)

    @property
    def sisaAnggaran(self) -> float:
        """Sisa anggaran yang masih bisa digunakan."""
        return max(0.0, float(self.batasMaksimal) - float(self.totalTerpakai))

    def __repr__(self) -> str:
        return (f"<Anggaran id={self.anggaranId} "
                f"bulan={self.periodesBulan}/{self.periodeTahun} "
                f"terpakai={self.persenTerpakai}%>")


# ============================================================
#  MODEL: Notifikasi
# ============================================================
class Notifikasi(ModelDasar):
    """Riwayat semua notifikasi yang dikirim ke pengguna."""
    __tablename__ = "tbl_notifikasi"

    notifikasiId:   Mapped[int]           = mapped_column("notifikasi_id", Integer, primary_key=True, autoincrement=True)
    penggunaId:     Mapped[int]           = mapped_column("pengguna_id",   Integer,
                                                ForeignKey("tbl_pengguna.pengguna_id", ondelete="CASCADE"),
                                                nullable=False, index=True)
    anggaranId:     Mapped[Optional[int]] = mapped_column("anggaran_id",   Integer,
                                                ForeignKey("tbl_anggaran.anggaran_id", ondelete="SET NULL"),
                                                nullable=True)
    judulPesan:     Mapped[str]           = mapped_column("judul_pesan",   String(150), nullable=False)
    isiPesan:       Mapped[str]           = mapped_column("isi_pesan",      Text,        nullable=False)
    tipeNotifikasi: Mapped[str]           = mapped_column("tipe_notifikasi",
                                                SAEnum(TipeNotifikasiEnum, values_callable=lambda e: [x.value for x in e]),
                                                nullable=False)
    statusBaca:     Mapped[bool]          = mapped_column("status_baca",   Boolean, nullable=False, default=False)
    tanggalKirim:   Mapped[datetime]      = mapped_column("tanggal_kirim", DateTime, nullable=False, default=datetime.utcnow)

    # Relasi
    penerima: Mapped["Pengguna"]          = relationship("Pengguna",  back_populates="daftarNotifikasi",
                                                          foreign_keys=[penggunaId])
    anggaran: Mapped[Optional["Anggaran"]] = relationship("Anggaran", back_populates="daftarNotifikasi",
                                                           foreign_keys=[anggaranId])

    def __repr__(self) -> str:
        return f"<Notifikasi id={self.notifikasiId} judul={self.judulPesan[:30]}>"
