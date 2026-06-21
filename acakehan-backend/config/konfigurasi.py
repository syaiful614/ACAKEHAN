"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : config/konfigurasi.py
  Fungsi : Konfigurasi global aplikasi (DB, JWT, dsb.)
============================================================
"""

import os
from datetime import timedelta


class KonfigurasiUtama:
    """
    Kelas konfigurasi utama aplikasi Acakehan.
    Semua nilai sensitif diambil dari environment variable
    agar tidak ter-hardcode di dalam kode sumber.
    """

    # ----- Konfigurasi Umum -----
    NAMA_APLIKASI    = "Acakehan"
    VERSI_APLIKASI   = "1.0.0"
    MODE_DEBUG       = os.getenv("MODE_DEBUG", "False").lower() == "true"

    # ----- Konfigurasi Database (MySQL / PostgreSQL) -----
    DB_HOST          = os.getenv("DB_HOST",     "localhost")
    DB_PORT          = int(os.getenv("DB_PORT", "3306"))
    DB_NAMA          = os.getenv("DB_NAMA",     "db_acakehan")
    DB_PENGGUNA      = os.getenv("DB_PENGGUNA", "root")
    DB_KATA_SANDI    = os.getenv("DB_KATA_SANDI", "")

    # URI koneksi SQLAlchemy
    SQLALCHEMY_DATABASE_URI = (
        f"mysql+pymysql://{DB_PENGGUNA}:{DB_KATA_SANDI}"
        f"@{DB_HOST}:{DB_PORT}/{DB_NAMA}?charset=utf8mb4"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ECHO = MODE_DEBUG  # Tampilkan query SQL saat mode debug aktif

    # ----- Konfigurasi JWT -----
    JWT_SECRET_KEY            = os.getenv("JWT_SECRET_KEY", "ganti-dengan-kunci-rahasia-acakehan-2024!")
    JWT_MASA_BERLAKU_AKSES    = timedelta(hours=int(os.getenv("JWT_JAM_AKSES",   "24")))
    JWT_MASA_BERLAKU_REFRESH  = timedelta(days=int(os.getenv("JWT_HARI_REFRESH", "30")))

    # ----- Konfigurasi Keamanan -----
    BCRYPT_LOG_ROUNDS         = 12    # Semakin tinggi, semakin aman (namun lebih lambat)
    PANJANG_MIN_KATA_SANDI    = 8     # Minimal 8 karakter untuk kata sandi

    # ----- Konfigurasi Anggaran -----
    # Persentase yang memicu notifikasi peringatan pertama
    BATAS_PERSEN_PERINGATAN   = 80.0
    # Persentase yang memicu notifikasi kritis (opsional, tahap berikutnya)
    BATAS_PERSEN_KRITIS       = 100.0

    # ----- Konfigurasi Notifikasi -----
    AKTIFKAN_PUSH_NOTIF       = os.getenv("AKTIFKAN_PUSH_NOTIF", "True").lower() == "true"
    FCM_SERVER_KEY            = os.getenv("FCM_SERVER_KEY", "")  # Firebase Cloud Messaging


class KonfigurasiPengembangan(KonfigurasiUtama):
    """Konfigurasi khusus mode pengembangan (development)."""
    MODE_DEBUG = True
    SQLALCHEMY_ECHO = True


class KonfigurasiProduksi(KonfigurasiUtama):
    """Konfigurasi khusus mode produksi (production)."""
    MODE_DEBUG = False
    SQLALCHEMY_ECHO = False
    BCRYPT_LOG_ROUNDS = 14  # Lebih aman di lingkungan produksi


# Peta konfigurasi berdasarkan nama environment
PETA_KONFIGURASI = {
    "pengembangan": KonfigurasiPengembangan,
    "produksi":     KonfigurasiProduksi,
    "default":      KonfigurasiPengembangan,
}
