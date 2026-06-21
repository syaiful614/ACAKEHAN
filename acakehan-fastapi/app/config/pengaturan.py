"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : app/config/pengaturan.py
  Fungsi : Konfigurasi terpusat — dibaca dari file .env
           menggunakan Pydantic Settings (type-safe & auto-validate)
============================================================
"""

from functools import lru_cache
from typing import List
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class PengaturanAplikasi(BaseSettings):
    """
    Semua konfigurasi aplikasi Acakehan.
    Nilai dibaca otomatis dari environment variable atau file .env.
    Pydantic akan memvalidasi tipe data secara otomatis saat startup.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,   # DB_HOST == db_host
        extra="ignore",         # Abaikan variabel .env yang tidak dikenali
    )

    # ── Identitas Aplikasi ──────────────────────────────────────
    NAMA_APLIKASI:    str = "Acakehan"
    VERSI_APLIKASI:   str = "1.0.0"
    MODE_DEBUG:       bool = False
    LINGKUNGAN:       str = "development"

    # ── Konfigurasi Database ────────────────────────────────────
    DB_HOST:          str = "localhost"
    DB_PORT:          int = 3306
    DB_NAMA:          str = "db_acakehan"
    DB_PENGGUNA:      str = "root"
    DB_KATA_SANDI:    str = ""
    DB_POOL_SIZE:     int = 10
    DB_MAX_OVERFLOW:  int = 20

    # ── Konfigurasi JWT ─────────────────────────────────────────
    JWT_KUNCI_RAHASIA:              str = "kunci-rahasia-default-GANTI-DI-PRODUKSI"
    JWT_ALGORITMA:                  str = "HS256"
    JWT_JAM_KADALUARSA_AKSES:       int = 24
    JWT_HARI_KADALUARSA_REFRESH:    int = 30

    # ── Bcrypt ──────────────────────────────────────────────────
    BCRYPT_ROUNDS:    int = 12

    # ── Aturan Anggaran ─────────────────────────────────────────
    BATAS_PERSEN_PERINGATAN:  float = 80.0
    BATAS_PERSEN_KRITIS:      float = 100.0

    # ── CORS ────────────────────────────────────────────────────
    ASAL_CORS_DIIZINKAN: str = "http://localhost:3000"

    # ── Property turunan (dihitung dari field lain) ─────────────

    @property
    def uriDatabase(self) -> str:
        """Bangun URI koneksi SQLAlchemy dari konfigurasi database."""
        return (
            f"mysql+pymysql://{self.DB_PENGGUNA}:{self.DB_KATA_SANDI}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAMA}"
            f"?charset=utf8mb4"
        )

    @property
    def daftarAsalCors(self) -> List[str]:
        """Ubah string CORS (dipisah koma) menjadi list."""
        return [asal.strip() for asal in self.ASAL_CORS_DIIZINKAN.split(",")]

    @property
    def modeProduksi(self) -> bool:
        return self.LINGKUNGAN.lower() == "production"


@lru_cache()
def ambilPengaturan() -> PengaturanAplikasi:
    """
    Singleton: hanya membuat instance PengaturanAplikasi sekali
    lalu menyimpannya di cache (@lru_cache).
    Gunakan fungsi ini di mana pun konfigurasi dibutuhkan.

    Contoh:
        from app.config.pengaturan import ambilPengaturan
        cfg = ambilPengaturan()
        print(cfg.NAMA_APLIKASI)
    """
    return PengaturanAplikasi()
