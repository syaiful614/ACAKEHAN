// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/data/repositories/repositori_auth.dart
//  Fungsi : Repository autentikasi — menghubungkan UI dengan
//           API backend. Menangani login, registrasi, logout,
//           dan penyimpanan token JWT secara aman.
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/konstanta_app.dart';
import '../../core/network/klien_http.dart';
import '../models/model_data.dart';

/// Kontrak abstrak repository autentikasi.
abstract class InterfaceRepositoriAuth {
  Future<ModelResponLogin> masuk({
    required String email,
    required String kataSandi,
  });

  Future<ModelResponLogin> daftar({
    required String namaLengkap,
    required String email,
    required String kataSandi,
    required String konfirmasiKataSandi,
  });

  Future<void> keluar();
  Future<bool> sudahLogin();
  Future<ModelPengguna?> ambilProfilLokal();
}

/// Implementasi nyata yang memanggil API FastAPI Acakehan.
class RepositoriAuth implements InterfaceRepositoriAuth {
  final Dio _klien;
  final FlutterSecureStorage _penyimpanan;

  const RepositoriAuth({
    required Dio klien,
    required FlutterSecureStorage penyimpanan,
  })  : _klien      = klien,
        _penyimpanan = penyimpanan;

  // ── LOGIN ──────────────────────────────────────────────────
  @override
  Future<ModelResponLogin> masuk({
    required String email,
    required String kataSandi,
  }) async {
    try {
      final respons = await _klien.post(
        KonstantaApi.masuk,
        data: {
          'email':     email.toLowerCase().trim(),
          'kataSandi': kataSandi,
        },
      );

      final dataRespons = respons.data as Map<String, dynamic>;
      final hasil = ModelResponLogin.dariJson(
        dataRespons['data'] as Map<String, dynamic>,
      );

      // Simpan token dan info pengguna ke secure storage
      await _simpanSesiLogin(hasil);
      return hasil;
    } on DioException catch (galat) {
      throw Exception(PenguraiGalatApi.uraikan(galat));
    }
  }

  // ── REGISTRASI ─────────────────────────────────────────────
  @override
  Future<ModelResponLogin> daftar({
    required String namaLengkap,
    required String email,
    required String kataSandi,
    required String konfirmasiKataSandi,
  }) async {
    try {
      final respons = await _klien.post(
        KonstantaApi.daftar,
        data: {
          'namaLengkap':          namaLengkap.trim(),
          'email':                email.toLowerCase().trim(),
          'kataSandi':            kataSandi,
          'konfirmasiKataSandi':  konfirmasiKataSandi,
        },
      );

      final dataRespons = respons.data as Map<String, dynamic>;
      final hasil = ModelResponLogin.dariJson(
        dataRespons['data'] as Map<String, dynamic>,
      );

      await _simpanSesiLogin(hasil);
      return hasil;
    } on DioException catch (galat) {
      throw Exception(PenguraiGalatApi.uraikan(galat));
    }
  }

  // ── LOGOUT ─────────────────────────────────────────────────
  @override
  Future<void> keluar() async {
    try {
      // Beri tahu server bahwa pengguna logout
      await _klien.post(KonstantaApi.keluar);
    } catch (_) {
      // Abaikan error jaringan — tetap hapus data lokal
    } finally {
      await _hapusSesiLogin();
    }
  }

  // ── CEK STATUS LOGIN ───────────────────────────────────────
  @override
  Future<bool> sudahLogin() async {
    final token = await _penyimpanan.read(key: KunciPenyimpanan.tokenAkses);
    return token != null && token.isNotEmpty;
  }

  // ── AMBIL PROFIL DARI LOKAL ────────────────────────────────
  @override
  Future<ModelPengguna?> ambilProfilLokal() async {
    final idStr = await _penyimpanan.read(key: KunciPenyimpanan.penggunaId);
    final nama  = await _penyimpanan.read(key: KunciPenyimpanan.namaPengguna);
    final email = await _penyimpanan.read(key: KunciPenyimpanan.emailPengguna);

    if (idStr == null || nama == null || email == null) return null;

    return ModelPengguna(
      penggunaId:   int.parse(idStr),
      namaLengkap:  nama,
      email:        email,
      statusAktif:  true,
      peranUser:    'pengguna',
      tanggalDaftar: DateTime.now(),
    );
  }

  // ── HELPER PRIVAT ──────────────────────────────────────────

  Future<void> _simpanSesiLogin(ModelResponLogin hasil) async {
    await Future.wait([
      _penyimpanan.write(
        key:   KunciPenyimpanan.tokenAkses,
        value: hasil.token.tokenAkses,
      ),
      _penyimpanan.write(
        key:   KunciPenyimpanan.tokenRefresh,
        value: hasil.token.tokenRefresh,
      ),
      _penyimpanan.write(
        key:   KunciPenyimpanan.penggunaId,
        value: hasil.pengguna.penggunaId.toString(),
      ),
      _penyimpanan.write(
        key:   KunciPenyimpanan.namaPengguna,
        value: hasil.pengguna.namaLengkap,
      ),
      _penyimpanan.write(
        key:   KunciPenyimpanan.emailPengguna,
        value: hasil.pengguna.email,
      ),
    ]);
  }

  Future<void> _hapusSesiLogin() async {
    await Future.wait([
      _penyimpanan.delete(key: KunciPenyimpanan.tokenAkses),
      _penyimpanan.delete(key: KunciPenyimpanan.tokenRefresh),
      _penyimpanan.delete(key: KunciPenyimpanan.penggunaId),
      _penyimpanan.delete(key: KunciPenyimpanan.namaPengguna),
      _penyimpanan.delete(key: KunciPenyimpanan.emailPengguna),
    ]);
  }
}

// ── Provider Riverpod ──────────────────────────────────────────
final repositoriAuthProvider = Provider<RepositoriAuth>((ref) {
  return RepositoriAuth(
    klien:      ref.watch(klienHttpProvider),
    penyimpanan: ref.watch(penyimpananAmanProvider),
  );
});
