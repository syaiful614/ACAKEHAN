"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : app/utils/pembantu.py
  Fungsi : Kumpulan fungsi utilitas yang dipakai bersama
           di seluruh lapisan aplikasi
============================================================
"""

from datetime import datetime
from decimal import Decimal
from passlib.context import CryptContext

from app.config.pengaturan import ambilPengaturan

cfg = ambilPengaturan()

# ── Konteks hashing bcrypt (menggunakan passlib) ─────────────
# deprecated="auto" → hash lama otomatis di-upgrade ke bcrypt saat login
konteksBcrypt = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ============================================================
#  BCRYPT: Hash & Verifikasi Kata Sandi
# ============================================================
def hashKataSandi(kataSandiPolos: str) -> str:
    """
    Menghasilkan hash bcrypt dari kata sandi yang diberikan.
    Bcrypt secara otomatis menambahkan salt acak — setiap hash unik
    meskipun kata sandinya sama.

    Args:
        kataSandiPolos: Kata sandi asli sebelum di-hash

    Returns:
        String hash bcrypt, contoh: "$2b$12$..."
    """
    return konteksBcrypt.hash(kataSandiPolos)


def verifikasiKataSandi(kataSandiPolos: str, hashTersimpan: str) -> bool:
    """
    Membandingkan kata sandi polos dengan hash yang tersimpan di DB.
    AMAN terhadap timing attack karena menggunakan perbandingan konstan.

    Args:
        kataSandiPolos : Kata sandi yang diinput pengguna saat login
        hashTersimpan  : Hash bcrypt dari database

    Returns:
        True jika cocok, False jika tidak
    """
    return konteksBcrypt.verify(kataSandiPolos, hashTersimpan)


# ============================================================
#  FORMAT MATA UANG
# ============================================================
def formatRupiah(nominal: float) -> str:
    """
    Mengubah angka float menjadi format mata uang Rupiah Indonesia.

    Contoh:
        1500000.5  →  "Rp 1.500.000,50"
        250000.0   →  "Rp 250.000,00"

    Args:
        nominal: Nilai uang dalam float atau Decimal

    Returns:
        String mata uang dalam format Indonesia
    """
    try:
        nilai = float(nominal)
        bagianBulat   = int(nilai)
        bagianDesimal = round((nilai - bagianBulat) * 100)
        # Format ribuan dengan titik (standar Indonesia)
        formatBulat = f"{bagianBulat:,}".replace(",", ".")
        return f"Rp {formatBulat},{bagianDesimal:02d}"
    except (TypeError, ValueError):
        return "Rp 0,00"


# ============================================================
#  NAMA BULAN BAHASA INDONESIA
# ============================================================
NAMA_BULAN_ID = [
    "", "Januari", "Februari", "Maret", "April", "Mei", "Juni",
    "Juli", "Agustus", "September", "Oktober", "November", "Desember"
]


def namaBulan(nomorBulan: int) -> str:
    """
    Mengonversi nomor bulan ke nama bulan Bahasa Indonesia.

    Args:
        nomorBulan: Integer 1-12

    Returns:
        Nama bulan, contoh: namaBulan(7) → "Juli"
    """
    if 1 <= nomorBulan <= 12:
        return NAMA_BULAN_ID[nomorBulan]
    return "?"


def labelPeriode(bulan: int, tahun: int) -> str:
    """
    Membuat label teks untuk periode bulan-tahun.

    Contoh:
        labelPeriode(7, 2024) → "Juli 2024"
    """
    return f"{namaBulan(bulan)} {tahun}"


# ============================================================
#  HELPER: Periode Bulan Ini
# ============================================================
def periodeBulanIni() -> dict:
    """
    Mengembalikan bulan dan tahun saat ini sebagai dictionary.

    Returns:
        {"bulan": 7, "tahun": 2024}
    """
    sekarang = datetime.utcnow()
    return {"bulan": sekarang.month, "tahun": sekarang.year}


# ============================================================
#  HELPER: Enam Bulan Terakhir
# ============================================================
def enamBulanTerakhir() -> list:
    """
    Menghasilkan daftar 6 periode bulan terakhir (termasuk bulan ini),
    diurutkan dari yang paling lama ke yang terbaru.

    Returns:
        List of dict: [{"bulan": 2, "tahun": 2024}, ..., {"bulan": 7, "tahun": 2024}]
    """
    from dateutil.relativedelta import relativedelta

    sekarang = datetime.utcnow()
    periodeList = []

    for i in range(5, -1, -1):  # 5, 4, 3, 2, 1, 0 (0 = bulan ini)
        tgl = sekarang - relativedelta(months=i)
        periodeList.append({"bulan": tgl.month, "tahun": tgl.year})

    return periodeList
