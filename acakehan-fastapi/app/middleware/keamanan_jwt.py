"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : app/middleware/keamanan_jwt.py
  Fungsi : Generate token JWT, dependency FastAPI untuk
           memvalidasi token pada setiap request yang dilindungi
============================================================
"""

from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError, ExpiredSignatureError
from sqlalchemy.orm import Session

from app.config.database import ambilSesiDB
from app.config.pengaturan import ambilPengaturan
from app.models.model_db import Pengguna

# Konfigurasi skema keamanan Bearer Token untuk dokumentasi Swagger otomatis
skemaBearer = HTTPBearer(
    scheme_name="JWT Bearer",
    description="Masukkan token akses JWT. Format: **Bearer &lt;token&gt;**",
    auto_error=False,  # Kita tangani error secara manual agar pesan lebih informatif
)

cfg = ambilPengaturan()


# ============================================================
#  FUNGSI: Hasilkan Token JWT
# ============================================================
def hasilkanTokenJWT(penggunaId: int, email: str, peran: str) -> dict:
    """
    Membuat pasangan token JWT (akses + refresh) untuk pengguna
    yang berhasil login atau baru mendaftar.

    Args:
        penggunaId : ID unik pengguna dari database
        email      : Email pengguna (disertakan di payload)
        peran      : Peran akun ('pengguna' atau 'admin')

    Returns:
        Dictionary berisi tokenAkses, tokenRefresh, tipeToken, masaBerlakuDetik
    """
    sekarang = datetime.now(timezone.utc)

    # ── Payload Token AKSES (berlaku N jam sesuai konfigurasi) ───
    payloadAkses = {
        "sub":       str(penggunaId),   # Subject — ID pengguna (selalu string)
        "email":     email,
        "peran":     peran,
        "tipeToken": "akses",
        "iat":       sekarang,          # Issued At
        "exp":       sekarang + timedelta(hours=cfg.JWT_JAM_KADALUARSA_AKSES),
    }

    # ── Payload Token REFRESH (berlaku N hari) ───────────────────
    payloadRefresh = {
        "sub":       str(penggunaId),
        "tipeToken": "refresh",
        "iat":       sekarang,
        "exp":       sekarang + timedelta(days=cfg.JWT_HARI_KADALUARSA_REFRESH),
    }

    tokenAkses   = jwt.encode(payloadAkses,   cfg.JWT_KUNCI_RAHASIA, algorithm=cfg.JWT_ALGORITMA)
    tokenRefresh = jwt.encode(payloadRefresh, cfg.JWT_KUNCI_RAHASIA, algorithm=cfg.JWT_ALGORITMA)

    return {
        "tokenAkses":       tokenAkses,
        "tokenRefresh":     tokenRefresh,
        "tipeToken":        "Bearer",
        "masaBerlakuDetik": cfg.JWT_JAM_KADALUARSA_AKSES * 3600,
    }


# ============================================================
#  DEPENDENCY: Ambil Pengguna Aktif dari Token JWT
# ============================================================
def ambilPenggunaAktif(
    kredensial: Optional[HTTPAuthorizationCredentials] = Depends(skemaBearer),
    db:         Session = Depends(ambilSesiDB),
) -> Pengguna:
    """
    FastAPI Dependency yang memvalidasi token JWT dan mengembalikan
    objek Pengguna yang sedang login.

    Cara pakai di endpoint:
        @router.post("/transaksi")
        def tambahTransaksi(
            pengguna: Pengguna = Depends(ambilPenggunaAktif),
            db: Session = Depends(ambilSesiDB)
        ):
            ...

    Alur validasi:
        1. Periksa header Authorization tersedia
        2. Decode & verifikasi signature JWT
        3. Periksa apakah token sudah kedaluwarsa
        4. Pastikan tipe token adalah 'akses' (bukan 'refresh')
        5. Ambil pengguna dari database berdasarkan ID di payload
        6. Pastikan akun masih aktif
    """
    # Pengecualian standar yang akan dilempar jika validasi gagal
    def lemparGalatAuth(pesan: str, kode: str = "AUTH_GAGAL") -> HTTPException:
        return HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"berhasil": False, "pesan": pesan, "kode": kode},
            headers={"WWW-Authenticate": "Bearer"},
        )

    # ── Langkah 1: Periksa token ada di header ───────────────────
    if not kredensial or not kredensial.credentials:
        raise lemparGalatAuth(
            pesan="Token autentikasi tidak ditemukan. Harap login terlebih dahulu.",
            kode="TOKEN_TIDAK_ADA"
        )

    tokenMentah = kredensial.credentials

    try:
        # ── Langkah 2 & 3: Decode + verifikasi (jose otomatis cek exp) ─
        payload = jwt.decode(
            tokenMentah,
            cfg.JWT_KUNCI_RAHASIA,
            algorithms=[cfg.JWT_ALGORITMA]
        )

        # ── Langkah 4: Pastikan ini token AKSES bukan REFRESH ────────
        if payload.get("tipeToken") != "akses":
            raise lemparGalatAuth(
                pesan="Tipe token tidak valid. Gunakan token akses, bukan token refresh.",
                kode="TIPE_TOKEN_SALAH"
            )

        # Ambil ID pengguna dari payload
        penggunaIdStr: Optional[str] = payload.get("sub")
        if not penggunaIdStr:
            raise lemparGalatAuth(pesan="Payload token tidak lengkap.", kode="TOKEN_TIDAK_VALID")

    except ExpiredSignatureError:
        # Token sudah kedaluwarsa — pengguna harus login ulang
        raise lemparGalatAuth(
            pesan="Sesi Anda telah berakhir. Silakan login kembali untuk melanjutkan.",
            kode="TOKEN_KADALUARSA"
        )
    except JWTError as galat:
        raise lemparGalatAuth(
            pesan=f"Token tidak valid: {str(galat)}",
            kode="TOKEN_RUSAK"
        )

    # ── Langkah 5: Cari pengguna di database ─────────────────────
    pengguna = db.query(Pengguna).filter(
        Pengguna.penggunaId == int(penggunaIdStr)
    ).first()

    if not pengguna:
        raise lemparGalatAuth(
            pesan="Akun tidak ditemukan. Mungkin akun sudah dihapus.",
            kode="AKUN_TIDAK_ADA"
        )

    # ── Langkah 6: Pastikan akun masih aktif ─────────────────────
    if not pengguna.statusAktif:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "berhasil": False,
                "pesan":    "Akun Anda telah dinonaktifkan. Hubungi administrator.",
                "kode":     "AKUN_NONAKTIF"
            }
        )

    return pengguna


def ambilPenggunaAdmin(
    pengguna: Pengguna = Depends(ambilPenggunaAktif)
) -> Pengguna:
    """
    Dependency tambahan: pastikan pengguna yang login adalah Admin.
    Selalu gunakan SETELAH ambilPenggunaAktif.

    Cara pakai:
        @router.get("/admin/laporan")
        def laporanAdmin(pengguna: Pengguna = Depends(ambilPenggunaAdmin)):
            ...
    """
    if pengguna.peranUser != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "berhasil": False,
                "pesan":    "Akses ditolak. Halaman ini hanya untuk administrator.",
                "kode":     "BUKAN_ADMIN"
            }
        )
    return pengguna
