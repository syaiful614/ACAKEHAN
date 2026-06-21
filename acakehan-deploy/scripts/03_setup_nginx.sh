#!/bin/bash
# ============================================================
#  ACAKEHAN — Konfigurasi Nginx Reverse Proxy
#  File   : scripts/03_setup_nginx.sh
#  Fungsi : Konfigurasi Nginx sebagai reverse proxy di depan
#           Uvicorn — menangani HTTP, gzip, rate limiting,
#           dan header keamanan.
#
#  CARA PAKAI:
#    # Ganti DOMAIN_ANDA dengan domain/IP VPS Anda
#    export DOMAIN="api.acakehan.com"
#    sudo bash 03_setup_nginx.sh
# ============================================================

set -e

HIJAU='\033[0;32m'; BIRU='\033[0;34m'; RESET='\033[0m'
info()   { echo -e "${BIRU}[INFO]${RESET} $1"; }
sukses() { echo -e "${HIJAU}[OK]${RESET} $1"; }

# ── Konfigurasi ─────────────────────────────────────────────────
DOMAIN="${DOMAIN:-api.acakehan.com}"   # Domain atau IP VPS
NAMA_CONF="acakehan"

echo ""
echo "======================================"
echo "   ACAKEHAN — Setup Nginx"
echo "   Domain: ${DOMAIN}"
echo "======================================"

# ── Buat konfigurasi Nginx ──────────────────────────────────────
info "Membuat konfigurasi Nginx untuk domain '${DOMAIN}'..."

cat > "/etc/nginx/sites-available/${NAMA_CONF}" <<NGINX_CONF
# ============================================================
#  Nginx Config — Acakehan API
#  Server: ${DOMAIN}
# ============================================================

# Batasi jumlah request per IP (rate limiting)
# 10 request/detik per IP, burst hingga 20 request
limit_req_zone \$binary_remote_addr zone=api_acakehan:10m rate=10r/s;

# Batas ukuran koneksi bersamaan per IP
limit_conn_zone \$binary_remote_addr zone=conn_acakehan:10m;

# Upstream: server Uvicorn yang berjalan di lokal
upstream acakehan_backend {
    server 127.0.0.1:8000;
    keepalive 32;   # Pertahankan koneksi agar lebih efisien
}

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    # ── Redirect HTTP → HTTPS (aktif setelah SSL dikonfigurasi) ──
    # Uncomment baris di bawah setelah menjalankan 04_setup_ssl.sh:
    # return 301 https://\$host\$request_uri;

    # ── Ukuran upload maksimal ─────────────────────────────────
    client_max_body_size 10M;   # Untuk upload foto struk/bukti

    # ── Kompresi Gzip ──────────────────────────────────────────
    gzip on;
    gzip_types
        text/plain text/css application/json
        application/javascript text/xml application/xml+rss;
    gzip_min_length 1000;
    gzip_comp_level 6;
    gzip_vary on;

    # ── Header Keamanan ────────────────────────────────────────
    add_header X-Frame-Options          "DENY"           always;
    add_header X-Content-Type-Options   "nosniff"        always;
    add_header X-XSS-Protection         "1; mode=block"  always;
    add_header Referrer-Policy          "strict-origin"  always;
    add_header Permissions-Policy       "geolocation=()" always;
    # HSTS: aktifkan setelah HTTPS terkonfigurasi
    # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # ── Health Check (tanpa rate limit) ───────────────────────
    location = /api/v1/status {
        proxy_pass         http://acakehan_backend;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        access_log         off;
    }

    # ── Dokumentasi Swagger (batasi akses di production) ──────
    location ~ ^/(docs|redoc|openapi.json) {
        # Di production, batasi hanya IP tertentu:
        # allow 203.0.113.0/24;   # IP kantor/rumah Anda
        # deny all;

        proxy_pass         http://acakehan_backend;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }

    # ── Endpoint API Utama ─────────────────────────────────────
    location /api/ {
        # Terapkan rate limiting
        limit_req        zone=api_acakehan burst=20 nodelay;
        limit_conn       conn_acakehan 20;
        limit_req_status 429;  # 429 Too Many Requests

        # Forward request ke Uvicorn
        proxy_pass         http://acakehan_backend;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade           \$http_upgrade;
        proxy_set_header   Connection        "upgrade";
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;

        # Timeout — sesuaikan jika ada endpoint berat
        proxy_connect_timeout 60s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;

        # Buffer untuk respons besar
        proxy_buffering    on;
        proxy_buffer_size  4k;
        proxy_buffers      8 4k;
    }

    # ── Blokir akses ke file sensitif ─────────────────────────
    location ~ /\. {
        deny all;
        return 404;
    }

    location ~ \.(env|git|gitignore|md|txt)$ {
        deny all;
        return 404;
    }

    # ── Log ────────────────────────────────────────────────────
    access_log /var/log/nginx/acakehan_access.log combined;
    error_log  /var/log/nginx/acakehan_error.log warn;
}
NGINX_CONF

# ── Aktifkan konfigurasi ────────────────────────────────────────
info "Mengaktifkan konfigurasi Nginx..."
ln -sf "/etc/nginx/sites-available/${NAMA_CONF}" \
        "/etc/nginx/sites-enabled/${NAMA_CONF}"

# Hapus konfigurasi default jika ada
rm -f /etc/nginx/sites-enabled/default

# ── Validasi konfigurasi Nginx ──────────────────────────────────
info "Memvalidasi konfigurasi Nginx..."
nginx -t
sukses "Konfigurasi Nginx valid."

# ── Reload Nginx ────────────────────────────────────────────────
systemctl reload nginx
sukses "Nginx berhasil dikonfigurasi dan di-reload."

echo ""
echo "======================================"
echo -e "${HIJAU}   Nginx siap! ✓${RESET}"
echo "======================================"
echo ""
echo "Test dari browser atau curl:"
echo "  curl http://${DOMAIN}/api/v1/status"
echo ""
echo "Langkah berikutnya:"
echo "  Aktifkan HTTPS: bash 04_setup_ssl.sh"
echo ""
