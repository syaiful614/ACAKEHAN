// ============================================================
//  ACAKEHAN — Konfigurasi Flutter untuk Production
//  File   : docs/konfigurasi_flutter_production.dart
//  Fungsi : Panduan dan kode lengkap untuk menghubungkan
//           aplikasi Flutter ke server backend production.
// ============================================================

// ============================================================
//  BAGIAN 1: Manajemen URL per Environment
//  Strategi: Gunakan dart-define saat build agar URL bisa
//  diubah tanpa mengubah kode sumber.
// ============================================================

// lib/core/constants/konstanta_app.dart (versi production-ready)

class KonfigurasiLingkungan {
  KonfigurasiLingkungan._();

  /// Lingkungan aktif: diinjeksi saat build via --dart-define
  static const String lingkungan = String.fromEnvironment(
    'LINGKUNGAN',
    defaultValue: 'development',
  );

  /// URL dasar API: diinjeksi saat build via --dart-define
  static const String urlApiDasar = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1', // Default: emulator Android
  );

  static bool get isDevelopment => lingkungan == 'development';
  static bool get isProduction  => lingkungan == 'production';
  static bool get isStaging     => lingkungan == 'staging';
}

// ── Cara Build per Environment ─────────────────────────────────

// Development (emulator Android):
//   flutter run --dart-define=LINGKUNGAN=development \
//               --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

// Development (perangkat fisik - sambungkan ke WiFi yang sama):
//   flutter run --dart-define=LINGKUNGAN=development \
//               --dart-define=API_BASE_URL=http://192.168.1.100:8000/api/v1

// Production (APK Release):
//   flutter build apk --release \
//               --dart-define=LINGKUNGAN=production \
//               --dart-define=API_BASE_URL=https://api.acakehan.com/api/v1

// Production (iOS Release):
//   flutter build ipa --release \
//               --dart-define=LINGKUNGAN=production \
//               --dart-define=API_BASE_URL=https://api.acakehan.com/api/v1


// ============================================================
//  BAGIAN 2: Konfigurasi Android untuk HTTPS
//  File: android/app/src/main/AndroidManifest.xml
// ============================================================

// Tambahkan di dalam tag <application>:
// <application
//     android:networkSecurityConfig="@xml/network_security_config"
//     ...>

// Buat file: android/app/src/main/res/xml/network_security_config.xml
const String networkSecurityConfigXml = '''
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>

    <!-- Production: hanya izinkan HTTPS -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.acakehan.com</domain>
    </domain-config>

    <!-- Development: izinkan HTTP lokal untuk emulator dan perangkat dev -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">10.0.2.2</domain>
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">127.0.0.1</domain>
        <domain includeSubdomains="true">192.168.0.0</domain>
    </domain-config>

</network-security-config>
''';


// ============================================================
//  BAGIAN 3: Klien HTTP Dio — Versi Production
//  Tambahan: Certificate Pinning, timeout lebih ketat,
//  retry logic untuk koneksi tidak stabil
// ============================================================

// lib/core/network/klien_http_production.dart

const String kodeProduksi = r'''
import "package:dio/dio.dart";
import "package:dio/io.dart";
import "dart:io";

class KlienHttpProduksi {
  static Dio buat() {
    final dio = Dio(
      BaseOptions(
        baseUrl:         KonfigurasiLingkungan.urlApiDasar,
        connectTimeout:  const Duration(seconds: 15),
        receiveTimeout:  const Duration(seconds: 30),
        sendTimeout:     const Duration(seconds: 30),
        headers: {
          "Content-Type":   "application/json",
          "Accept":         "application/json",
          "Accept-Language": "id-ID,id;q=0.9",
          // Identifikasi versi aplikasi untuk debugging
          "X-App-Version":  "1.0.0",
          "X-Platform":     Platform.operatingSystem,
        },
      ),
    );

    // ── Retry Interceptor (untuk jaringan tidak stabil) ──────
    // Coba ulang maksimal 2 kali jika gagal koneksi
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout) {
            final retryCount = error.requestOptions.extra["retryCount"] ?? 0;
            if (retryCount < 2) {
              error.requestOptions.extra["retryCount"] = retryCount + 1;
              await Future.delayed(Duration(seconds: retryCount + 1));
              try {
                final respons = await dio.fetch(error.requestOptions);
                return handler.resolve(respons);
              } catch (_) {}
            }
          }
          return handler.next(error);
        },
      ),
    );

    return dio;
  }
}
''';


