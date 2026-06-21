"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : app.py
  Fungsi : Entry point aplikasi — inisialisasi Flask,
           ekstensi, dan pendaftaran semua Blueprint/Router
  Pola   : Application Factory Pattern
============================================================
"""

from flask import Flask, jsonify
from config.konfigurasi import PETA_KONFIGURASI
import os


def buatAplikasi(nama_env: str = "default") -> Flask:
    """
    Application Factory: membuat dan mengonfigurasi instance Flask.

    Args:
        nama_env: Nama lingkungan ('pengembangan', 'produksi', 'default')

    Returns:
        Instance Flask yang sudah dikonfigurasi dan siap dijalankan
    """
    app = Flask(__name__)

    # ── Muat konfigurasi berdasarkan environment ──────────────────
    konfigurasiDipilih = PETA_KONFIGURASI.get(nama_env, PETA_KONFIGURASI["default"])
    app.config.from_object(konfigurasiDipilih)

    # ── Inisialisasi ekstensi (import dari extensions.py) ─────────
    from extensions import db, bcrypt, jwt
    db.init_app(app)
    bcrypt.init_app(app)
    jwt.init_app(app)

    # ── Daftarkan semua Blueprint (Router) ────────────────────────
    from controllers.controller_autentikasi import routerAutentikasi
    from controllers.controller_transaksi   import routerTransaksi

    app.register_blueprint(routerAutentikasi)
    app.register_blueprint(routerTransaksi)

    # ── Handler error global ──────────────────────────────────────
    @app.errorhandler(404)
    def endpoint_tidak_ditemukan(galat):
        return jsonify({
            "berhasil": False,
            "pesan":    "Endpoint yang Anda akses tidak ditemukan.",
            "kode":     "ENDPOINT_TIDAK_ADA"
        }), 404

    @app.errorhandler(405)
    def metode_tidak_diizinkan(galat):
        return jsonify({
            "berhasil": False,
            "pesan":    "Metode HTTP tidak diizinkan untuk endpoint ini.",
            "kode":     "METODE_TIDAK_VALID"
        }), 405

    @app.errorhandler(500)
    def kesalahan_server(galat):
        return jsonify({
            "berhasil": False,
            "pesan":    "Terjadi kesalahan internal pada server. "
                        "Silakan hubungi administrator.",
            "kode":     "KESALAHAN_SERVER"
        }), 500

    # ── Route health check ────────────────────────────────────────
    @app.route("/api/status", methods=["GET"])
    def statusServer():
        """Endpoint untuk memverifikasi server berjalan dengan normal."""
        return jsonify({
            "berhasil":     True,
            "namaAplikasi": app.config["NAMA_APLIKASI"],
            "versi":        app.config["VERSI_APLIKASI"],
            "pesan":        "Server Acakehan berjalan normal."
        })

    return app


# ── Titik masuk utama aplikasi ────────────────────────────────────
if __name__ == "__main__":
    namaEnv = os.getenv("FLASK_ENV", "pengembangan")
    app     = buatAplikasi(namaEnv)

    with app.app_context():
        from extensions import db
        db.create_all()   # Buat semua tabel jika belum ada
        print(f"[INFO] Semua tabel database berhasil diinisialisasi.")

    print(f"[INFO] Server Acakehan berjalan di http://localhost:5000")
    app.run(host="0.0.0.0", port=5000, debug=app.config["MODE_DEBUG"])
