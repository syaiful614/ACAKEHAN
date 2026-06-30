// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/core/constants/konstanta_app.dart
//  Fungsi : Semua konstanta global aplikasi —
//           URL API, nama route, kunci storage, dll.
// ============================================================

/// Konfigurasi URL dan endpoint API backend Acakehan (FastAPI).
class KonstantaApi {
  KonstantaApi._(); // Cegah instantiasi — hanya konstanta statis

  /// Ganti dengan IP/domain server backend saat production.R
  /// Untuk emulator Android gunakan 10.0.2.2 (bukan localhost).
  /// Untuk simulator iOS / web gunakan localhost.
  static const String urlDasar = 'http://10.175.139.96:8000/api/v1';

  // ── Endpoint Autentikasi ──────────────────────────────────
  static const String daftar  = '/auth/daftar';
  static const String masuk   = '/auth/masuk';
  static const String keluar  = '/auth/keluar';
  static const String profil  = '/auth/profil';

  // ── Endpoint Transaksi ────────────────────────────────────
  static const String transaksi       = '/transaksi';
  static String transaksiById(int id) => '/transaksi/$id';

  // ── Endpoint Kategori ──────────────────────────────────────
  static const String kategori = '/kategori';

  // ── Endpoint Dashboard ────────────────────────────────────
  static const String dashboard = '/dashboard';

  // ── Timeout koneksi ───────────────────────────────────────
  static const Duration timeoutKoneksi = Duration(seconds: 15);
  static const Duration timeoutTerima  = Duration(seconds: 30);
}

/// Nama-nama route untuk navigasi menggunakan GoRouter.
class NamaRoute {
  NamaRoute._();

  static const String sambutan  = '/';
  static const String masuk     = '/masuk';
  static const String daftar    = '/daftar';
  static const String dashboard = '/dashboard';
  static const String transaksi = '/transaksi';
  static const String anggaran  = '/anggaran';
  static const String profil    = '/profil';
}

/// Kunci untuk penyimpanan lokal (SecureStorage & SharedPreferences).
class KunciPenyimpanan {
  KunciPenyimpanan._();

  // SecureStorage — data sensitif
  static const String tokenAkses   = 'token_akses';
  static const String tokenRefresh = 'token_refresh';
  static const String penggunaId   = 'pengguna_id';

  // SharedPreferences — preferensi UI
  static const String temaGelap    = 'tema_gelap';
  static const String namaPengguna = 'nama_pengguna';
  static const String emailPengguna = 'email_pengguna';
}

/// Konstanta string UI yang dipakai di seluruh aplikasi.
class TeksApp {
  TeksApp._();

  static const String namaAplikasi  = 'Acakehan';
  static const String tagline       = 'Catat. Kelola. Bebas Finansial.';
  static const String matauang      = 'Rp';
  static const String versi         = '1.0.0';
}