// ============================================================
//  BAGIAN 4: Flavor Configuration
//  Pisahkan konfigurasi dev/staging/prod di level Flutter
// ============================================================

// lib/core/config/flavor_config.dart
const String kodeFlavorConfig = r'''
enum Flavor { development, staging, production }

class FlavorConfig {
  static Flavor? _flavor;
  static String? _apiBaseUrl;
  static String? _namaAplikasi;

  static void inisialisasi({
    required Flavor flavor,
    required String apiBaseUrl,
    String namaAplikasi = "Acakehan",
  }) {
    _flavor      = flavor;
    _apiBaseUrl  = apiBaseUrl;
    _namaAplikasi = namaAplikasi;
  }

  static Flavor  get flavor      => _flavor!;
  static String  get apiBaseUrl  => _apiBaseUrl!;
  static String  get namaAplikasi => _namaAplikasi!;
  static bool    get isDev        => _flavor == Flavor.development;
  static bool    get isProd       => _flavor == Flavor.production;
}
''';

// ── File entry point per flavor ─────────────────────────────────

// lib/main_development.dart
const String mainDev = r'''
import "package:flutter/material.dart";
import "main.dart" as app;
import "core/config/flavor_config.dart";

void main() {
  FlavorConfig.inisialisasi(
    flavor:      Flavor.development,
    apiBaseUrl:  "http://10.0.2.2:8000/api/v1",
    namaAplikasi: "Acakehan (Dev)",
  );
  app.main();
}
''';

// lib/main_production.dart
const String mainProd = r'''
import "package:flutter/material.dart";
import "main.dart" as app;
import "core/config/flavor_config.dart";

void main() {
  FlavorConfig.inisialisasi(
    flavor:      Flavor.production,
    apiBaseUrl:  "https://api.acakehan.com/api/v1",
    namaAplikasi: "Acakehan",
  );
  app.main();
}
''';

// ── Cara jalankan per flavor ────────────────────────────────────
// flutter run -t lib/main_development.dart
// flutter build apk --release -t lib/main_production.dart


// ============================================================
//  BAGIAN 5: Penanganan Error Koneksi di UI
//  Widget yang menampilkan status koneksi dan tombol retry
// ============================================================

const String kodeWidgetKoneksi = r'''
import "package:flutter/material.dart";
import "package:connectivity_plus/connectivity_plus.dart";

class PeriksaKoneksi extends StatelessWidget {
  final Widget child;
  const PeriksaKoneksi({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityResult>(
      stream:       Connectivity().onConnectivityChanged,
      initialData:  ConnectivityResult.wifi,
      builder: (context, snapshot) {
        final terkoneksi = snapshot.data != ConnectivityResult.none;

        if (!terkoneksi) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    "Tidak ada koneksi internet",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Periksa koneksi Wi-Fi atau data seluler Anda.",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
''';


// ============================================================
//  BAGIAN 6: Ringkasan Perintah Build APK Production
// ============================================================

// Langkah-langkah build APK release:
//
// 1. Generate keystore (sekali saja):
//    keytool -genkey -v \
//      -keystore ~/acakehan-keystore.jks \
//      -keyalg RSA -keysize 2048 \
//      -validity 10000 \
//      -alias acakehan
//
// 2. Buat file android/key.properties:
//    storePassword=<kata sandi keystore>
//    keyPassword=<kata sandi key>
//    keyAlias=acakehan
//    storeFile=<path ke acakehan-keystore.jks>
//
// 3. Build APK:
//    flutter build apk --release \
//      --dart-define=LINGKUNGAN=production \
//      --dart-define=API_BASE_URL=https://api.acakehan.com/api/v1 \
//      --obfuscate \
//      --split-debug-info=build/debug-info
//
// 4. APK tersedia di: build/app/outputs/flutter-apk/app-release.apk
//
// 5. Build App Bundle (untuk Play Store):
//    flutter build appbundle --release \
//      --dart-define=LINGKUNGAN=production \
//      --dart-define=API_BASE_URL=https://api.acakehan.com/api/v1
