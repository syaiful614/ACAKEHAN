// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/data/repositories/repositori_dashboard.dart
//  Fungsi : Repository dashboard & transaksi — mengambil data
//           dari API backend dan memetakannya ke model lokal.
//  FIX    : Perbaikan parsing response pagination yang salah
//           (pagination berada di root response, bukan di dalam 'data')
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/konstanta_app.dart';
import '../../core/network/klien_http.dart';
import '../models/model_data.dart';

class RepositoriDashboard {
  final Dio _klien;
  const RepositoriDashboard({required Dio klien}) : _klien = klien;

  /// Mengambil seluruh data dashboard dalam satu request.
  Future<ModelDashboard> ambilDashboard() async {
    try {
      final respons = await _klien.get(KonstantaApi.dashboard);
      final data    = respons.data['data'] as Map<String, dynamic>;
      return ModelDashboard.dariJson(data);
    } on DioException catch (galat) {
      throw Exception(PenguraiGalatApi.uraikan(galat));
    }
  }
}

class RepositoriTransaksi {
  final Dio _klien;
  const RepositoriTransaksi({required Dio klien}) : _klien = klien;

  /// Ambil riwayat transaksi dengan filter opsional & pagination.
  /// FIX: FastAPI mengembalikan 'data' sebagai List langsung dan
  ///      'pagination' di level root response (bukan di dalam 'data').
  Future<Map<String, dynamic>> ambilDaftarTransaksi({
    String? tipe,
    int?    bulan,
    int?    tahun,
    int?    kategoriId,
    int     halaman    = 1,
    int     perHalaman = 20,
  }) async {
    try {
      final queryParam = <String, dynamic>{
        'halaman':     halaman,
        'per_halaman': perHalaman,
        if (tipe       != null) 'tipe':        tipe,
        if (bulan      != null) 'bulan':       bulan,
        if (tahun      != null) 'tahun':       tahun,
        if (kategoriId != null) 'kategori_id': kategoriId,
      };

      final respons = await _klien.get(
        KonstantaApi.transaksi,
        queryParameters: queryParam,
      );

      // FIX: FastAPI mengembalikan struktur:
      // { "berhasil": true, "data": [...], "pagination": {...} }
      // bukan { "berhasil": true, "data": { "transaksi": [...], "pagination": {...} } }
      final daftarJson = respons.data['data'] as List;
      final paginasi   = respons.data['pagination'] as Map<String, dynamic>;

      return {
        'transaksi': daftarJson
            .map((e) => ModelTransaksi.dariJson(e as Map<String, dynamic>))
            .toList(),
        'totalData':    paginasi['totalData']    ?? 0,
        'totalHalaman': paginasi['totalHalaman'] ?? 1,
        'halamanSaat':  paginasi['halaman']      ?? 1,
      };
    } on DioException catch (galat) {
      throw Exception(PenguraiGalatApi.uraikan(galat));
    }
  }

  /// Catat transaksi baru dan kembalikan hasilnya.
  /// FIX: Response FastAPI: { "data": { "transaksi": {...}, "anggaran": {...} } }
  Future<ModelTransaksi> tambahTransaksi({
    required int    kategoriId,
    required double jumlahNominal,
    required String tipeTransaksi,
    required String tanggalTransaksi,
    String?         catatanTambahan,
  }) async {
    try {
      final respons = await _klien.post(
        KonstantaApi.transaksi,
        data: {
          'kategoriId':       kategoriId,
          'jumlahNominal':    jumlahNominal,
          'tipeTransaksi':    tipeTransaksi,
          'tanggalTransaksi': tanggalTransaksi,
          if (catatanTambahan != null) 'catatanTambahan': catatanTambahan,
        },
      );
      // FIX: data transaksi ada di dalam 'data' → 'transaksi'
      final data = respons.data['data']['transaksi'] as Map<String, dynamic>;
      return ModelTransaksi.dariJson(data);
    } on DioException catch (galat) {
      throw Exception(PenguraiGalatApi.uraikan(galat));
    }
  }

  /// Hapus transaksi berdasarkan ID.
  Future<void> hapusTransaksi(int transaksiId) async {
    try {
      await _klien.delete(KonstantaApi.transaksiById(transaksiId));
    } on DioException catch (galat) {
      throw Exception(PenguraiGalatApi.uraikan(galat));
    }
  }
}

class RepositoriKategori {
  final Dio _klien;
  const RepositoriKategori({required Dio klien}) : _klien = klien;

  /// Ambil daftar kategori, filter opsional berdasarkan tipe.
  /// FIX: Response FastAPI: { "data": [...] } — 'data' adalah List langsung
  Future<List<ModelKategori>> ambilDaftarKategori({String? tipe}) async {
    try {
      final respons = await _klien.get(
        KonstantaApi.kategori,
        queryParameters: tipe != null ? {'tipe': tipe} : null,
      );
      final daftarJson = respons.data['data'] as List;
      return daftarJson
          .map((e) => ModelKategori.dariJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (galat) {
      throw Exception(PenguraiGalatApi.uraikan(galat));
    }
  }
}

// ── Provider Riverpod ──────────────────────────────────────────
final repositoriDashboardProvider = Provider<RepositoriDashboard>((ref) {
  return RepositoriDashboard(klien: ref.watch(klienHttpProvider));
});

final repositoriTransaksiProvider = Provider<RepositoriTransaksi>((ref) {
  return RepositoriTransaksi(klien: ref.watch(klienHttpProvider));
});

final repositoriKategoriProvider = Provider<RepositoriKategori>((ref) {
  return RepositoriKategori(klien: ref.watch(klienHttpProvider));
});
