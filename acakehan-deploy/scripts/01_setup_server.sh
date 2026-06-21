#!/bin/bash
# ============================================================
#  ACAKEHAN — Skrip Setup VPS Ubuntu Otomatis
#  File   : scripts/01_setup_server.sh
#  Fungsi : Mengkonfigurasi VPS Ubuntu 22.04 dari nol:
#           - Update sistem
#           - Install Python, MySQL, Nginx
#           - Buat user non-root untuk keamanan
#           - Konfigurasi firewall UFW
#           - Hardening SSH dasar
#
#  CARA PAKAI:
#    chmod +x 01_setup_server.sh
#    sudo bash 01_setup_server.sh
#
#  PRASYARAT:
#    - VPS Ubuntu 22.04 LTS (min. 1 vCPU, 1 GB RAM)
#    - Akses root atau sudo
# ============================================================

set -e  # Hentikan skrip jika ada perintah yang gagal

# ── Warna terminal ─────────────────────────────────────────────
HIJAU='\033[0;32m'
KUNING='\033[1;33m'
MERAH='\033[0;31m'
BIRU='\033[0;34m'
RESET='\033[0m'

info()    { echo -e "${BIRU}[INFO]${RESET} $1"; }
sukses()  { echo -e "${HIJAU}[OK]${RESET} $1"; }
peringatan() { echo -e "${KUNING}[WARN]${RESET} $1"; }

# ── Variabel Konfigurasi ───────────────────────────────────────
NAMA_USER_DEPLOY="acakehan"          # User non-root untuk menjalankan app
NAMA_DB="db_acakehan"
NAMA_DB_USER="acakehan_user"
# WAJIB GANTI: kata sandi database yang kuat
DB_PASSWORD="AcakehanDB@Prod2024!"
DIR_APP="/home/${NAMA_USER_DEPLOY}/acakehan-backend"

echo ""
echo "=============================================="
echo "   ACAKEHAN — Setup VPS Ubuntu 22.04"
echo "=============================================="
echo ""

# ── Langkah 1: Update Sistem ───────────────────────────────────
info "Langkah 1/8: Memperbarui paket sistem..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    curl wget git unzip \
    software-properties-common \
    build-essential
sukses "Sistem berhasil diperbarui."

# ── Langkah 2: Install Python 3.11 ────────────────────────────
info "Langkah 2/8: Menginstall Python 3.11..."
add-apt-repository -y ppa:deadsnakes/ppa
apt-get update -qq
apt-get install -y -qq \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip
sukses "Python $(python3.11 --version) berhasil diinstall."

# ── Langkah 3: Install MySQL Server ───────────────────────────
info "Langkah 3/8: Menginstall MySQL Server 8.0..."
apt-get install -y -qq mysql-server mysql-client libmysqlclient-dev

# Mulai dan aktifkan MySQL saat boot
systemctl start mysql
systemctl enable mysql

# Konfigurasi database dan user Acakehan
mysql -u root <<MYSQL_SCRIPT
-- Buat database
CREATE DATABASE IF NOT EXISTS ${NAMA_DB}
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Buat user khusus (bukan root!)
CREATE USER IF NOT EXISTS '${NAMA_DB_USER}'@'localhost'
    IDENTIFIED BY '${DB_PASSWORD}';

-- Beri hak akses hanya ke database Acakehan
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER
    ON ${NAMA_DB}.*
    TO '${NAMA_DB_USER}'@'localhost';

FLUSH PRIVILEGES;
MYSQL_SCRIPT

sukses "MySQL dan database '${NAMA_DB}' berhasil dikonfigurasi."

# ── Langkah 4: Install Nginx ───────────────────────────────────
info "Langkah 4/8: Menginstall Nginx sebagai reverse proxy..."
apt-get install -y -qq nginx
systemctl start nginx
systemctl enable nginx
sukses "Nginx berhasil diinstall."

# ── Langkah 5: Buat User Deploy Non-Root ──────────────────────
info "Langkah 5/8: Membuat user deployment '${NAMA_USER_DEPLOY}'..."
if id "${NAMA_USER_DEPLOY}" &>/dev/null; then
    peringatan "User '${NAMA_USER_DEPLOY}' sudah ada, lewati pembuatan."
else
    useradd -m -s /bin/bash "${NAMA_USER_DEPLOY}"
    usermod -aG sudo "${NAMA_USER_DEPLOY}"
    sukses "User '${NAMA_USER_DEPLOY}' berhasil dibuat."
fi

# Buat direktori aplikasi
mkdir -p "${DIR_APP}"
chown -R "${NAMA_USER_DEPLOY}:${NAMA_USER_DEPLOY}" "/home/${NAMA_USER_DEPLOY}"

# ── Langkah 6: Konfigurasi Firewall UFW ───────────────────────
info "Langkah 6/8: Mengkonfigurasi firewall UFW..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh        # Port 22 — SSH
ufw allow 80/tcp    # Port 80 — HTTP
ufw allow 443/tcp   # Port 443 — HTTPS
ufw --force enable
sukses "Firewall UFW aktif. Port 22/80/443 dibuka."

# ── Langkah 7: Hardening SSH ──────────────────────────────────
info "Langkah 7/8: Menerapkan hardening SSH dasar..."
# Nonaktifkan login root via SSH
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin/PermitRootLogin no/' /etc/ssh/sshd_config
# Nonaktifkan autentikasi kata sandi (gunakan SSH key)
# CATATAN: Pastikan SSH key sudah dikonfigurasi SEBELUM mengaktifkan ini!
# sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
sukses "Hardening SSH selesai."

# ── Langkah 8: Install Certbot (SSL) ──────────────────────────
info "Langkah 8/8: Menginstall Certbot untuk SSL/TLS gratis..."
apt-get install -y -qq certbot python3-certbot-nginx
sukses "Certbot berhasil diinstall."

# ── Ringkasan ──────────────────────────────────────────────────
echo ""
echo "=============================================="
echo -e "${HIJAU}   Setup VPS selesai! ✓${RESET}"
echo "=============================================="
echo ""
echo "Informasi penting:"
echo "  Database      : ${NAMA_DB}"
echo "  User DB       : ${NAMA_DB_USER}"
echo "  Password DB   : ${DB_PASSWORD}"
echo "  User Deploy   : ${NAMA_USER_DEPLOY}"
echo "  Dir Aplikasi  : ${DIR_APP}"
echo ""
echo "Langkah berikutnya:"
echo "  1. Upload kode: bash 02_deploy_backend.sh"
echo "  2. Konfigurasi Nginx: bash 03_setup_nginx.sh"
echo "  3. SSL: bash 04_setup_ssl.sh"
echo ""
