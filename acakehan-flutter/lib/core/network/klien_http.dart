// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/core/network/klien_http.dart
//  Fungsi : Konfigurasi Dio HTTP client dengan interceptor:
//           1. Injeksi token JWT ke setiap request (Bearer)
//           2. Tangani error 401 → navigasi ke halaman login
//           3. Logging request/response di mode debug
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/konstanta_app.dart';

part 'klien_http.g.dart';

/// Provider untuk FlutterSecureStorage — singleton di seluruh app.
@riverpod
FlutterSecureStorage penyimpananAman(PenyimpananAmanRef ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
}

/// Provider untuk instance Dio yang sudah dikonfigurasi penuh.
@riverpod
Dio klienHttp(KlienHttpRef ref) {
  final penyimpanan = ref.read(penyimpananAmanProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl:        KonstantaApi.urlDasar,
      connectTimeout: KonstantaApi.timeoutKoneksi,
      receiveTimeout: KonstantaApi.timeoutTerima,
      headers: {
        'Content-Type': 'application/json',
        'Accept':        'application/json',
      },
    ),
  );

  // ── Interceptor 1: Injeksi Token JWT ─────────────────────
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Ambil token akses dari secure storage
        final tokenAkses = await penyimpanan.read(key: KunciPenyimpanan.tokenAkses);

        // Sertakan di header Authorization jika token tersedia
        if (tokenAkses != null && tokenAkses.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $tokenAkses';
        }

        return handler.next(options);
      },

      onError: (DioException galat, handler) async {
        // ── Tangani 401 Unauthorized ────────────────────────
        // Token kedaluwarsa atau tidak valid → hapus token lokal
        if (galat.response?.statusCode == 401) {
          await penyimpanan.delete(key: KunciPenyimpanan.tokenAkses);
          await penyimpanan.delete(key: KunciPenyimpanan.tokenRefresh);
          // Di aplikasi nyata: navigasi ke halaman login menggunakan GoRouter
          // Contoh: navigasiGlobal.go(NamaRoute.masuk);
        }

        return handler.next(galat);
      },
    ),
  );

  // ── Interceptor 2: Logger (hanya di mode debug) ──────────
  if (kDebugMode) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader:  true,
        requestBody:    true,
        responseHeader: false,
        responseBody:   true,
        error:          true,
        compact:        true,
      ),
    );
  }

  return dio;
}

/// Kelas pembantu untuk menguraikan error API menjadi pesan Indonesia.
class PenguraiGalatApi {
  PenguraiGalatApi._();

  /// Mengubah DioException menjadi pesan error yang ramah pengguna.
  static String uraikan(Object galat) {
    if (galat is DioException) {
      switch (galat.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Koneksi timeout. Periksa jaringan internet Anda.';

        case DioExceptionType.connectionError:
          return 'Tidak dapat terhubung ke server. '
              'Pastikan server backend berjalan.';

        case DioExceptionType.badResponse:
          final statusCode = galat.response?.statusCode;
          final data       = galat.response?.data;

          // Coba ambil pesan dari respons API Acakehan
          String? pesanApi;
          if (data is Map<String, dynamic>) {
            pesanApi = data['pesan'] as String?  ??
                       data['detail']?['pesan'] as String?;
          }

          if (pesanApi != null) return pesanApi;

          return switch (statusCode) {
            400 => 'Permintaan tidak valid.',
            401 => 'Sesi Anda telah berakhir. Silakan login kembali.',
            403 => 'Akses ditolak.',
            404 => 'Data tidak ditemukan.',
            409 => 'Data sudah ada.',
            422 => 'Data yang dikirim tidak valid.',
            500 => 'Terjadi kesalahan pada server.',
            _   => 'Terjadi kesalahan (kode: $statusCode).',
          };

        case DioExceptionType.cancel:
          return 'Permintaan dibatalkan.';

        default:
          return 'Terjadi kesalahan jaringan yang tidak diketahui.';
      }
    }

    return 'Terjadi kesalahan: ${galat.toString()}';
  }
}
