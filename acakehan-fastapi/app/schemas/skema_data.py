"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : app/schemas/skema_data.py
  Fungsi : Schema Pydantic — validasi input request
           dan serialisasi output response (DTO pattern)
  Standar: PascalCase untuk nama class, camelCase untuk field
============================================================
"""

from datetime import datetime, date
from decimal import Decimal
from typing import Optional, List, Any, Generic, TypeVar
from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator

# TypeVar untuk Generic Response
T = TypeVar("T")


# ============================================================
#  SCHEMA DASAR: Respons API standar
# ============================================================
class ResponAPI(BaseModel, Generic[T]):
    """
    Struktur respons JSON yang konsisten untuk SEMUA endpoint.
    Dengan Generic[T], tipe field 'data' bisa berupa apapun.

    Contoh penggunaan:
        return ResponAPI[DataPengguna](
            berhasil=True,
            pesan="Login berhasil",
            data=objPengguna
        )
    """
    berhasil:  bool     = Field(..., description="True jika operasi sukses")
    pesan:     str      = Field(..., description="Pesan deskriptif untuk pengguna")
    data:      Optional[T] = Field(None, description="Payload data (jika ada)")
    timestamp: datetime = Field(default_factory=datetime.utcnow)

    model_config = {"from_attributes": True}


class ResponAPIList(BaseModel, Generic[T]):
    """Respons API untuk data koleksi dengan informasi pagination."""
    berhasil:   bool        = True
    pesan:      str         = ""
    data:       List[T]     = []
    total:      int         = 0
    halaman:    int         = 1
    perHalaman: int         = 20
    totalHalaman: int       = 1
    timestamp:  datetime    = Field(default_factory=datetime.utcnow)

    model_config = {"from_attributes": True}


# ============================================================
#  SCHEMA: Pengguna
# ============================================================
class SkemaRegistrasi(BaseModel):
    """Validasi body request untuk endpoint POST /auth/daftar."""
    namaLengkap:           str      = Field(..., min_length=3, max_length=100,
                                            description="Nama lengkap pengguna")
    email:                 EmailStr = Field(..., description="Alamat email yang valid")
    kataSandi:             str      = Field(..., min_length=8, max_length=72,
                                            description="Kata sandi (min. 8 karakter)")
    konfirmasiKataSandi:   str      = Field(..., description="Harus sama dengan kataSandi")
    nomorTelepon:          Optional[str] = Field(None, max_length=20,
                                            description="Nomor telepon (opsional)")

    @field_validator("kataSandi")
    @classmethod
    def validasiKekuatanKataSandi(cls, nilaiKataSandi: str) -> str:
        """
        Kata sandi wajib mengandung:
        - Minimal 1 huruf kapital
        - Minimal 1 huruf kecil
        - Minimal 1 angka
        """
        import re
        kesalahan = []
        if not re.search(r"[A-Z]", nilaiKataSandi):
            kesalahan.append("minimal 1 huruf kapital")
        if not re.search(r"[a-z]", nilaiKataSandi):
            kesalahan.append("minimal 1 huruf kecil")
        if not re.search(r"\d", nilaiKataSandi):
            kesalahan.append("minimal 1 angka")
        if kesalahan:
            raise ValueError(
                "Kata sandi harus mengandung: " + ", ".join(kesalahan) + "."
            )
        return nilaiKataSandi

    @model_validator(mode="after")
    def validasiKonfirmasiKataSandi(self) -> "SkemaRegistrasi":
        """Pastikan kata sandi dan konfirmasi sama persis."""
        if self.kataSandi != self.konfirmasiKataSandi:
            raise ValueError("Kata sandi dan konfirmasi kata sandi tidak cocok.")
        return self

    @field_validator("namaLengkap")
    @classmethod
    def bersihkanNama(cls, nama: str) -> str:
        return nama.strip()


class SkemaLogin(BaseModel):
    """Validasi body request untuk endpoint POST /auth/masuk."""
    email:     EmailStr = Field(..., description="Email terdaftar")
    kataSandi: str      = Field(..., min_length=1, description="Kata sandi akun")


class SkemaDataPengguna(BaseModel):
    """Data pengguna yang aman untuk dikembalikan dalam respons (TANPA password)."""
    penggunaId:    int
    namaLengkap:   str
    email:         str
    nomorTelepon:  Optional[str]
    fotoProfil:    Optional[str]
    statusAktif:   bool
    peranUser:     str
    tanggalDaftar: datetime
    terakhirLogin: Optional[datetime]

    model_config = {"from_attributes": True}


class SkemaToken(BaseModel):
    """Data token JWT yang dikembalikan setelah login/registrasi."""
    tokenAkses:   str
    tokenRefresh: str
    tipeToken:    str = "Bearer"
    masaBerlakuDetik: int


class SkemaResponLogin(BaseModel):
    """Gabungan data pengguna + token untuk respons login/registrasi."""
    pengguna: SkemaDataPengguna
    token:    SkemaToken


# ============================================================
#  SCHEMA: Kategori
# ============================================================
class SkemaDataKategori(BaseModel):
    """Data kategori untuk respons API."""
    kategoriId:   int
    namaKategori: str
    ikonKategori: Optional[str]
    tipeKategori: str
    adalahGlobal: bool

    model_config = {"from_attributes": True}


# ============================================================
#  SCHEMA: Transaksi
# ============================================================
class SkemaTambahTransaksi(BaseModel):
    """Validasi body request untuk endpoint POST /transaksi."""
    kategoriId:       int     = Field(..., gt=0, description="ID kategori yang dipilih")
    jumlahNominal:    Decimal = Field(..., gt=0, le=Decimal("999999999999999.99"),
                                      description="Nominal transaksi (harus > 0)")
    tipeTransaksi:    str     = Field(..., description="'pemasukan' atau 'pengeluaran'")
    tanggalTransaksi: date    = Field(..., description="Tanggal transaksi (YYYY-MM-DD)")
    catatanTambahan:  Optional[str] = Field(None, max_length=1000,
                                            description="Catatan tambahan (opsional)")

    @field_validator("tipeTransaksi")
    @classmethod
    def validasiTipeTransaksi(cls, nilai: str) -> str:
        nilaiValid = ("pemasukan", "pengeluaran")
        if nilai.lower() not in nilaiValid:
            raise ValueError(
                f"tipeTransaksi tidak valid. Gunakan salah satu: {', '.join(nilaiValid)}."
            )
        return nilai.lower()

    @field_validator("tanggalTransaksi")
    @classmethod
    def validasiTanggalTidakMasaDepan(cls, tgl: date) -> date:
        from datetime import date as DateType
        if tgl > DateType.today():
            raise ValueError("Tanggal transaksi tidak boleh di masa depan.")
        return tgl

    @field_validator("jumlahNominal")
    @classmethod
    def validasiNominalDuaDesimal(cls, nominal: Decimal) -> Decimal:
        """Pastikan nominal hanya memiliki maksimal 2 angka desimal."""
        return round(nominal, 2)


class SkemaDataTransaksi(BaseModel):
    """Data transaksi untuk respons API."""
    transaksiId:      int
    penggunaId:       int
    kategori:         Optional[SkemaDataKategori]
    jumlahNominal:    float
    tipeTransaksi:    str
    tanggalTransaksi: date
    catatanTambahan:  Optional[str]
    tanggalDicatat:   datetime

    model_config = {"from_attributes": True}


class SkemaInfoAnggaran(BaseModel):
    """Info status anggaran setelah transaksi dicatat."""
    adaAnggaran:    bool
    anggaranId:     Optional[int]    = None
    batasMaksimal:  Optional[float]  = None
    totalTerpakai:  Optional[float]  = None
    sisaAnggaran:   Optional[float]  = None
    persenTerpakai: Optional[float]  = None
    adaNotifikasi:  bool             = False
    notifikasi:     Optional[dict]   = None
    pesan:          str              = ""


class SkemaResponTransaksi(BaseModel):
    """Respons lengkap setelah transaksi berhasil dicatat."""
    transaksi: SkemaDataTransaksi
    anggaran:  Optional[SkemaInfoAnggaran]


# ============================================================
#  SCHEMA: Anggaran
# ============================================================
class SkemaTambahAnggaran(BaseModel):
    """Validasi body request untuk endpoint POST /anggaran."""
    kategoriId:    int     = Field(..., gt=0)
    batasMaksimal: Decimal = Field(..., gt=0, le=Decimal("999999999999999.99"))
    periodesBulan: int     = Field(..., ge=1, le=12, description="Bulan: 1-12")
    periodeTahun:  int     = Field(..., ge=2000, le=2100, description="Tahun: YYYY")


class SkemaDataAnggaran(BaseModel):
    """Data anggaran untuk respons API."""
    anggaranId:       int
    kategori:         Optional[SkemaDataKategori]
    batasMaksimal:    float
    periodesBulan:    int
    periodeTahun:     int
    totalTerpakai:    float
    persenTerpakai:   float
    sisaAnggaran:     float
    statusNotifikasi: bool

    model_config = {"from_attributes": True}


# ============================================================
#  SCHEMA: Dashboard
# ============================================================
class SkemaRingkasanBulanan(BaseModel):
    """Ringkasan keuangan satu bulan."""
    bulan:              int
    tahun:              int
    totalPemasukan:     float
    totalPengeluaran:   float
    saldoBersih:        float       # totalPemasukan - totalPengeluaran
    jumlahTransaksi:    int


class SkemaPengeluaranPerKategori(BaseModel):
    """Breakdown pengeluaran berdasarkan kategori (untuk grafik pie)."""
    namaKategori:   str
    ikonKategori:   Optional[str]
    totalNominal:   float
    jumlahTransaksi: int
    persenDariTotal: float


class SkemaTrenBulanan(BaseModel):
    """Data tren pemasukan vs pengeluaran per bulan (untuk grafik garis)."""
    bulan:            int
    tahun:            int
    labelBulan:       str           # Contoh: "Juli 2024"
    totalPemasukan:   float
    totalPengeluaran: float
    saldoBersih:      float


class SkemaStatusAnggaran(BaseModel):
    """Status semua anggaran aktif pengguna di bulan ini."""
    namaKategori:   str
    ikonKategori:   Optional[str] = None   # FIX: tambah ikon kategori untuk tampilan UI
    batasMaksimal:  float
    totalTerpakai:  float
    persenTerpakai: float
    sisaAnggaran:   float
    statusAman:     bool            # True jika < 80%, False jika >= 80%


class SkemaDataDashboard(BaseModel):
    """Respons lengkap untuk endpoint GET /dashboard."""
    ringkasanBulanIni:       SkemaRingkasanBulanan
    pengeluaranPerKategori:  List[SkemaPengeluaranPerKategori]
    trenEnamBulanTerakhir:   List[SkemaTrenBulanan]
    statusSemuaAnggaran:     List[SkemaStatusAnggaran]
    notifikasiBelumDibaca:   int


# ============================================================
#  SCHEMA: Notifikasi
# ============================================================
class SkemaDataNotifikasi(BaseModel):
    """Data notifikasi untuk respons API."""
    notifikasiId:   int
    judulPesan:     str
    isiPesan:       str
    tipeNotifikasi: str
    sudahDibaca:    bool
    tanggalKirim:   datetime

    model_config = {"from_attributes": True}
