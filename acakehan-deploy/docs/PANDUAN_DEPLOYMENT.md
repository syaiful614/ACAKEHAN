# 🚀 Panduan Deployment Acakehan ke VPS Ubuntu

> **Estimasi waktu:** 45–90 menit  
> **Target:** VPS Ubuntu 22.04 LTS dengan domain aktif

---

## Daftar Isi

1. [Persiapan](#1-persiapan)
2. [Beli & Akses VPS](#2-beli--akses-vps)
3. [Setup Server](#3-setup-server)
4. [Deploy Backend](#4-deploy-backend)
5. [Konfigurasi Nginx](#5-konfigurasi-nginx)
6. [Aktifkan HTTPS](#6-aktifkan-https)
7. [Hubungkan Flutter ke Server](#7-hubungkan-flutter-ke-server)
8. [Build APK Production](#8-build-apk-production)
9. [Monitoring & Maintenance](#9-monitoring--maintenance)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Persiapan

Sebelum mulai, pastikan Anda memiliki:

| Kebutuhan | Keterangan |
|---|---|
| VPS Ubuntu 22.04 | Min. 1 vCPU, 1 GB RAM (DigitalOcean, Vultr, Contabo, AWS EC2) |
| Domain | Contoh: `api.acakehan.com` (bisa beli di Niagahoster, Namecheap) |
| SSH Client | Terminal (Linux/Mac) atau PuTTY (Windows) |
| Kode backend | Folder `acakehan-backend` yang sudah selesai |
| Git repository | Push kode ke GitHub/GitLab terlebih dahulu |

### 1.1 Push Kode ke GitHub

```bash
# Di komputer lokal — inisialisasi dan push kode
cd acakehan-backend
git init
git add .
git commit -m "Initial commit: Acakehan Backend v1.0"
git remote add origin https://github.com/username/acakehan-backend.git
git push -u origin main
```

### 1.2 Konfigurasi DNS

Di panel DNS domain Anda, tambahkan A Record:

```
Nama (Host) : api
Tipe        : A
Nilai       : <IP_VPS_ANDA>
TTL         : 3600
```

Tunggu propagasi DNS (5–30 menit). Verifikasi:
```bash
nslookup api.acakehan.com
# Harus mengembalikan IP VPS Anda
```

---

## 2. Beli & Akses VPS

### 2.1 Akses SSH Pertama Kali

```bash
# Dari terminal komputer lokal
ssh root@<IP_VPS_ANDA>

# Contoh:
ssh root@103.167.xx.xx
```

### 2.2 Generate SSH Key (Opsional tapi Direkomendasikan)

```bash
# Di komputer lokal — buat SSH key pair
ssh-keygen -t ed25519 -C "acakehan-deploy" -f ~/.ssh/acakehan_vps

# Salin public key ke VPS
ssh-copy-id -i ~/.ssh/acakehan_vps.pub root@<IP_VPS_ANDA>

# Login tanpa password
ssh -i ~/.ssh/acakehan_vps root@<IP_VPS_ANDA>
```

---

## 3. Setup Server

```bash
# Unduh skrip setup
wget https://raw.githubusercontent.com/username/acakehan-backend/main/scripts/01_setup_server.sh

# Jalankan sebagai root
chmod +x 01_setup_server.sh
sudo bash 01_setup_server.sh
```

**Yang diinstall secara otomatis:**
- Python 3.11 + pip
- MySQL Server 8.0 + database `db_acakehan`
- Nginx (reverse proxy)
- UFW Firewall (port 22/80/443)
- Certbot (untuk SSL gratis)
- User `acakehan` (non-root untuk keamanan)

---

## 4. Deploy Backend

### 4.1 Login sebagai User Acakehan

```bash
# Dari komputer lokal
ssh acakehan@<IP_VPS_ANDA>
```

### 4.2 Clone Repositori

```bash
# Di dalam VPS, sebagai user acakehan
cd ~
git clone https://github.com/username/acakehan-backend.git
cd acakehan-backend
```

### 4.3 Jalankan Skrip Deploy

```bash
# Jalankan skrip deploy backend
bash scripts/02_deploy_backend.sh
```

### 4.4 Konfigurasi .env Production

File `.env` sudah dibuat otomatis, tapi **WAJIB** update JWT secret:

```bash
nano /home/acakehan/acakehan-backend/.env
```

Ganti nilai `JWT_KUNCI_RAHASIA` dengan string acak yang kuat:

```bash
# Generate kunci acak yang aman
python3 -c "import secrets; print(secrets.token_hex(64))"
# Salin hasilnya ke JWT_KUNCI_RAHASIA di file .env
```

Setelah edit `.env`, restart service:

```bash
sudo systemctl restart acakehan-api
```

### 4.5 Verifikasi Backend Berjalan

```bash
# Cek status service
sudo systemctl status acakehan-api

# Test API dari dalam VPS
curl http://127.0.0.1:8000/api/v1/status

# Lihat log real-time
sudo journalctl -u acakehan-api -f
```

Output yang diharapkan dari `curl`:
```json
{
  "berhasil": true,
  "namaAplikasi": "Acakehan",
  "versiAplikasi": "1.0.0",
  "statusDatabase": "terhubung",
  "pesan": "Server Acakehan berjalan normal."
}
```

---

## 5. Konfigurasi Nginx

```bash
# Ganti dengan domain Anda
export DOMAIN="api.acakehan.com"
sudo bash scripts/03_setup_nginx.sh
```

Verifikasi dari komputer lokal:
```bash
curl http://api.acakehan.com/api/v1/status
```

---

## 6. Aktifkan HTTPS

```bash
export DOMAIN="api.acakehan.com"
export EMAIL="admin@acakehan.com"
sudo bash scripts/04_setup_ssl.sh
```

Setelah selesai, test HTTPS:
```bash
curl https://api.acakehan.com/api/v1/status
```

> **Catatan:** Sertifikat SSL gratis dari Let's Encrypt berlaku 90 hari
> dan diperbarui **otomatis** oleh Certbot via cron job.

---

## 7. Hubungkan Flutter ke Server

### 7.1 Update URL API di Aplikasi

Buka `lib/core/constants/konstanta_app.dart` dan ubah:

```dart
class KonstantaApi {
  // Ganti dengan URL production Anda
  static const String urlDasar = 'https://api.acakehan.com/api/v1';
}
```

**Atau** gunakan `--dart-define` saat build (lebih baik):

```bash
# Development (emulator Android)
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# Development (perangkat fisik)
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.100:8000/api/v1

# Production
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.acakehan.com/api/v1
```

### 7.2 Konfigurasi Network Security (Android)

Buat file `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Production: hanya HTTPS -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.acakehan.com</domain>
    </domain-config>
    <!-- Development: izinkan HTTP lokal -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">10.0.2.2</domain>
        <domain includeSubdomains="true">192.168.0.0</domain>
    </domain-config>
</network-security-config>
```

Daftarkan di `android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
```

### 7.3 Konfigurasi iOS (Info.plist)

Tambahkan di `ios/Runner/Info.plist` untuk **mengizinkan** HTTPS:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.acakehan.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### 7.4 Test Koneksi dari Perangkat Nyata

```dart
// Tambahkan sementara di initState() untuk debugging
Future<void> _tesKoneksi() async {
  try {
    final dio = Dio();
    final respons = await dio.get('https://api.acakehan.com/api/v1/status');
    debugPrint('Status server: ${respons.data}');
  } catch (e) {
    debugPrint('Koneksi gagal: $e');
  }
}
```

---

## 8. Build APK Production

### 8.1 Buat Keystore (Satu Kali)

```bash
# Di komputer lokal
keytool -genkey -v \
  -keystore ~/acakehan-release-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias acakehan

# Isi informasi yang diminta (nama, organisasi, dll.)
```

### 8.2 Konfigurasi Signing

Buat `android/key.properties`:
```properties
storePassword=kata_sandi_keystore_anda
keyPassword=kata_sandi_key_anda
keyAlias=acakehan
storeFile=/Users/nama/acakehan-release-key.jks
```

Update `android/app/build.gradle`:
```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias     keystoreProperties['keyAlias']
            keyPassword  keystoreProperties['keyPassword']
            storeFile    keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig     signingConfigs.release
            minifyEnabled     true
            shrinkResources   true
        }
    }
}
```

### 8.3 Build APK

```bash
# Build APK release (untuk distribusi langsung)
flutter build apk --release \
  --dart-define=LINGKUNGAN=production \
  --dart-define=API_BASE_URL=https://api.acakehan.com/api/v1 \
  --obfuscate \
  --split-debug-info=build/debug-info

# Lokasi APK hasil build:
# build/app/outputs/flutter-apk/app-release.apk

# Build App Bundle (untuk Google Play Store)
flutter build appbundle --release \
  --dart-define=LINGKUNGAN=production \
  --dart-define=API_BASE_URL=https://api.acakehan.com/api/v1
```

---

## 9. Monitoring & Maintenance

### Perintah Harian

```bash
# Cek status semua service
systemctl status acakehan-api nginx mysql

# Lihat log backend (100 baris terakhir)
journalctl -u acakehan-api -n 100

# Monitor log real-time
journalctl -u acakehan-api -f

# Lihat log Nginx
tail -f /var/log/nginx/acakehan_access.log
tail -f /var/log/nginx/acakehan_error.log

# Penggunaan resource server
htop
df -h    # Disk
free -h  # RAM
```

### Update Aplikasi ke Versi Baru

```bash
# Dari komputer lokal — push kode baru
git add . && git commit -m "feat: fitur baru" && git push

# Di VPS — jalankan skrip update
ssh acakehan@api.acakehan.com \
  "bash ~/acakehan-backend/scripts/05_update_production.sh"
```

### Backup Database

```bash
# Backup manual
mysqldump -u acakehan_user -p db_acakehan \
  > ~/backup_$(date +%Y%m%d_%H%M%S).sql

# Otomatis setiap malam jam 02:00 (tambahkan ke crontab)
crontab -e
# Tambahkan baris:
# 0 2 * * * mysqldump -u acakehan_user -pPASSWORD db_acakehan > ~/backups/db_$(date +\%Y\%m\%d).sql
```

---

## 10. Troubleshooting

### Backend tidak bisa diakses dari internet

```bash
# 1. Cek service berjalan
systemctl status acakehan-api

# 2. Cek Nginx aktif
systemctl status nginx

# 3. Cek port 80/443 terbuka
ufw status

# 4. Test dari dalam VPS
curl http://127.0.0.1:8000/api/v1/status    # Uvicorn
curl http://localhost/api/v1/status          # Nginx
```

### Error 502 Bad Gateway di Nginx

```bash
# Artinya: Nginx bisa diakses tapi tidak bisa forward ke Uvicorn
# Penyebab umum: service acakehan-api tidak berjalan

# Cek dan restart
systemctl status acakehan-api
journalctl -u acakehan-api -n 50   # Lihat error
systemctl restart acakehan-api
```

### Flutter tidak bisa konek ke server

```
Checklist:
□ URL di konstanta_app.dart sudah benar (https://, bukan http://)
□ network_security_config.xml sudah dikonfigurasi (Android)
□ Sertifikat SSL valid: curl -v https://api.acakehan.com
□ CORS: domain Flutter app sudah ditambahkan di .env → ASAL_CORS_DIIZINKAN
□ Coba dari browser: https://api.acakehan.com/api/v1/status
```

### Reset dan Deploy Ulang dari Awal

```bash
# HATI-HATI: Ini menghapus semua data!
sudo systemctl stop acakehan-api
sudo rm -rf /home/acakehan/acakehan-backend
mysql -u root -e "DROP DATABASE db_acakehan;"
# Lalu jalankan ulang dari langkah 3
```

---

## Checklist Deployment

```
□ VPS Ubuntu 22.04 sudah dibeli dan bisa diakses via SSH
□ Domain sudah diarahkan ke IP VPS (A Record DNS)
□ Kode backend sudah di-push ke GitHub
□ Skrip 01_setup_server.sh berhasil dijalankan
□ Skrip 02_deploy_backend.sh berhasil, service berjalan
□ File .env production sudah dikonfigurasi (JWT_KUNCI_RAHASIA diganti)
□ Database sudah terisi tabel dan data awal
□ Skrip 03_setup_nginx.sh berhasil, HTTP bisa diakses
□ Skrip 04_setup_ssl.sh berhasil, HTTPS aktif
□ curl https://api.acakehan.com/api/v1/status mengembalikan 200 OK
□ URL API di Flutter sudah diubah ke https://api.acakehan.com/api/v1
□ network_security_config.xml sudah dikonfigurasi
□ APK release berhasil di-build dan bisa login ke akun
□ Backup database terjadwal sudah dikonfigurasi
```

---

*Panduan ini dibuat untuk proyek tugas Analisis Perancangan Sistem — Acakehan v1.0*
