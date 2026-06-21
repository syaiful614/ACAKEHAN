"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : controllers/controller_autentikasi.py
  Fungsi : Endpoint Registrasi & Login Pengguna
  Pola   : MVC — Layer Controller
  Metode : POST /api/auth/daftar
           POST /api/auth/masuk
           POST /api/auth/keluar
============================================================
"""

from flask import Blueprint, request, jsonify, g
from datetime import datetime, timezone

# Import ekstensi dan modul internal
from extensions import db, bcrypt
from models.model_database import Pengguna
from middleware.autentikasi_jwt import hasilkan_token_jwt, wajib_login
from utils.pembantu import (
    validasiFormatEmail,
    validasiKekuatanKataSandi,
    buatResponAPI
)
from config.konfigurasi import KonfigurasiUtama as Konfigurasi


# Blueprint untuk mengelompokkan semua route autentikasi
routerAutentikasi = Blueprint("autentikasi", __name__, url_prefix="/api/auth")


# ============================================================
#  ENDPOINT: POST /api/auth/daftar
#  Fungsi  : Registrasi akun pengguna baru
# ============================================================
@routerAutentikasi.route("/daftar", methods=["POST"])
def daftarAkunBaru():
    """
    Mendaftarkan pengguna baru ke dalam sistem Acakehan.

    Body JSON yang diharapkan:
        {
            "namaLengkap"  : "Budi Santoso",
            "email"        : "budi@email.com",
            "kataSandi"    : "KataSandi123",
            "konfirmasiKataSandi": "KataSandi123",
            "nomorTelepon" : "08123456789"  (opsional)
        }

    Alur Proses:
        1. Validasi kelengkapan field wajib
        2. Validasi format email
        3. Validasi kekuatan kata sandi
        4. Periksa konfirmasi kata sandi cocok
        5. Cek apakah email sudah terdaftar (duplikat)
        6. Hash kata sandi menggunakan bcrypt
        7. Simpan pengguna baru ke database
        8. Generate token JWT otomatis (langsung login setelah daftar)
        9. Kembalikan respons sukses + token
    """
    try:
        # ── Langkah 1: Ambil dan periksa body request ──────────────
        dataRequest = request.get_json(silent=True)

        if not dataRequest:
            return buatResponAPI(
                berhasil=False,
                pesan="Body request tidak valid atau bukan format JSON.",
                kode_status=400
            )

        # Ekstrak field dari body request
        namaLengkap           = dataRequest.get("namaLengkap",           "").strip()
        email                 = dataRequest.get("email",                  "").strip().lower()
        kataSandi             = dataRequest.get("kataSandi",              "")
        konfirmasiKataSandi   = dataRequest.get("konfirmasiKataSandi",   "")
        nomorTelepon          = dataRequest.get("nomorTelepon",           "").strip() or None

        # ── Langkah 2: Validasi field wajib tidak boleh kosong ──────
        fieldKosong = []
        if not namaLengkap:         fieldKosong.append("namaLengkap")
        if not email:               fieldKosong.append("email")
        if not kataSandi:           fieldKosong.append("kataSandi")
        if not konfirmasiKataSandi: fieldKosong.append("konfirmasiKataSandi")

        if fieldKosong:
            return buatResponAPI(
                berhasil=False,
                pesan=f"Field berikut wajib diisi: {', '.join(fieldKosong)}.",
                kode_status=422
            )

        # ── Langkah 3: Validasi panjang nama ────────────────────────
        if len(namaLengkap) < 3 or len(namaLengkap) > 100:
            return buatResponAPI(
                berhasil=False,
                pesan="Nama lengkap harus antara 3 hingga 100 karakter.",
                kode_status=422
            )

        # ── Langkah 4: Validasi format email ────────────────────────
        if not validasiFormatEmail(email):
            return buatResponAPI(
                berhasil=False,
                pesan="Format email tidak valid. Contoh yang benar: nama@domain.com",
                kode_status=422
            )

        # ── Langkah 5: Validasi kekuatan kata sandi ─────────────────
        hasilValidasiKataSandi = validasiKekuatanKataSandi(
            kataSandi,
            panjangMinimal=Konfigurasi.PANJANG_MIN_KATA_SANDI
        )
        if not hasilValidasiKataSandi["valid"]:
            return buatResponAPI(
                berhasil=False,
                pesan=hasilValidasiKataSandi["pesan"],
                kode_status=422
            )

        # ── Langkah 6: Periksa apakah konfirmasi kata sandi cocok ───
        if kataSandi != konfirmasiKataSandi:
            return buatResponAPI(
                berhasil=False,
                pesan="Kata sandi dan konfirmasi kata sandi tidak cocok.",
                kode_status=422
            )

        # ── Langkah 7: Periksa duplikasi email di database ──────────
        penggunaExisting = Pengguna.query.filter_by(email=email).first()
        if penggunaExisting:
            return buatResponAPI(
                berhasil=False,
                pesan=f"Email '{email}' sudah terdaftar. "
                       "Gunakan email lain atau login dengan akun yang ada.",
                kode_status=409   # 409 Conflict
            )

        # ── Langkah 8: Hash kata sandi menggunakan bcrypt ───────────
        # bcrypt.generate_password_hash() secara otomatis menambahkan
        # salt acak ke dalam hash, sehingga aman dari serangan rainbow table.
        # Nilai LOG_ROUNDS = 12 berarti 2^12 = 4096 iterasi hashing.
        passwordHashTerenkripsi = bcrypt.generate_password_hash(
            kataSandi,
            rounds=Konfigurasi.BCRYPT_LOG_ROUNDS
        ).decode("utf-8")

        # ── Langkah 9: Buat dan simpan objek Pengguna baru ──────────
        penggunaBaru = Pengguna(
            namaLengkap  = namaLengkap,
            email        = email,
            passwordHash = passwordHashTerenkripsi,
            nomorTelepon = nomorTelepon,
            tanggalDaftar = datetime.now(timezone.utc),
            statusAktif  = 1,
            peranUser    = "pengguna",
        )

        db.session.add(penggunaBaru)
        db.session.flush()   # Flush untuk mendapatkan pengguna_id sebelum commit

        # ── Langkah 10: Generate token JWT (auto-login setelah daftar) ──
        dataToken = hasilkan_token_jwt(
            pengguna_id = penggunaBaru.pengguna_id,
            email       = penggunaBaru.email,
            peran       = penggunaBaru.peranUser
        )

        db.session.commit()  # Commit semua perubahan ke database

        return buatResponAPI(
            berhasil    = True,
            pesan       = f"Akun berhasil dibuat! Selamat datang di Acakehan, {namaLengkap}.",
            data        = {
                "pengguna": penggunaBaru.ke_dict(),
                "token":    dataToken,
            },
            kode_status = 201   # 201 Created
        )

    except Exception as galat:
        # Rollback transaksi database jika terjadi error tak terduga
        db.session.rollback()
        # Catat error ke log server (di produksi gunakan logger, bukan print)
        print(f"[ERROR] daftarAkunBaru: {str(galat)}")
        return buatResponAPI(
            berhasil    = False,
            pesan       = "Terjadi kesalahan pada server saat memproses pendaftaran. "
                          "Silakan coba lagi beberapa saat.",
            kode_status = 500
        )


# ============================================================
#  ENDPOINT: POST /api/auth/masuk
#  Fungsi  : Login pengguna yang sudah terdaftar
# ============================================================
@routerAutentikasi.route("/masuk", methods=["POST"])
def masukAkun():
    """
    Mengautentikasi pengguna dan mengembalikan token JWT.

    Body JSON:
        {
            "email"    : "budi@email.com",
            "kataSandi": "KataSandi123"
        }
    """
    try:
        dataRequest = request.get_json(silent=True)
        if not dataRequest:
            return buatResponAPI(
                berhasil=False,
                pesan="Body request tidak valid.",
                kode_status=400
            )

        email     = dataRequest.get("email",     "").strip().lower()
        kataSandi = dataRequest.get("kataSandi", "")

        # Validasi field wajib
        if not email or not kataSandi:
            return buatResponAPI(
                berhasil=False,
                pesan="Email dan kata sandi wajib diisi.",
                kode_status=422
            )

        # Cari pengguna berdasarkan email
        pengguna = Pengguna.query.filter_by(email=email).first()

        # PENTING: Gunakan pesan error yang sama untuk email/kata sandi salah
        # agar penyerang tidak bisa mengetahui apakah email terdaftar atau tidak
        pesanGagalLogin = "Email atau kata sandi yang Anda masukkan salah."

        if not pengguna:
            return buatResponAPI(
                berhasil=False,
                pesan=pesanGagalLogin,
                kode_status=401
            )

        # Periksa apakah akun masih aktif
        if not pengguna.statusAktif:
            return buatResponAPI(
                berhasil=False,
                pesan="Akun Anda telah dinonaktifkan. Hubungi administrator.",
                kode_status=403
            )

        # Verifikasi kata sandi dengan bcrypt
        # bcrypt.check_password_hash() membandingkan kata sandi asli
        # dengan hash yang tersimpan di database secara aman
        kataSandiValid = bcrypt.check_password_hash(pengguna.passwordHash, kataSandi)
        if not kataSandiValid:
            return buatResponAPI(
                berhasil=False,
                pesan=pesanGagalLogin,
                kode_status=401
            )

        # Update timestamp terakhir login
        pengguna.terakhirLogin = datetime.now(timezone.utc)

        # Generate token JWT baru
        dataToken = hasilkan_token_jwt(
            pengguna_id = pengguna.pengguna_id,
            email       = pengguna.email,
            peran       = pengguna.peranUser
        )

        db.session.commit()

        return buatResponAPI(
            berhasil = True,
            pesan    = f"Selamat datang kembali, {pengguna.namaLengkap}!",
            data     = {
                "pengguna": pengguna.ke_dict(),
                "token":    dataToken,
            }
        )

    except Exception as galat:
        db.session.rollback()
        print(f"[ERROR] masukAkun: {str(galat)}")
        return buatResponAPI(
            berhasil    = False,
            pesan       = "Terjadi kesalahan pada server saat proses login.",
            kode_status = 500
        )


# ============================================================
#  ENDPOINT: POST /api/auth/keluar
#  Fungsi  : Logout (invalidasi token di sisi klien)
# ============================================================
@routerAutentikasi.route("/keluar", methods=["POST"])
@wajib_login
def keluarAkun():
    """
    Endpoint logout. Karena JWT bersifat stateless, logout dilakukan
    di sisi klien dengan menghapus token. Di sini kita hanya
    mengembalikan konfirmasi bahwa logout berhasil.

    Catatan untuk pengembangan lanjutan:
        Untuk invalidasi token server-side, implementasikan
        daftar hitam (blacklist) token menggunakan Redis.
    """
    namaPengguna = g.pengguna_aktif.namaLengkap
    return buatResponAPI(
        berhasil = True,
        pesan    = f"Berhasil keluar. Sampai jumpa, {namaPengguna}! "
                   "Hapus token dari penyimpanan lokal perangkat Anda."
    )
