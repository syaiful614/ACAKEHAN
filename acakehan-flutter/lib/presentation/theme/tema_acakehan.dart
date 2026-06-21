// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/presentation/theme/tema_acakehan.dart
//  Fungsi : Definisi tema visual lengkap — warna, tipografi,
//           dekorasi komponen, dengan dukungan light/dark mode.
//  Estetik: "Soft Financial" — bersih, modern, terpercaya.
//           Gradien hangat, tipografi rounded, kartu berlapis.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Palet Warna Utama ─────────────────────────────────────────
class WarnaAcakehan {
  WarnaAcakehan._();

  // Hijau toska sebagai warna primer — melambangkan pertumbuhan finansial
  static const Color primer        = Color(0xFF0D9488); // Teal 600
  static const Color primerMuda    = Color(0xFF14B8A6); // Teal 500
  static const Color primerSangat  = Color(0xFF134E4A); // Teal 900
  static const Color primerPudar   = Color(0xFFCCFBF1); // Teal 100

  // Aksen oranye hangat — kontras dan energik
  static const Color aksen         = Color(0xFFF97316); // Orange 500
  static const Color aksenMuda     = Color(0xFFFED7AA); // Orange 200
  static const Color aksenGelap    = Color(0xFFC2410C); // Orange 700

  // Merah untuk pengeluaran
  static const Color pengeluaran   = Color(0xFFEF4444); // Red 500
  static const Color pengeluaranBg = Color(0xFFFEE2E2); // Red 100

  // Hijau untuk pemasukan
  static const Color pemasukan     = Color(0xFF22C55E); // Green 500
  static const Color pemasukanBg   = Color(0xFFDCFCE7); // Green 100

  // Kuning untuk peringatan
  static const Color peringatan    = Color(0xFFF59E0B); // Amber 500
  static const Color peringatanBg  = Color(0xFFFEF3C7); // Amber 100

  // Netral abu-abu
  static const Color abu100        = Color(0xFFF1F5F9);
  static const Color abu200        = Color(0xFFE2E8F0);
  static const Color abu300        = Color(0xFFCBD5E1);
  static const Color abu400        = Color(0xFF94A3B8);
  static const Color abu500        = Color(0xFF64748B);
  static const Color abu600        = Color(0xFF475569);
  static const Color abu700        = Color(0xFF334155);
  static const Color abu800        = Color(0xFF1E293B);
  static const Color abu900        = Color(0xFF0F172A);

  // Latar belakang
  static const Color latarTerang   = Color(0xFFF8FAFC);
  static const Color latarGelap    = Color(0xFF0F172A);
  static const Color kartuTerang   = Color(0xFFFFFFFF);
  static const Color kartuGelap    = Color(0xFF1E293B);
}

// ── Gradien ───────────────────────────────────────────────────
class GradienAcakehan {
  GradienAcakehan._();

  static const LinearGradient headerUtama = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient kartuSaldo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF0D9488)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient tombolPrimer = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
  );

  static const LinearGradient latarLogin = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF134E4A), Color(0xFF0F172A)],
    stops: [0.0, 0.6],
  );
}

// ── Dekorasi Komponen ─────────────────────────────────────────
class DekorasiAcakehan {
  DekorasiAcakehan._();

  /// Shadow halus untuk kartu — efek berlapis
  static List<BoxShadow> get shadowKartu => [
        BoxShadow(
          color: const Color(0xFF0D9488).withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowKuat => [
        BoxShadow(
          color: const Color(0xFF0D9488).withOpacity(0.25),
          blurRadius: 30,
          offset: const Offset(0, 8),
        ),
      ];

  static BoxDecoration get kartuUtama => BoxDecoration(
        color: WarnaAcakehan.kartuTerang,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadowKartu,
      );

  static BoxDecoration get kartuGradienSaldo => const BoxDecoration(
        gradient: GradienAcakehan.kartuSaldo,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      );
}

// ── ThemeData Flutter ─────────────────────────────────────────
class TemaAcakehan {
  TemaAcakehan._();

  static ThemeData get temaTerang {
    const ColorScheme skemaWarna = ColorScheme(
      brightness: Brightness.light,
      primary:            WarnaAcakehan.primer,
      onPrimary:          Colors.white,
      primaryContainer:   WarnaAcakehan.primerPudar,
      onPrimaryContainer: WarnaAcakehan.primerSangat,
      secondary:          WarnaAcakehan.aksen,
      onSecondary:        Colors.white,
      secondaryContainer: WarnaAcakehan.aksenMuda,
      onSecondaryContainer: WarnaAcakehan.aksenGelap,
      error:              WarnaAcakehan.pengeluaran,
      onError:            Colors.white,
      errorContainer:     WarnaAcakehan.pengeluaranBg,
      onErrorContainer:   Color(0xFF7F1D1D),
      surface:            WarnaAcakehan.latarTerang,
      onSurface:          WarnaAcakehan.abu900,
      surfaceContainerHighest: WarnaAcakehan.abu100,
      outline:            WarnaAcakehan.abu300,
    );

    return ThemeData(
      useMaterial3:     true,
      colorScheme:      skemaWarna,
      fontFamily:       'Nunito',

      // ── AppBar ─────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation:       0,
        scrolledUnderElevation: 0,
        centerTitle:     false,
        titleTextStyle:  TextStyle(
          fontFamily:  'Sora',
          fontSize:    20,
          fontWeight:  FontWeight.w700,
          color:       WarnaAcakehan.abu900,
          letterSpacing: -0.3,
        ),
        iconTheme:       IconThemeData(color: WarnaAcakehan.abu800),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:           Colors.transparent,
          statusBarIconBrightness:  Brightness.dark,
        ),
      ),

      // ── Input / TextField ──────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   WarnaAcakehan.abu100,
        border:      OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: WarnaAcakehan.abu200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: WarnaAcakehan.primer, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: WarnaAcakehan.pengeluaran, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(
          color:      WarnaAcakehan.abu400,
          fontSize:   15,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color:      WarnaAcakehan.abu500,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: WarnaAcakehan.abu400,
        suffixIconColor: WarnaAcakehan.abu400,
      ),

      // ── ElevatedButton ─────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:   WarnaAcakehan.primer,
          foregroundColor:   Colors.white,
          elevation:         0,
          shadowColor:       Colors.transparent,
          padding:           const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:             RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily:  'Nunito',
            fontSize:    16,
            fontWeight:  FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Card ───────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation:    0,
        color:        WarnaAcakehan.kartuTerang,
        shape:        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin:       EdgeInsets.zero,
      ),

      // ── BottomNavigationBar ────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:          Colors.white,
        selectedItemColor:        WarnaAcakehan.primer,
        unselectedItemColor:      WarnaAcakehan.abu400,
        selectedLabelStyle:       TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle:     TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        elevation:                0,
        type:                     BottomNavigationBarType.fixed,
      ),

      // ── Scaffold ───────────────────────────────────────────
      scaffoldBackgroundColor: WarnaAcakehan.latarTerang,

      // ── Chip ───────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: WarnaAcakehan.abu100,
        selectedColor:   WarnaAcakehan.primerPudar,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Divider ────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color:     WarnaAcakehan.abu100,
        thickness: 1,
        space:     1,
      ),
    );
  }
}
