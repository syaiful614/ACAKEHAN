"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : app/controllers/controller_autentikasi.py
  Fungsi : Logika bisnis untuk Registrasi, Login, Logout
  Pola   : MVC — Layer Controller (Service Layer)
           Controller dipanggil oleh Route, bukan langsung dari request
============================================================
"""

from datetime import datetime, timezone
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.models.model_db import Pengguna
from app.schemas.skema_data import (
    SkemaRegistrasi, SkemaLogin,
    SkemaDataPengguna, SkemaToken, SkemaResponLogin
)
from app.middleware.keamanan_jwt import hasilkanTokenJWT
from app.utils.pembantu import hashKataSandi, verifikasiKataSandi


# ============================================================
#  CONTROLLER: Registrasi Akun Baru
# ============================================================
def kontrolerDaftarAkun(dataRegistrasi: SkemaRegistrasi, db: Session) -> SkemaResponLogin:
    """
    Mendaftarkan pengguna baru ke sistem Acakehan.

    Alur:
        1. Cek duplikasi email di database
        2. Hash kata sandi menggunakan bcrypt (12 rounds)
        3. Simpan objek Pengguna baru ke database
        4. Generate token JWT (akses + refresh)
        5. Kembalikan data pengguna + token

    Args:
        dataRegistrasi : Data tervalidasi dari SkemaRegistrasi (Pydantic)
        db             : Sesi database dari dependency injection

    Returns:
        SkemaResponLogin berisi data pengguna dan token JWT

    Raises:
        HTTPException 409 : Jika email sudah terdaftar
        HTTPException 500 : Jika terjadi error database tidak terduga
    """

    # ── Langkah 1: Cek duplikasi email ──────────────────────────
    emailSudahAda = db.query(Pengguna).filter(
        Pengguna.email == dataRegistrasi.email.lower()
    ).first()

    if emailSudahAda:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "berhasil": False,
                "pesan":    f"Email '{dataRegistrasi.email}' sudah terdaftar. "
                            "Gunakan email lain atau masuk dengan akun yang sudah ada.",
                "kode":     "EMAIL_DUPLIKAT"
            }
        )

    # ── Langkah 2: Hash kata sandi menggunakan bcrypt ────────────
    # Passlib bcrypt secara otomatis:
    #   - Menambahkan salt acak 128-bit unik per hash
    #   - Melakukan 2^12 = 4096 iterasi (rounds=12)
    # Ini membuat serangan brute-force dan rainbow table tidak praktis
    kataSandiTerHash = hashKataSandi(dataRegistrasi.kataSandi)

    # ── Langkah 3: Buat objek Pengguna dan simpan ke DB ─────────
    penggunaBaru = Pengguna(
        namaLengkap  = dataRegistrasi.namaLengkap.strip(),
        email        = dataRegistrasi.email.lower().strip(),
        passwordHash = kataSandiTerHash,
        nomorTelepon = dataRegistrasi.nomorTelepon,
        statusAktif  = True,
        peranUser    = "pengguna",
        tanggalDaftar = datetime.now(timezone.utc),
    )

    try:
        db.add(penggunaBaru)
        db.flush()   # Flush untuk mendapatkan penggunaId sebelum commit

        # ── Langkah 4: Generate token JWT ────────────────────────
        dataToken = hasilkanTokenJWT(
            penggunaId = penggunaBaru.penggunaId,
            email      = penggunaBaru.email,
            peran      = penggunaBaru.peranUser,
        )

        db.commit()
        db.refresh(penggunaBaru)

    except IntegrityError:
        # Menangani race condition: dua request registrasi email sama secara bersamaan
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "berhasil": False,
                "pesan":    "Email sudah digunakan. Silakan gunakan email lain.",
                "kode":     "EMAIL_DUPLIKAT"
            }
        )
    except Exception as galat:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "berhasil": False,
                "pesan":    "Terjadi kesalahan server saat menyimpan akun. Silakan coba lagi.",
                "kode":     "KESALAHAN_SERVER"
            }
        )

    # ── Langkah 5: Susun dan kembalikan respons ──────────────────
    return SkemaResponLogin(
        pengguna = SkemaDataPengguna.model_validate(penggunaBaru),
        token    = SkemaToken(**dataToken),
    )


# ============================================================
#  CONTROLLER: Login Pengguna
# ============================================================
def kontrolerMasukAkun(dataLogin: SkemaLogin, db: Session) -> SkemaResponLogin:
    """
    Mengautentikasi pengguna dan mengembalikan token JWT baru.

    Alur:
        1. Cari pengguna berdasarkan email
        2. Verifikasi kata sandi dengan bcrypt
        3. Periksa status akun
        4. Update timestamp terakhir login
        5. Generate dan kembalikan token JWT baru

    Args:
        dataLogin : Data tervalidasi dari SkemaLogin
        db        : Sesi database

    Returns:
        SkemaResponLogin berisi data pengguna dan token baru

    Raises:
        HTTPException 401 : Jika email/kata sandi salah
        HTTPException 403 : Jika akun dinonaktifkan
    """

    # ── Langkah 1: Cari pengguna berdasarkan email ───────────────
    pengguna = db.query(Pengguna).filter(
        Pengguna.email == dataLogin.email.lower().strip()
    ).first()

    # KEAMANAN: Gunakan pesan error yang SAMA untuk email tidak ada
    # dan kata sandi salah — mencegah attacker menebak email terdaftar
    pesanGagalLogin = (
        "Email atau kata sandi yang Anda masukkan salah. "
        "Periksa kembali dan coba lagi."
    )

    if not pengguna:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"berhasil": False, "pesan": pesanGagalLogin, "kode": "KREDENSIAL_SALAH"}
        )

    # ── Langkah 2: Verifikasi kata sandi dengan bcrypt ───────────
    # verifikasiKataSandi() menggunakan constant-time comparison
    # untuk mencegah timing attack
    if not verifikasiKataSandi(dataLogin.kataSandi, pengguna.passwordHash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"berhasil": False, "pesan": pesanGagalLogin, "kode": "KREDENSIAL_SALAH"}
        )

    # ── Langkah 3: Periksa status akun ──────────────────────────
    if not pengguna.statusAktif:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "berhasil": False,
                "pesan":    "Akun Anda telah dinonaktifkan. Hubungi administrator untuk bantuan.",
                "kode":     "AKUN_NONAKTIF"
            }
        )

    # ── Langkah 4: Update waktu terakhir login ───────────────────
    pengguna.terakhirLogin = datetime.now(timezone.utc)

    # ── Langkah 5: Generate token JWT baru ───────────────────────
    dataToken = hasilkanTokenJWT(
        penggunaId = pengguna.penggunaId,
        email      = pengguna.email,
        peran      = pengguna.peranUser,
    )

    db.commit()

    return SkemaResponLogin(
        pengguna = SkemaDataPengguna.model_validate(pengguna),
        token    = SkemaToken(**dataToken),
    )


# ============================================================
#  CONTROLLER: Profil Pengguna Aktif
# ============================================================
def kontrolerAmbilProfil(pengguna: Pengguna) -> SkemaDataPengguna:
    """
    Mengembalikan data profil pengguna yang sedang login.
    Digunakan di endpoint GET /auth/profil.
    """
    return SkemaDataPengguna.model_validate(pengguna)
