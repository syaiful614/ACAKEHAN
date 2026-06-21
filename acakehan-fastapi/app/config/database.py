"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : app/config/database.py
  Fungsi : Inisialisasi koneksi database SQLAlchemy,
           manajemen sesi, dan dependency injection untuk FastAPI
============================================================
"""

from typing import Generator
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, DeclarativeBase, Session
from sqlalchemy.pool import QueuePool

from app.config.pengaturan import ambilPengaturan

cfg = ambilPengaturan()


class ModelDasar(DeclarativeBase):
    pass


engineDatabase = create_engine(
    cfg.uriDatabase,
    poolclass=QueuePool,
    pool_size=cfg.DB_POOL_SIZE,
    max_overflow=cfg.DB_MAX_OVERFLOW,
    pool_pre_ping=True,
    pool_recycle=3600,
    echo=cfg.MODE_DEBUG,
)


SessionLokal = sessionmaker(
    bind=engineDatabase,
    autocommit=False,
    autoflush=False,
)


def ambilSesiDB() -> Generator[Session, None, None]:
    sesi = SessionLokal()
    try:
        yield sesi
        sesi.commit()
    except Exception:
        sesi.rollback()
        raise
    finally:
        sesi.close()


def buatSemuaTabel() -> None:
    ModelDasar.metadata.create_all(bind=engineDatabase)
    print("[DB] Semua tabel berhasil diinisialisasi.")


def periksaKoneksiDB() -> bool:
    try:
        with engineDatabase.connect() as koneksi:
            koneksi.execute(text("SELECT 1"))
        return True
    except Exception as galat:
        print(f"[DB ERROR] Koneksi database gagal: {str(galat)}")
        return False