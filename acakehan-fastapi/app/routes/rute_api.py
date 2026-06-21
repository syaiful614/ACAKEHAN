"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : app/routes/rute_api.py
  Fungsi : Definisi semua endpoint API — menghubungkan
           HTTP request dengan controller yang tepat.
  Pola   : MVC — Layer Route (View dalam FastAPI)

  Daftar Endpoint:
    AUTH:
      POST   /api/v1/auth/daftar      → Registrasi akun baru
      POST   /api/v1/auth/masuk       → Login & dapatkan token
      GET    /api/v1/auth/profil      → Profil pengguna aktif (🔒)
      POST   /api/v1/auth/keluar      → Logout (🔒)

    TRANSAKSI:
      POST   /api/v1/transaksi        → Catat transaksi baru (🔒)
      GET    /api/v1/transaksi        → Riwayat transaksi + filter (🔒)
      DELETE /api/v1/transaksi/{id}   → Hapus transaksi (🔒)

    DASHBOARD:
      GET    /api/v1/dashboard        → Data ringkasan dashboard (🔒)

    KATEGORI:
      GET    /api/v1/kategori         → Daftar kategori (🔒)

    SISTEM:
      GET    /api/v1/status           → Health check server

  🔒 = Memerlukan token JWT (Authorization: Bearer <token>)
