// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/core/utils/format_helper.dart
//  Fungsi : Fungsi-fungsi pemformat untuk tampilan UI —
//           Rupiah, tanggal Bahasa Indonesia, persentase, dll.
// ============================================================

import 'package:intl/intl.dart';

/// Semua fungsi format yang digunakan di seluruh aplikasi.
class FormatHelper {
  FormatHelper._();

  // ── Format Mata Uang Rupiah ────────────────────────────────

  static final NumberFormat _formatRupiah = NumberFormat.currency(
    locale:        'id_ID',
    symbol:        'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _formatRupiahDesimal = NumberFormat.currency(
    locale:        'id_ID',
    symbol:        'Rp ',
    decimalDigits: 2,
  );

  /// Format angka ke Rupiah tanpa desimal.
  /// Contoh: 1500000 → "Rp 1.500.000"
  static String rupiah(num nominal) {
    return _formatRupiah.format(nominal);
  }

  /// Format angka ke Rupiah dengan desimal (untuk ketelitian).
  /// Contoh: 1500000.50 → "Rp 1.500.000,50"
  static String rupiahDesimal(num nominal) {
    return _formatRupiahDesimal.format(nominal);
  }

  /// Format nominal ringkas untuk tampilan kecil.
  /// Contoh: 1500000 → "1,5 Jt" | 250000000 → "250 Jt" | 1500000000 → "1,5 M"
  static String rupiahRingkas(num nominal) {
    if (nominal >= 1000000000) {
      final miliar = nominal / 1000000000;
      return 'Rp ${miliar.toStringAsFixed(miliar.truncateToDouble() == miliar ? 0 : 1)} M';
    } else if (nominal >= 1000000) {
      final juta = nominal / 1000000;
      return 'Rp ${juta.toStringAsFixed(juta.truncateToDouble() == juta ? 0 : 1)} Jt';
    } else if (nominal >= 1000) {
      final ribu = nominal / 1000;
      return 'Rp ${ribu.toStringAsFixed(0)} Rb';
    }
    return rupiah(nominal);
  }

  // ── Format Tanggal ─────────────────────────────────────────

  static final DateFormat _formatTanggalLengkap = DateFormat(
    'dd MMMM yyyy', 'id_ID',
  );
  static final DateFormat _formatTanggalPendek = DateFormat(
    'd MMM', 'id_ID',
  );
  static final DateFormat _formatBulanTahun = DateFormat(
    'MMMM yyyy', 'id_ID',
  );
  static final DateFormat _formatHariTanggal = DateFormat(
    'EEEE, d MMMM', 'id_ID',
  );

  /// "15 Juli 2024"
  static String tanggalLengkap(DateTime tgl) => _formatTanggalLengkap.format(tgl);

  /// "15 Jul"
  static String tanggalPendek(DateTime tgl) => _formatTanggalPendek.format(tgl);

  /// "Juli 2024"
  static String bulanTahun(DateTime tgl) => _formatBulanTahun.format(tgl);

  /// "Senin, 15 Juli"
  static String hariTanggal(DateTime tgl) => _formatHariTanggal.format(tgl);

  /// Format relatif: "Hari ini", "Kemarin", atau tanggal lengkap
  static String tanggalRelatif(DateTime tgl) {
    final sekarang = DateTime.now();
    final selisihHari = DateTime(sekarang.year, sekarang.month, sekarang.day)
        .difference(DateTime(tgl.year, tgl.month, tgl.day))
        .inDays;

    return switch (selisihHari) {
      0 => 'Hari ini',
      1 => 'Kemarin',
      _ => tanggalLengkap(tgl),
    };
  }

  // ── Format Persentase ──────────────────────────────────────

  /// "85,3%"
  static String persen(double nilai, {int desimal = 1}) {
    return '${nilai.toStringAsFixed(desimal)}%';
  }

  // ── Format Angka Biasa ─────────────────────────────────────

  /// Format angka dengan pemisah ribuan: 1500 → "1.500"
  static String angka(num nilai) {
    return NumberFormat('#,###', 'id_ID').format(nilai);
  }

  // ── Nama Bulan Bahasa Indonesia ────────────────────────────

  static const List<String> _namaBulan = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  static String namaBulan(int nomorBulan) {
    if (nomorBulan < 1 || nomorBulan > 12) return '?';
    return _namaBulan[nomorBulan];
  }

  /// "Juli 2024"
  static String labelPeriode(int bulan, int tahun) {
    return '${namaBulan(bulan)} $tahun';
  }

  // ── Method tambahan yang dibutuhkan halaman profil & anggaran ──

  /// Format DateTime? ke string tanggal lengkap (null-safe)
  static String formatTanggal(DateTime? tgl) {
    if (tgl == null) return '-';
    return tanggalLengkap(tgl);
  }

  /// Alias rupiah() untuk kompatibilitas widget
  static String formatRupiah(num nominal) => rupiah(nominal);

  /// Label bulan saat ini, contoh: "Juni 2026"
  static String labelBulanIni() {
    final now = DateTime.now();
    return bulanTahun(now);
  }
}