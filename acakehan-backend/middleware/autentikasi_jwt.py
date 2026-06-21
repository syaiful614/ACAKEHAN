"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : middleware/autentikasi_jwt.py
  Fungsi : Middleware validasi token JWT pada setiap request
  Pola   : Decorator pattern — dipakai di semua endpoint
           yang membutuhkan pengguna yang sudah login
============================================================
"""

import jwt
import functools
from datetime import datetime, timezone
from flask import request, jsonify, current_app, g
from models.model_database import Pengguna


def hasilkan_token_jwt(pengguna_id: int, email: str, peran: str) -> dict:
    """
    Membuat pasangan token JWT (akses + refresh) untuk pengguna
    yang berhasil login atau registrasi.

    Args:
        pengguna_id : ID unik pengguna dari database
        email       : Email pengguna (disertakan di payload)
        peran       : Peran pengguna ('pengguna' atau 'admin')

    Returns:
        dict berisi 'tokenAkses' dan 'tokenRefresh'
    """
    sekarang = datetime.now(timezone.utc)
    konfigurasi = current_app.config

    # ----- Payload token AKSES (berlaku 24 jam) -----
    payload_akses = {
        "sub":        pengguna_id,          # Subject: ID pengguna
        "email":      email,
        "peran":      peran,
        "tipeToken":  "akses",
        "iat":        sekarang,             # Issued At
        "exp":        sekarang + konfigurasi["JWT_MASA_BERLAKU_AKSES"],
    }

    # ----- Payload token REFRESH (berlaku 30 hari) -----
    payload_refresh = {
        "sub":        pengguna_id,
        "tipeToken":  "refresh",
        "iat":        sekarang,
        "exp":        sekarang + konfigurasi["JWT_MASA_BERLAKU_REFRESH"],
    }

    tokenAkses  = jwt.encode(payload_akses,  konfigurasi["JWT_SECRET_KEY"], algorithm="HS256")
    tokenRefresh = jwt.encode(payload_refresh, konfigurasi["JWT_SECRET_KEY"], algorithm="HS256")

    return {
        "tokenAkses":  tokenAkses,
        "tokenRefresh": tokenRefresh,
        "tipeToken":   "Bearer",
        "masaBerlaku": int(konfigurasi["JWT_MASA_BERLAKU_AKSES"].total_seconds()),
    }


def wajib_login(fungsi):
    """
    Decorator untuk memproteksi endpoint — hanya pengguna dengan
    token JWT akses yang valid yang bisa mengaksesnya.

    Cara pakai:
        @app.route("/api/transaksi", methods=["POST"])
        @wajib_login
        def tambah_transaksi():
            pengguna_aktif = g.pengguna_aktif
            ...

    Alur validasi:
        1. Ambil header Authorization: Bearer <token>
        2. Decode & verifikasi signature JWT
        3. Periksa apakah token sudah kedaluwarsa
        4. Pastikan tipe token adalah 'akses' (bukan 'refresh')
        5. Cari pengguna di database berdasarkan ID di payload
        6. Simpan objek pengguna ke flask.g untuk dipakai di controller
    """
    @functools.wraps(fungsi)
    def pembungkus(*args, **kwargs):
        token = None

        # Langkah 1: Ekstrak token dari header Authorization
        headerAuth = request.headers.get("Authorization", "")
        if headerAuth.startswith("Bearer "):
            token = headerAuth.split(" ")[1]

        if not token:
            return jsonify({
                "berhasil": False,
                "pesan":    "Akses ditolak: token autentikasi tidak ditemukan. "
                            "Harap login terlebih dahulu.",
                "kode":     "TOKEN_TIDAK_ADA"
            }), 401

        try:
            # Langkah 2 & 3: Decode + verifikasi (PyJWT otomatis periksa exp)
            payload = jwt.decode(
                token,
                current_app.config["JWT_SECRET_KEY"],
                algorithms=["HS256"]
            )

            # Langkah 4: Pastikan ini token akses, bukan token refresh
            if payload.get("tipeToken") != "akses":
                return jsonify({
                    "berhasil": False,
                    "pesan":    "Akses ditolak: tipe token tidak valid. "
                                "Gunakan token akses, bukan token refresh.",
                    "kode":     "TIPE_TOKEN_SALAH"
                }), 401

            # Langkah 5: Cari pengguna di database
            penggunaAktif = Pengguna.query.filter_by(
                pengguna_id=payload["sub"],
                statusAktif=1
            ).first()

            if not penggunaAktif:
                return jsonify({
                    "berhasil": False,
                    "pesan":    "Akses ditolak: akun tidak ditemukan atau telah dinonaktifkan.",
                    "kode":     "AKUN_TIDAK_VALID"
                }), 401

            # Langkah 6: Simpan data pengguna agar bisa diakses oleh controller
            g.pengguna_aktif = penggunaAktif
            g.payload_token  = payload

        except jwt.ExpiredSignatureError:
            return jsonify({
                "berhasil": False,
                "pesan":    "Sesi Anda telah berakhir. Silakan login kembali.",
                "kode":     "TOKEN_KEDALUWARSA"
            }), 401

        except jwt.InvalidTokenError as galat:
            return jsonify({
                "berhasil": False,
                "pesan":    f"Token tidak valid: {str(galat)}",
                "kode":     "TOKEN_TIDAK_VALID"
            }), 401

        # Lanjutkan eksekusi fungsi controller yang asli
        return fungsi(*args, **kwargs)

    return pembungkus


def hanya_admin(fungsi):
    """
    Decorator tambahan (harus dipakai SETELAH @wajib_login) untuk
    memastikan hanya pengguna ber-peran 'admin' yang bisa mengakses.

    Cara pakai:
        @app.route("/api/admin/pengguna", methods=["GET"])
        @wajib_login
        @hanya_admin
        def daftar_pengguna():
            ...
    """
    @functools.wraps(fungsi)
    def pembungkus(*args, **kwargs):
        if not hasattr(g, "pengguna_aktif") or g.pengguna_aktif.peranUser != "admin":
            return jsonify({
                "berhasil": False,
                "pesan":    "Akses ditolak: halaman ini hanya untuk administrator.",
                "kode":     "BUKAN_ADMIN"
            }), 403
        return fungsi(*args, **kwargs)
    return pembungkus
