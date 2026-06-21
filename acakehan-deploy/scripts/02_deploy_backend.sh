#!/bin/bash
# ============================================================
#  ACAKEHAN — Skrip Deploy Backend FastAPI
#  File   : scripts/02_deploy_backend.sh
#  Fungsi : Upload kode, buat virtual environment Python,
#           install dependensi, konfigurasi .env production,
#           jalankan migrasi database, dan mulai aplikasi.
#
#  CARA PAKAI (dari komputer lokal):
#    # Opsi A: Upload via SCP lalu jalankan di server
#    scp -r ./acakehan-backend user@IP_VPS:/home/acakehan/
#    ssh user@IP_VPS "bash /home/acakehan/acakehan-backend/scripts/02_deploy_backend.sh"
#
#    # Opsi B: Clone dari Git (direkomendasikan)
#    ssh user@IP_VPS
#    git clone https://github.com/username/acakehan-backend.git /home/acakehan/acakehan-backend
#    bash /home/acakehan/acakehan-backend/scripts/02_deploy_backend.sh
# ============================================================

set -e

HIJAU='\033[0;32m'; BIRU='\033[0;34m'; RESET='\033[0m'
info()   { echo -e "${BIRU}[INFO]${RESET} $1"; }
sukses() { echo -e "${HIJAU}[OK]${RESET} $1"; }

# ── Variabel ────────────────────────────────────────────────────
NAMA_USER="acakehan"
DIR_APP="/home/${NAMA_USER}/acakehan-backend"
DIR_VENV="${DIR_APP}/venv"
NAMA_SERVICE="acakehan-api"

echo ""
echo "======================================"
echo "   ACAKEHAN — Deploy Backend FastAPI"
echo "======================================"

# ── Langkah 1: Buat virtual environment Python ─────────────────
info "Membuat virtual environment Python 3.11..."
cd "${DIR_APP}"
python3.11 -m venv "${DIR_VENV}"
sukses "Virtual environment siap di ${DIR_VENV}"

# ── Langkah 2: Install dependensi ──────────────────────────────
info "Menginstall dependensi dari requirements.txt..."
"${DIR_VENV}/bin/pip" install --upgrade pip -q
"${DIR_VENV}/bin/pip" install -r requirements.txt -q
sukses "Semua dependensi berhasil diinstall."

# ── Langkah 3: Buat file .env production ───────────────────────
info "Membuat konfigurasi .env production..."
if [ ! -f "${DIR_APP}/.env" ]; then
cat > "${DIR_APP}/.env" <<ENV_FILE
# ============================================================
#  Acakehan — Konfigurasi Production
#  JANGAN commit file ini ke Git!
# ============================================================

# Identitas
NAMA_APLIKASI=Acakehan
VERSI_APLIKASI=1.0.0
MODE_DEBUG=False
LINGKUNGAN=production

# Database — sesuaikan dengan yang dibuat di skrip 01
DB_HOST=localhost
DB_PORT=3306
DB_NAMA=db_acakehan
DB_PENGGUNA=acakehan_user
DB_KATA_SANDI=AcakehanDB@Prod2024!
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=40

# JWT — WAJIB GANTI dengan string acak panjang!
# Generate: python3 -c "import secrets; print(secrets.token_hex(64))"
JWT_KUNCI_RAHASIA=GANTI_DENGAN_STRING_ACAK_128_KARAKTER_DISINI_SANGAT_PANJANG
JWT_ALGORITMA=HS256
JWT_JAM_KADALUARSA_AKSES=24
JWT_HARI_KADALUARSA_REFRESH=30

# Bcrypt
BCRYPT_ROUNDS=14

# Anggaran
BATAS_PERSEN_PERINGATAN=80.0
BATAS_PERSEN_KRITIS=100.0

# CORS — ganti dengan domain atau IP aplikasi mobile Anda
ASAL_CORS_DIIZINKAN=https://yourdomain.com,http://localhost:3000
ENV_FILE
    sukses "File .env production dibuat."
else
    echo "  File .env sudah ada, dilewati."
fi

# ── Langkah 4: Buat tabel database ─────────────────────────────
info "Menginisialisasi tabel database..."
cd "${DIR_APP}"
"${DIR_VENV}/bin/python" -c "
from app.config.database import buatSemuaTabel
from app.config.pengaturan import ambilPengaturan
import app.models.model_db  # Pastikan semua model diimport
buatSemuaTabel()
print('Tabel database berhasil dibuat.')
"
sukses "Database siap."

# ── Langkah 5: Buat file systemd service ───────────────────────
info "Membuat systemd service '${NAMA_SERVICE}'..."
cat > "/etc/systemd/system/${NAMA_SERVICE}.service" <<SERVICE_FILE
[Unit]
Description=Acakehan FastAPI Backend
Documentation=https://github.com/username/acakehan-backend
After=network.target mysql.service
Requires=mysql.service

[Service]
Type=exec
User=${NAMA_USER}
Group=${NAMA_USER}
WorkingDirectory=${DIR_APP}
Environment="PATH=${DIR_VENV}/bin"
EnvironmentFile=${DIR_APP}/.env

# Uvicorn: 2 worker per CPU core (sesuaikan dengan jumlah CPU VPS)
ExecStart=${DIR_VENV}/bin/uvicorn main:app \
    --host 127.0.0.1 \
    --port 8000 \
    --workers 2 \
    --log-level info \
    --access-log \
    --proxy-headers \
    --forwarded-allow-ips='*'

# Restart otomatis jika crash
Restart=always
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3

# Batas resource (opsional, sesuaikan dengan VPS)
LimitNOFILE=65536
LimitNPROC=512

# Log ke journald
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${NAMA_SERVICE}

[Install]
WantedBy=multi-user.target
SERVICE_FILE

# Reload systemd dan mulai service
systemctl daemon-reload
systemctl enable "${NAMA_SERVICE}"
systemctl start "${NAMA_SERVICE}"

# Tunggu sebentar lalu cek status
sleep 3
if systemctl is-active --quiet "${NAMA_SERVICE}"; then
    sukses "Service '${NAMA_SERVICE}' berjalan!"
else
    echo "ERROR: Service gagal start. Cek log: journalctl -u ${NAMA_SERVICE} -n 50"
    exit 1
fi

# ── Langkah 6: Atur kepemilikan file ───────────────────────────
chown -R "${NAMA_USER}:${NAMA_USER}" "${DIR_APP}"

echo ""
echo "======================================"
echo -e "${HIJAU}   Backend berhasil di-deploy! ✓${RESET}"
echo "======================================"
echo ""
echo "Perintah berguna:"
echo "  Status  : systemctl status ${NAMA_SERVICE}"
echo "  Log     : journalctl -u ${NAMA_SERVICE} -f"
echo "  Restart : systemctl restart ${NAMA_SERVICE}"
echo "  Stop    : systemctl stop ${NAMA_SERVICE}"
echo ""
echo "Test API (dari dalam VPS):"
echo "  curl http://127.0.0.1:8000/api/v1/status"
echo ""
