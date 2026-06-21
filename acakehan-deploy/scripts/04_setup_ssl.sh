#!/bin/bash
# ============================================================
#  ACAKEHAN — Setup SSL/HTTPS dengan Let's Encrypt
#  File   : scripts/04_setup_ssl.sh
#  Fungsi : Aktifkan HTTPS gratis menggunakan Certbot +
#           Let's Encrypt. Sertifikat diperbarui otomatis
#           setiap 90 hari melalui cron job.
#
#  PRASYARAT:
#    - Domain sudah diarahkan ke IP VPS (A record DNS)
#    - Port 80 terbuka di firewall
#    - Nginx sudah dikonfigurasi (jalankan 03_setup_nginx.sh dulu)
#
#  CARA PAKAI:
#    export DOMAIN="api.acakehan.com"
#    export EMAIL="admin@acakehan.com"
#    sudo bash 04_setup_ssl.sh
# ============================================================

set -e

HIJAU='\033[0;32m'; BIRU='\033[0;34m'; MERAH='\033[0;31m'; RESET='\033[0m'
info()   { echo -e "${BIRU}[INFO]${RESET} $1"; }
sukses() { echo -e "${HIJAU}[OK]${RESET} $1"; }
error()  { echo -e "${MERAH}[ERROR]${RESET} $1"; exit 1; }

DOMAIN="${DOMAIN:-api.acakehan.com}"
EMAIL="${EMAIL:-admin@acakehan.com}"

echo ""
echo "======================================"
echo "   ACAKEHAN — Setup SSL Let's Encrypt"
echo "   Domain : ${DOMAIN}"
echo "   Email  : ${EMAIL}"
echo "======================================"

# ── Verifikasi domain bisa dijangkau ───────────────────────────
info "Memeriksa aksesibilitas domain ${DOMAIN}..."
if ! curl -s --max-time 10 "http://${DOMAIN}/api/v1/status" > /dev/null; then
    error "Domain ${DOMAIN} tidak bisa dijangkau. Pastikan:
  1. A record DNS sudah mengarah ke IP VPS ini
  2. Nginx sudah berjalan (systemctl status nginx)
  3. Port 80 terbuka di firewall (ufw allow 80)"
fi
sukses "Domain dapat dijangkau."

# ── Dapatkan sertifikat SSL ────────────────────────────────────
info "Mendapatkan sertifikat SSL dari Let's Encrypt..."
certbot --nginx \
    --non-interactive \
    --agree-tos \
    --email "${EMAIL}" \
    --domains "${DOMAIN}" \
    --redirect \
    --hsts \
    --staple-ocsp

sukses "Sertifikat SSL berhasil diperoleh!"

# ── Aktifkan header HSTS di Nginx ──────────────────────────────
info "Mengaktifkan HSTS di konfigurasi Nginx..."
sed -i 's/# add_header Strict-Transport-Security/add_header Strict-Transport-Security/' \
    "/etc/nginx/sites-available/acakehan"
nginx -t && systemctl reload nginx
sukses "HSTS aktif."

# ── Setup pembaruan otomatis sertifikat ────────────────────────
info "Mengkonfigurasi pembaruan sertifikat otomatis..."

# Certbot sudah menambahkan cron job otomatis, tapi kita tambahkan
# hook untuk reload Nginx setelah pembaruan
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh <<'HOOK'
#!/bin/bash
# Hook: reload Nginx setelah sertifikat Let's Encrypt diperbarui
systemctl reload nginx
echo "[$(date)] Nginx di-reload setelah pembaruan sertifikat SSL" \
    >> /var/log/letsencrypt/renewal-hook.log
HOOK

chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

# Simulasi pembaruan untuk memastikan konfigurasi benar
certbot renew --dry-run
sukses "Pembaruan otomatis sertifikat SSL dikonfigurasi."

# ── Verifikasi akhir ───────────────────────────────────────────
info "Memverifikasi HTTPS..."
sleep 2
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/api/v1/status")
if [ "${HTTP_CODE}" = "200" ]; then
    sukses "HTTPS berjalan dengan sempurna! (HTTP ${HTTP_CODE})"
else
    echo "  Peringatan: HTTPS mengembalikan kode ${HTTP_CODE}"
    echo "  Cek: journalctl -u nginx -n 20"
fi

echo ""
echo "======================================"
echo -e "${HIJAU}   HTTPS aktif! ✓${RESET}"
echo "======================================"
echo ""
echo "API Production URL:"
echo "  https://${DOMAIN}/api/v1/status"
echo "  https://${DOMAIN}/docs  (Swagger UI)"
echo ""
echo "Sertifikat akan diperbarui otomatis setiap 90 hari."
echo "Cek tanggal kadaluarsa: certbot certificates"
echo ""