============================================================
"""

from typing import Optional, List
from fastapi import APIRouter, Depends, Path, Query, status
from sqlalchemy.orm import Session

# Config & Dependencies
from app.config.database import ambilSesiDB
from app.models.model_db import Pengguna
from app.middleware.keamanan_jwt import ambilPenggunaAktif

# Schemas
from app.schemas.skema_data import (
    ResponAPI, SkemaRegistrasi, SkemaLogin,
    SkemaResponLogin, SkemaDataPengguna,
    SkemaTambahTransaksi, SkemaResponTransaksi,
    SkemaDataDashboard, SkemaDataKategori,
)

# Controllers
from app.controllers.controller_autentikasi import (
    kontrolerDaftarAkun,
    kontrolerMasukAkun,
    kontrolerAmbilProfil,
)
from app.controllers.controller_transaksi import (
    kontrolerTambahTransaksi,
    kontrolerDaftarTransaksi,
    kontrolerHapusTransaksi,
)
from app.controllers.controller_dashboard import (
    kontrolerAmbilDashboard,
)
from app.controllers.controller_kategori import (
    kontrolerDaftarKategori,
)


# ── Router utama dengan prefix /api/v1 ────────────────────────
routerUtama = APIRouter(prefix="/api/v1")


# ============================================================
#  TAG: Autentikasi
# ============================================================
routerAuth = APIRouter(prefix="/auth", tags=["🔐 Autentikasi"])


@routerAuth.post(
    "/daftar",
    response_model=ResponAPI[SkemaResponLogin],
    status_code=status.HTTP_201_CREATED,
    summary="Registrasi Akun Baru",
    description="""
    Mendaftarkan pengguna baru ke sistem Acakehan.

    **Aturan kata sandi:**
    - Minimal 8 karakter
    - Minimal 1 huruf kapital
    - Minimal 1 huruf kecil
    - Minimal 1 angka

    Setelah berhasil, token JWT akan otomatis diterbitkan.
    """,
)
def ruteDaftarAkun(
    dataRegistrasi: SkemaRegistrasi,
    db: Session = Depends(ambilSesiDB),
):
    """Endpoint registrasi — memanggil kontrolerDaftarAkun."""
    hasilRegistrasi = kontrolerDaftarAkun(dataRegistrasi, db)
    return ResponAPI[SkemaResponLogin](
        berhasil = True,
        pesan    = f"Selamat datang di Acakehan, {hasilRegistrasi.pengguna.namaLengkap}! "
                   "Akun berhasil dibuat.",
        data     = hasilRegistrasi,
    )


@routerAuth.post(
    "/masuk",
    response_model=ResponAPI[SkemaResponLogin],
    status_code=status.HTTP_200_OK,
    summary="Login Akun",
    description="Autentikasi pengguna dengan email dan kata sandi. Mengembalikan token JWT akses + refresh.",
)
def ruteMasukAkun(
    dataLogin: SkemaLogin,
    db: Session = Depends(ambilSesiDB),
):
    """Endpoint login — memanggil kontrolerMasukAkun."""
    hasilLogin = kontrolerMasukAkun(dataLogin, db)
    return ResponAPI[SkemaResponLogin](
        berhasil = True,
        pesan    = f"Selamat datang kembali, {hasilLogin.pengguna.namaLengkap}!",
        data     = hasilLogin,
    )


@routerAuth.get(
    "/profil",
    response_model=ResponAPI[SkemaDataPengguna],
    status_code=status.HTTP_200_OK,
    summary="Profil Pengguna Aktif 🔒",
    description="Mengambil data profil pengguna yang sedang login. **Memerlukan token JWT.**",
)
def ruteProfilPengguna(
    pengguna: Pengguna = Depends(ambilPenggunaAktif),
):
    """Endpoint profil — data pengguna aktif dari token JWT."""
    dataProfil = kontrolerAmbilProfil(pengguna)
    return ResponAPI[SkemaDataPengguna](
        berhasil = True,
        pesan    = "Data profil berhasil diambil.",
        data     = dataProfil,
    )


@routerAuth.post(
    "/keluar",
    response_model=ResponAPI,
    status_code=status.HTTP_200_OK,
    summary="Logout 🔒",
    description="""
    Endpoint logout. Karena JWT bersifat stateless, logout dilakukan di sisi klien
    dengan menghapus token dari penyimpanan lokal.

    **Catatan pengembangan lanjutan:** Untuk invalidasi server-side, implementasikan
    token blacklist menggunakan Redis.
    """,
)
def ruteKeluarAkun(
    pengguna: Pengguna = Depends(ambilPenggunaAktif),
):
    """Endpoint logout — konfirmasi dan instruksi hapus token di klien."""
    return ResponAPI(
        berhasil = True,
        pesan    = f"Berhasil keluar dari akun {pengguna.namaLengkap}. "
                   "Harap hapus token dari penyimpanan lokal perangkat Anda.",
    )


# ============================================================
#  TAG: Transaksi
# ============================================================
routerTransaksi = APIRouter(prefix="/transaksi", tags=["💰 Transaksi"])


@routerTransaksi.post(
    "",
    response_model=ResponAPI[SkemaResponTransaksi],
    status_code=status.HTTP_201_CREATED,
    summary="Catat Transaksi Baru 🔒",
    description="""
    Mencatat transaksi keuangan baru (pemasukan atau pengeluaran).

    **Fitur otomatis:**
    - Untuk transaksi **pengeluaran**: sistem memeriksa apakah total pengeluaran
      kategori ini sudah mencapai **80%** dari batas anggaran.
    - Jika ya dan notifikasi belum pernah dikirim bulan ini, **notifikasi peringatan**
      akan otomatis dibuat dan disertakan dalam respons.

    **Memerlukan token JWT.**
    """,
)
def ruteTambahTransaksi(
    dataBaru: SkemaTambahTransaksi,
    pengguna: Pengguna = Depends(ambilPenggunaAktif),
    db: Session = Depends(ambilSesiDB),
):
    """Endpoint catat transaksi baru."""
    hasilTransaksi = kontrolerTambahTransaksi(dataBaru, pengguna, db)

    # Susun pesan sukses — sertakan peringatan anggaran jika ada
    pesan = (
        f"Transaksi {dataBaru.tipeTransaksi} sebesar "
        f"Rp {float(dataBaru.jumlahNominal):,.0f} berhasil dicatat."
    )
    if (hasilTransaksi.anggaran and hasilTransaksi.anggaran.adaNotifikasi):
        pesan += f" ⚠️ {hasilTransaksi.anggaran.notifikasi['judul']}"

    return ResponAPI[SkemaResponTransaksi](
        berhasil = True,
        pesan    = pesan,
        data     = hasilTransaksi,
    )


@routerTransaksi.get(
    "",
    response_model=dict,
    status_code=status.HTTP_200_OK,
    summary="Riwayat Transaksi 🔒",
    description="""
    Mengambil riwayat transaksi pengguna dengan filter opsional dan pagination.

    **Filter yang tersedia:**
    - `tipe`: `pemasukan` atau `pengeluaran`
    - `bulan`: 1-12
    - `tahun`: format YYYY
    - `kategori_id`: ID kategori tertentu

    **Memerlukan token JWT.**
    """,
)
def ruteDaftarTransaksi(
    tipe:        Optional[str] = Query(None,  description="Filter tipe: 'pemasukan' atau 'pengeluaran'"),
    bulan:       Optional[int] = Query(None,  ge=1, le=12, description="Filter bulan (1-12)"),
    tahun:       Optional[int] = Query(None,  ge=2000,     description="Filter tahun (YYYY)"),
    kategori_id: Optional[int] = Query(None,  gt=0,        description="Filter ID kategori"),
    halaman:     int           = Query(1,     ge=1,        description="Nomor halaman (mulai 1)"),
    per_halaman: int           = Query(20,    ge=1, le=100, description="Jumlah data per halaman (max 100)"),
    pengguna:    Pengguna      = Depends(ambilPenggunaAktif),
    db:          Session       = Depends(ambilSesiDB),
):
    """Endpoint daftar riwayat transaksi dengan filter dan pagination."""
    hasilQuery = kontrolerDaftarTransaksi(
        pengguna   = pengguna,
        db         = db,
        tipe       = tipe,
        bulan      = bulan,
        tahun      = tahun,
        kategoriId = kategori_id,
        halaman    = halaman,
        perHalaman = per_halaman,
    )

    return {
        "berhasil":  True,
        "pesan":     f"Berhasil mengambil {len(hasilQuery['transaksi'])} transaksi.",
        "data":      [t.model_dump() for t in hasilQuery["transaksi"]],
        "pagination": {
            "totalData":              hasilQuery["totalData"],
            "halaman":                hasilQuery["halaman"],
            "perHalaman":             hasilQuery["perHalaman"],
            "totalHalaman":           hasilQuery["totalHalaman"],
            "adaHalamanBerikutnya":   hasilQuery["adaHalamanBerikutnya"],
        }
    }


@routerTransaksi.delete(
    "/{transaksiId}",
    response_model=ResponAPI,
    status_code=status.HTTP_200_OK,
    summary="Hapus Transaksi 🔒",
    description="""
    Menghapus transaksi secara lunak (*soft delete*).
    Data tidak benar-benar dihapus dari database — hanya ditandai sebagai terhapus
    sehingga tetap bisa diaudit jika diperlukan.

    **Memerlukan token JWT.**
    """,
)
def ruteHapusTransaksi(
    transaksiId: int = Path(..., gt=0, description="ID transaksi yang akan dihapus"),
    pengguna: Pengguna = Depends(ambilPenggunaAktif),
    db: Session = Depends(ambilSesiDB),
):
    """Endpoint hapus transaksi (soft delete)."""
    hasilHapus = kontrolerHapusTransaksi(transaksiId, pengguna, db)
    return ResponAPI(
        berhasil = True,
        pesan    = hasilHapus["pesanHapus"],
    )


# ============================================================
#  TAG: Dashboard
# ============================================================
routerDashboard = APIRouter(prefix="/dashboard", tags=["📊 Dashboard"])


@routerDashboard.get(
    "",
    response_model=ResponAPI[SkemaDataDashboard],
    status_code=status.HTTP_200_OK,
    summary="Data Dashboard Lengkap 🔒",
    description="""
    Mengambil semua data yang dibutuhkan halaman Dashboard dalam satu request:

    - **Ringkasan bulan ini**: total pemasukan, pengeluaran, dan saldo bersih
    - **Pengeluaran per kategori**: data untuk grafik Pie Chart
    - **Tren 6 bulan terakhir**: data untuk grafik Line Chart
    - **Status anggaran**: progress bar semua anggaran aktif bulan ini
    - **Badge notifikasi**: jumlah notifikasi yang belum dibaca

    **Memerlukan token JWT.**
    """,
)
def ruteDashboard(
    pengguna: Pengguna = Depends(ambilPenggunaAktif),
    db: Session = Depends(ambilSesiDB),
):
    """Endpoint dashboard — satu endpoint, semua data yang dibutuhkan."""
    dataDashboard = kontrolerAmbilDashboard(pengguna, db)
    return ResponAPI[SkemaDataDashboard](
        berhasil = True,
        pesan    = f"Data dashboard {pengguna.namaLengkap} berhasil dimuat.",
        data     = dataDashboard,
    )


# ============================================================
#  TAG: Kategori
# ============================================================
routerKategori = APIRouter(prefix="/kategori", tags=["📂 Kategori"])


@routerKategori.get(
    "",
    response_model=ResponAPI[List[SkemaDataKategori]],
    status_code=status.HTTP_200_OK,
    summary="Daftar Kategori 🔒",
    description="""
    Mengambil daftar kategori yang bisa digunakan pengguna untuk mencatat transaksi —
    gabungan kategori global dan kategori custom milik pengguna sendiri.

    **Filter opsional:** `tipe` = `pemasukan` atau `pengeluaran`

    **Memerlukan token JWT.**
    """,
)
def ruteDaftarKategori(
    tipe: Optional[str] = Query(None, description="Filter tipe: 'pemasukan' atau 'pengeluaran'"),
    pengguna: Pengguna = Depends(ambilPenggunaAktif),
    db: Session = Depends(ambilSesiDB),
):
    """Endpoint daftar kategori yang bisa diakses pengguna."""
    daftarKategori = kontrolerDaftarKategori(pengguna, db, tipe)
    return ResponAPI[List[SkemaDataKategori]](
        berhasil = True,
        pesan    = f"Berhasil mengambil {len(daftarKategori)} kategori.",
        data     = daftarKategori,
    )


# ============================================================
#  TAG: Sistem
# ============================================================
routerSistem = APIRouter(tags=["⚙️ Sistem"])


@routerSistem.get(
    "/status",
    status_code=status.HTTP_200_OK,
    summary="Health Check Server",
    description="Memeriksa apakah server dan koneksi database dalam kondisi normal.",
)
def ruteStatusServer():
    """Endpoint health check — tidak memerlukan autentikasi."""
    from app.config.database import periksaKoneksiDB
    from app.config.pengaturan import ambilPengaturan

    cfg = ambilPengaturan()
    dbOke = periksaKoneksiDB()

    return {
        "berhasil":       True,
        "namaAplikasi":   cfg.NAMA_APLIKASI,
        "versiAplikasi":  cfg.VERSI_APLIKASI,
        "lingkungan":     cfg.LINGKUNGAN,
        "statusDatabase": "terhubung" if dbOke else "tidak terhubung",
        "pesan":          "Server Acakehan berjalan normal." if dbOke
                          else "⚠️ Koneksi database bermasalah.",
    }


# ── Gabungkan semua sub-router ke routerUtama ─────────────────
routerUtama.include_router(routerAuth)
routerUtama.include_router(routerTransaksi)
routerUtama.include_router(routerDashboard)
routerUtama.include_router(routerKategori)
routerUtama.include_router(routerSistem)