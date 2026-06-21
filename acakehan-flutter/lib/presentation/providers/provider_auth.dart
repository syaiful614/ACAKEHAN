// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/presentation/providers/provider_auth.dart
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/model_data.dart';
import '../../data/repositories/repositori_auth.dart';

class StateAuth {
  final ModelPengguna? pengguna;
  final bool sedangMemuat;
  final String? pesanError;
  final bool sudahLogin;

  const StateAuth({
    this.pengguna,
    this.sedangMemuat = true,
    this.pesanError,
    this.sudahLogin = false,
  });

  StateAuth salin({
    ModelPengguna? pengguna,
    bool? sedangMemuat,
    String? pesanError,
    bool? sudahLogin,
    bool hapusError = false,
  }) {
    return StateAuth(
      pengguna:     pengguna     ?? this.pengguna,
      sedangMemuat: sedangMemuat ?? this.sedangMemuat,
      pesanError:   hapusError ? null : (pesanError ?? this.pesanError),
      sudahLogin:   sudahLogin   ?? this.sudahLogin,
    );
  }
}

class NotifierAuth extends StateNotifier<StateAuth> {
  final RepositoriAuth _repositori;

  NotifierAuth(this._repositori) : super(const StateAuth()) {
    _periksaStatusLogin();
  }

  Future<void> _periksaStatusLogin() async {
    print('=== MULAI CEK STATUS LOGIN ===');
    // Langsung set belum login tanpa cek storage
    // untuk bypass masalah flutter_secure_storage hang
    await Future.delayed(const Duration(milliseconds: 500));
    state = state.salin(
      sudahLogin:   false,
      pengguna:     null,
      sedangMemuat: false,
    );
    print('=== STATE UPDATED - BYPASS MODE ===');
  }

  Future<bool> masuk({
    required String email,
    required String kataSandi,
  }) async {
    state = state.salin(sedangMemuat: true, hapusError: true);
    try {
      final hasil = await _repositori.masuk(
        email:     email,
        kataSandi: kataSandi,
      );
      state = state.salin(
        pengguna:     hasil.pengguna,
        sudahLogin:   true,
        sedangMemuat: false,
      );
      return true;
    } catch (galat) {
      state = state.salin(
        sedangMemuat: false,
        pesanError:   galat.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> daftar({
    required String namaLengkap,
    required String email,
    required String kataSandi,
    required String konfirmasiKataSandi,
  }) async {
    state = state.salin(sedangMemuat: true, hapusError: true);
    try {
      final hasil = await _repositori.daftar(
        namaLengkap:         namaLengkap,
        email:               email,
        kataSandi:           kataSandi,
        konfirmasiKataSandi: konfirmasiKataSandi,
      );
      state = state.salin(
        pengguna:     hasil.pengguna,
        sudahLogin:   true,
        sedangMemuat: false,
      );
      return true;
    } catch (galat) {
      state = state.salin(
        sedangMemuat: false,
        pesanError:   galat.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> keluar() async {
    state = state.salin(sedangMemuat: true);
    try { await _repositori.keluar(); } catch (_) {}
    state = const StateAuth(sudahLogin: false, sedangMemuat: false);
  }

  void hapusError() => state = state.salin(hapusError: true);
}

final providerAuthNotifier = StateNotifierProvider<NotifierAuth, StateAuth>((ref) {
  return NotifierAuth(ref.watch(repositoriAuthProvider));
});

final providerSudahLogin = Provider<bool>((ref) =>
    ref.watch(providerAuthNotifier).sudahLogin);

final providerPenggunaAktif = Provider<ModelPengguna?>((ref) =>
    ref.watch(providerAuthNotifier).pengguna);