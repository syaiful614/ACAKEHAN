"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : app/controllers/controller_kategori.py
  Fungsi : Logika bisnis untuk pengambilan daftar Kategori
  Pola   : MVC — Layer Controller
============================================================
"""

from typing import Optional, List
from sqlalchemy.orm import Session

from app.models.model_db import Kategori, Pengguna
from app.schemas.skema_data import SkemaDataKategori


def kontrolerDaftarKategori(
    pengguna: Pengguna,
    db: Session,
    tipe: Optional[str] = None,
) -> List[SkemaDataKategori]:
    """
    Mengambil daftar kategori yang bisa diakses pengguna:
    kategori global (penggunaId NULL) ditambah kategori custom miliknya sendiri.
    """
    query = db.query(Kategori).filter(
        (Kategori.penggunaId == pengguna.penggunaId) |
        (Kategori.penggunaId.is_(None))
    )

    if tipe in ("pemasukan", "pengeluaran"):
        query = query.filter(Kategori.tipeKategori == tipe)

    daftarKategori = query.order_by(Kategori.namaKategori.asc()).all()

    return [
        SkemaDataKategori(
            kategoriId   = k.kategoriId,
            namaKategori = k.namaKategori,
            ikonKategori = k.ikonKategori,
            tipeKategori = k.tipeKategori,
            adalahGlobal = k.penggunaId is None,
        )
        for k in daftarKategori
    ]