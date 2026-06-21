"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : utils/pembantu.py
  Fungsi : Fungsi-fungsi utilitas dan validasi yang dipakai
           bersama di seluruh bagian aplikasi
============================================================
"""

import re
from datetime import datetime
from typing import Optional


# ============================================================
#  VALIDASI EMAIL
# ============================================================
def validasiFormatEmail(email: str) -> bool:
    """
    Memeriksa apakah string email memiliki format yang valid
    menggunakan pola regex standar RFC 5322 (sederhana).

    Args:
        email: String email yang akan divalidasi

    Returns:
        True jika format valid, False jika tidak
    """
    if not email or not isinstance(email, str):
        return False
    # Pola: nama@domain.tld — minimal 1 char sebelum @, domain, dan tld
    pola_email = r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"
    return bool(re.match(pola_email, email.strip()))


# ============================================================
#  VALIDASI KATA SANDI
# ============================================================
def validasiKekuatanKataSandi(kataSandi: str, panjangMinimal: int = 8) -> dict:
    """
    Memeriksa apakah kata sandi memenuhi syarat keamanan minimal:
      - Panjang minimal (default 8 karakter)
      - Mengandung huruf besar
      - Mengandung huruf kecil
      - Mengandung angka

    Args:
        kataSandi    : Kata sandi yang akan diperiksa
        panjangMinimal: Jumlah karakter minimum (default: 8)

    Returns:
        dict dengan key 'valid' (bool) dan 'pesan' (str penjelasan)
    """
    if not kataSandi or len(kataSandi) < panjangMinimal:
        return {
            "valid": False,
            "pesan": f"Kata sandi minimal {panjangMinimal} karakter."
        }

    daftarKesalahan = []

    if not re.search(r"[A-Z]", kataSandi):
        daftarKesalahan.append("minimal 1 huruf kapital")
    if not re.search(r"[a-z]", kataSandi):
        daftarKesalahan.append("minimal 1 huruf kecil")
    if not re.search(r"\d", kataSandi):
        daftarKesalahan.append("minimal 1 angka")

    if daftarKesalahan:
        return {
            "valid": False,
            "pesan": "Kata sandi harus mengandung: " + ", ".join(daftarKesalahan) + "."
        }

    return {"valid": True, "pesan": "Kata sandi memenuhi syarat keamanan."}


# ============================================================
#  VALIDASI NOMINAL UANG
# ============================================================
def validasiNominalUang(nilai) -> dict:
    """
    Memastikan nominal transaksi/anggaran adalah angka positif
    yang masuk akal (tidak negatif, tidak nol, tidak terlalu besar).

    Args:
        nilai: Nilai yang akan divalidasi (bisa str atau number)

    Returns:
        dict dengan key 'valid' (bool), 'nilai' (float), dan 'pesan' (str)
    """
    try:
        nominalFloat = float(nilai)
    except (TypeError, ValueError):
        return {
            "valid": False,
            "nilai": 0.0,
            "pesan": "Nominal harus berupa angka yang valid."
        }

    if nominalFloat <= 0:
        return {
            "valid": False,
            "nilai": 0.0,
            "pesan": "Nominal harus lebih besar dari 0 (nol)."
        }

    # Batas maksimal 999 triliun (sesuai tipe DECIMAL(15,2) di database)
    BATAS_MAKSIMAL_NOMINAL = 999_999_999_999_999.99
    if nominalFloat > BATAS_MAKSIMAL_NOMINAL:
        return {
            "valid": False,
            "nilai": 0.0,
            "pesan": "Nominal melebihi batas maksimum yang diizinkan sistem."
        }

    return {"valid": True, "nilai": nominalFloat, "pesan": "Nominal valid."}


# ============================================================
#  VALIDASI FORMAT TANGGAL
# ============================================================
def validasiFormatTanggal(tanggalStr: str, format_tgl: str = "%Y-%m-%d") -> dict:
    """
    Memeriksa dan mengurai string tanggal ke objek datetime.date.

    Args:
        tanggalStr : String tanggal, contoh: "2024-07-15"
        format_tgl : Format yang diharapkan (default: YYYY-MM-DD)

    Returns:
        dict dengan key 'valid' (bool), 'tanggal' (date obj), dan 'pesan' (str)
    """
    if not tanggalStr or not isinstance(tanggalStr, str):
        return {
            "valid": False,
            "tanggal": None,
            "pesan": "Tanggal tidak boleh kosong."
        }

    try:
        objTanggal = datetime.strptime(tanggalStr.strip(), format_tgl).date()

        # Pastikan tanggal tidak di masa depan yang terlalu jauh (lebih dari 1 hari ke depan)
        selisihHari = (objTanggal - datetime.utcnow().date()).days
        if selisihHari > 1:
            return {
                "valid": False,
                "tanggal": None,
                "pesan": "Tanggal transaksi tidak boleh lebih dari hari ini."
            }

        return {"valid": True, "tanggal": objTanggal, "pesan": "Format tanggal valid."}

    except ValueError:
        return {
            "valid": False,
            "tanggal": None,
            "pesan": f"Format tanggal salah. Gunakan format: {format_tgl} (contoh: 2024-07-15)."
        }


# ============================================================
#  FORMAT RUPIAH
# ============================================================
def formatRupiah(nominal: float) -> str:
    """
    Mengubah angka menjadi format mata uang Rupiah Indonesia.
    Contoh: 1500000.0 → 'Rp 1.500.000,00'

    Args:
        nominal: Nilai uang dalam float

    Returns:
        String dalam format Rupiah
    """
    try:
        # Format dengan pemisah ribuan titik (.) dan desimal koma (,)
        bagianBulat    = int(nominal)
        bagianDesimal  = round((nominal - bagianBulat) * 100)
        formatBulat    = f"{bagianBulat:,}".replace(",", ".")
        return f"Rp {formatBulat},{bagianDesimal:02d}"
    except (TypeError, ValueError):
        return "Rp 0,00"


# ============================================================
#  BUAT RESPONS API STANDAR
# ============================================================
def buatResponAPI(
    berhasil: bool,
    pesan: str,
    data: Optional[dict] = None,
    kode_status: int = 200
) -> tuple:
    """
    Membuat struktur respons JSON yang konsisten untuk semua endpoint.

    Args:
        berhasil    : True jika operasi sukses, False jika gagal
        pesan       : Pesan deskriptif untuk ditampilkan ke klien
        data        : Data payload (opsional)
        kode_status : HTTP status code (default: 200)

    Returns:
        Tuple (dict_respons, kode_status) siap dikembalikan oleh Flask
    """
    respons = {
        "berhasil":  berhasil,
        "pesan":     pesan,
        "timestamp": datetime.utcnow().isoformat() + "Z",
    }
    if data is not None:
        respons["data"] = data

    return respons, kode_status
