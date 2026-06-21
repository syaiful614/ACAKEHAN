"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : main.py
  Fungsi : Entry point utama aplikasi FastAPI
           - Inisialisasi app
           - Konfigurasi middleware (CORS, Exception Handler)
           - Pendaftaran semua router
           - Pembuatan tabel database saat startup
============================================================
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError

from app.config.pengaturan import ambilPengaturan
from app.config.database import buatSemuaTabel
from app.routes.rute_api import routerUtama

cfg = ambilPengaturan()


# ============================================================
#  LIFESPAN: Aksi Startup & Shutdown
# ============================================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Context manager untuk mengelola lifecycle aplikasi.
    Kode sebelum 'yield' dijalankan saat startup.
    Kode setelah 'yield' dijalankan saat shutdown.
    """
    # ── STARTUP ─────────────────────────────────────────────
    print(f"\n{'='*55}")
    print(f"  🚀 {cfg.NAMA_APLIKASI} v{cfg.VERSI_APLIKASI} — Mulai...")
    print(f"  📦 Lingkungan : {cfg.LINGKUNGAN}")
    print(f"  🔧 Mode Debug : {cfg.MODE_DEBUG}")
    print(f"{'='*55}\n")

    # Buat semua tabel database yang belum ada
    buatSemuaTabel()
    print("[✓] Database siap digunakan.\n")

    yield   # Aplikasi berjalan di sini

    # ── SHUTDOWN ─────────────────────────────────────────────
    print(f"\n[INFO] {cfg.NAMA_APLIKASI} dimatikan. Sampai jumpa!")


# ============================================================
#  INISIALISASI APLIKASI FASTAPI
# ============================================================
app = FastAPI(
    title         = f"{cfg.NAMA_APLIKASI} API",
    description   = """
## Acakehan — Aplikasi Catatan Keuangan Harian

Backend API untuk aplikasi mobile pencatatan keuangan pribadi.

### Fitur Utama
- 🔐 **Autentikasi JWT** — Registrasi, Login, Profil
- 💰 **Transaksi** — Catat pemasukan & pengeluaran harian
- 📊 **Dashboard** — Ringkasan keuangan, grafik tren, status anggaran
- 🔔 **Notifikasi Otomatis** — Peringatan saat anggaran mencapai 80%

### Cara Menggunakan API
1. Daftar akun di `POST /api/v1/auth/daftar`
2. Login di `POST /api/v1/auth/masuk` untuk mendapatkan token
3. Klik tombol **Authorize** di kanan atas dan masukkan: `Bearer <token_anda>`
4. Akses endpoint yang dilindungi 🔒
    """,
    version       = cfg.VERSI_APLIKASI,
    lifespan      = lifespan,
    docs_url      = "/docs",        # Swagger UI: http://localhost:8000/docs
    redoc_url     = "/redoc",       # ReDoc: http://localhost:8000/redoc
    openapi_url   = "/openapi.json",
)


# ============================================================
#  MIDDLEWARE: CORS (Cross-Origin Resource Sharing)
# ============================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins     = cfg.daftarAsalCors,  # Daftar domain yang diizinkan
    allow_credentials = True,
    allow_methods     = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers     = ["Authorization", "Content-Type", "Accept", "X-Request-ID"],
)


# ============================================================
#  EXCEPTION HANDLER: Validasi Input (Pydantic)
# ============================================================
@app.exception_handler(RequestValidationError)
async def tanganiGalatValidasi(request: Request, galat: RequestValidationError):
    """
    Mengubah format error validasi Pydantic menjadi respons JSON
    yang lebih ramah dan konsisten dengan standar API Acakehan.

    Contoh error yang ditangani:
        - Field wajib kosong
        - Tipe data salah (string di field angka)
        - Nilai di luar rentang yang diizinkan
        - Format email tidak valid
    """
    # Kumpulkan semua pesan error dari setiap field yang bermasalah
    daftarKesalahan = []
    for kesalahan in galat.errors():
        lokasiField = " → ".join(str(l) for l in kesalahan["loc"] if l != "body")
        pesanError  = kesalahan["msg"].replace("Value error, ", "")
        daftarKesalahan.append(f"{lokasiField}: {pesanError}" if lokasiField else pesanError)

    pesanUtama = (
        daftarKesalahan[0] if len(daftarKesalahan) == 1
        else f"{len(daftarKesalahan)} kesalahan validasi ditemukan: " +
             "; ".join(daftarKesalahan[:3])   # Tampilkan max 3 error pertama
    )

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "berhasil":          False,
            "pesan":             pesanUtama,
            "kode":              "VALIDASI_GAGAL",
            "detailKesalahan":   daftarKesalahan,
        }
    )


# ============================================================
#  EXCEPTION HANDLER: Error Server Umum
# ============================================================
@app.exception_handler(Exception)
async def tanganiGalatServer(request: Request, galat: Exception):
    """Menangani exception tak terduga agar respons tetap berformat JSON."""
    print(f"[ERROR TIDAK TERDUGA] {request.method} {request.url}: {str(galat)}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "berhasil": False,
            "pesan":    "Terjadi kesalahan internal pada server. "
                        "Tim kami sedang menangani masalah ini.",
            "kode":     "KESALAHAN_SERVER"
        }
    )


# ============================================================
#  DAFTARKAN SEMUA ROUTER
# ============================================================
app.include_router(routerUtama)


# ============================================================
#  ROUTE ROOT: Redirect ke Dokumentasi
# ============================================================
@app.get("/", include_in_schema=False)
def ruteRoot():
    """Redirect ke halaman dokumentasi Swagger."""
    from fastapi.responses import RedirectResponse
    return RedirectResponse(url="/docs")


# ============================================================
#  JALANKAN APLIKASI (Mode Development)
# ============================================================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host      = "0.0.0.0",
        port      = 8000,
        reload    = cfg.MODE_DEBUG,     # Auto-reload saat file berubah (mode dev)
        log_level = "debug" if cfg.MODE_DEBUG else "info",
    )
