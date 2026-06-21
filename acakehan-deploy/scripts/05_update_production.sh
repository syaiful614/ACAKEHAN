#!/bin/bash
# ============================================================
#  ACAKEHAN — Skrip Update Production (Zero-Downtime)
#  File   : scripts/05_update_production.sh
#  Fungsi : Update kode backend ke versi terbaru tanpa downtime.
#           Jalankan setiap kali ada perubahan kode yang perlu
#           di-deploy ulang ke production.
#
#  CARA PAKAI (dari komputer lokal):
#    ssh acakehan@IP_VPS "bash ~/acakehan-backend/scripts/05_update_production.sh"
#
#  Atau otomatis via GitHub Actions (lihat .github/workflows/)
# ============================================================

set -e

HIJAU='\033[0;32m'; BIRU='\033[0;34m'; KUNING='\033[1;33m'; RESET='\033[0m'
info()       { echo -e "${BIRU}[INFO]${RESET} $1"; }
sukses()     { echo -e "${HIJAU}[OK]${RESET} $1"; }
peringatan() { echo -e "${KUNING}[WARN]${RESET} $1"; }

DIR_APP="/home/acakehan/acakehan-backend"
NAMA_SERVICE="acakehan-api"
WAKTU_MULAI=$(date +%s)

echo ""
echo "======================================"
echo "   ACAKEHAN — Update Production"
echo "   Waktu: $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================"

cd "${DIR_APP}"

# ── Simpan versi saat ini (untuk rollback) ─────────────────────
COMMIT_SEKARANG=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
info "Versi saat ini: ${COMMIT_SEKARANG}"

# ── Tarik kode terbaru dari Git ────────────────────────────────
info "Mengambil kode terbaru dari repositori..."
git fetch origin main
git pull origin main --rebase
COMMIT_BARU=$(git rev-parse --short HEAD)
sukses "Kode diperbarui ke commit: ${COMMIT_BARU}"

# ── Update dependensi Python ───────────────────────────────────
info "Memperbarui dependensi Python..."
"${DIR_APP}/venv/bin/pip" install -r requirements.txt -q --no-deps
sukses "Dependensi diperbarui."

# ── Jalankan migrasi database (jika ada perubahan model) ───────
info "Menjalankan migrasi database..."
"${DIR_APP}/venv/bin/python" -c "
from app.config.database import buatSemuaTabel
import app.models.model_db
buatSemuaTabel()
" && sukses "Database up-to-date." || peringatan "Tidak ada perubahan schema."

# ── Restart service dengan graceful reload ─────────────────────
info "Merestart service ${NAMA_SERVICE}..."
systemctl reload-or-restart "${NAMA_SERVICE}"
sleep 3

# ── Verifikasi service berjalan ────────────────────────────────
if systemctl is-active --quiet "${NAMA_SERVICE}"; then
    sukses "Service berjalan normal."
else
    echo "ERROR: Service gagal! Melakukan rollback ke ${COMMIT_SEKARANG}..."
    git checkout "${COMMIT_SEKARANG}"
    systemctl restart "${NAMA_SERVICE}"
    echo "Rollback selesai. Cek log: journalctl -u ${NAMA_SERVICE} -n 50"
    exit 1
fi

# ── Test health endpoint ────────────────────────────────────────
info "Mengetes health endpoint..."
sleep 2
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/api/v1/status)
if [ "${HTTP_CODE}" = "200" ]; then
    sukses "Health check OK (HTTP 200)."
else
    peringatan "Health check mengembalikan HTTP ${HTTP_CODE}."
fi

WAKTU_SELESAI=$(date +%s)
DURASI=$((WAKTU_SELESAI - WAKTU_MULAI))

echo ""
echo "======================================"
echo -e "${HIJAU}   Update selesai! ✓ (${DURASI} detik)${RESET}"
echo "  Dari : ${COMMIT_SEKARANG}"
echo "  Ke   : ${COMMIT_BARU}"
echo "======================================"
echo ""
