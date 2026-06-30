// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/presentation/providers/provider_dashboard.dart
//  Fungsi : State management data dashboard & transaksi
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/model_data.dart';
import '../../data/repositories/repositori_dashboard.dart';

// ── Provider Dashboard (FutureProvider — auto-cache) ──────────
final providerDashboard = FutureProvider.autoDispose<ModelDashboard>((ref) async {
  final repositori = ref.watch(repositoriDashboardProvider);
  return repositori.ambilDashboard();
});

// ── Provider Daftar Kategori (untuk dropdown form transaksi) ──
final providerDaftarKategori =
    FutureProvider.autoDispose<List<ModelKategori>>((ref) async {
  final repositori = ref.watch(repositoriKategoriProvider);
  return repositori.ambilDaftarKategori();
});

// ── State Transaksi ───────────────────────────────────────────
class StateTransaksi {
  final List<ModelTransaksi> daftarTransaksi;
  final bool sedangMemuat;
  final bool sedangMuatLebih;
  final String? pesanError;
  final int halamanSaat;
  final int totalHalaman;
  final String? filterTipe;

  const StateTransaksi({
    this.daftarTransaksi   = const [],
    this.sedangMemuat      = false,
    this.sedangMuatLebih   = false,
    this.pesanError,
    this.halamanSaat       = 1,
    this.totalHalaman      = 1,
    this.filterTipe,
  });

  bool get adaHalamanBerikutnya => halamanSaat < totalHalaman;

  StateTransaksi salin({
    List<ModelTransaksi>? daftarTransaksi,
    bool? sedangMemuat,
    bool? sedangMuatLebih,
    String? pesanError,
    int? halamanSaat,
    int? totalHalaman,
    String? filterTipe,
    bool hapusError  = false,
    bool hapusFilter = false,   // FIX: flag untuk reset filterTipe ke null
  }) {
    return StateTransaksi(
      daftarTransaksi:  daftarTransaksi  ?? this.daftarTransaksi,
      sedangMemuat:     sedangMemuat     ?? this.sedangMemuat,
      sedangMuatLebih:  sedangMuatLebih  ?? this.sedangMuatLebih,
      pesanError:       hapusError ? null : (pesanError ?? this.pesanError),
      halamanSaat:      halamanSaat      ?? this.halamanSaat,
      totalHalaman:     totalHalaman     ?? this.totalHalaman,
      // FIX: hapusFilter=true → paksa reset ke null, agar filter "Semua" benar-benar hapus filter
      filterTipe:       hapusFilter ? null : (filterTipe ?? this.filterTipe),
    );
  }
}

class NotifierTransaksi extends StateNotifier<StateTransaksi> {
  final RepositoriTransaksi _repositori;

  NotifierTransaksi(this._repositori) : super(const StateTransaksi()) {
    muatTransaksi();
  }

  /// Muat ulang dari awal (refresh).
  Future<void> muatTransaksi({String? tipe}) async {
    state = state.salin(sedangMemuat: true, hapusError: true, filterTipe: tipe, hapusFilter: tipe == null);
    try {
      final hasil = await _repositori.ambilDaftarTransaksi(
        tipe:    tipe,
        halaman: 1,
      );
      state = state.salin(
        daftarTransaksi: hasil['transaksi'] as List<ModelTransaksi>,
        halamanSaat:     1,
        totalHalaman:    hasil['totalHalaman'] as int,
        sedangMemuat:    false,
      );
    } catch (galat) {
      state = state.salin(
        sedangMemuat: false,
        pesanError:   galat.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Muat halaman berikutnya (infinite scroll).
  Future<void> muatLebihBanyak() async {
    if (!state.adaHalamanBerikutnya || state.sedangMuatLebih) return;

    state = state.salin(sedangMuatLebih: true);
    try {
      final halamanBerikutnya = state.halamanSaat + 1;
      final hasil = await _repositori.ambilDaftarTransaksi(
        tipe:    state.filterTipe,
        halaman: halamanBerikutnya,
      );
      state = state.salin(
        daftarTransaksi: [
          ...state.daftarTransaksi,
          ...(hasil['transaksi'] as List<ModelTransaksi>),
        ],
        halamanSaat:    halamanBerikutnya,
        totalHalaman:   hasil['totalHalaman'] as int,
        sedangMuatLebih: false,
      );
    } catch (galat) {
      state = state.salin(
        sedangMuatLebih: false,
        pesanError: galat.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Tambah transaksi baru ke daftar tanpa perlu reload penuh.
  void tambahkanKeLokal(ModelTransaksi transaksi) {
    state = state.salin(
      daftarTransaksi: [transaksi, ...state.daftarTransaksi],
    );
  }
}

final providerTransaksiNotifier =
    StateNotifierProvider<NotifierTransaksi, StateTransaksi>((ref) {
  return NotifierTransaksi(ref.watch(repositoriTransaksiProvider));
});