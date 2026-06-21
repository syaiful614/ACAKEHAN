// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/presentation/widgets/common/widget_umum.dart
//  Fungsi : Koleksi widget yang dipakai ulang di seluruh app:
//           TombolGradien, KartuInfo, SkeletonLoading, dsb.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/tema_acakehan.dart';

// ============================================================
//  WIDGET: TombolGradien
//  Tombol penuh lebar dengan efek gradien dan loading state
// ============================================================
class TombolGradien extends StatelessWidget {
  final String       teks;
  final VoidCallback? onTap;
  final bool         sedangMemuat;
  final IconData?    ikon;
  final double       tinggi;

  const TombolGradien({
    super.key,
    required this.teks,
    this.onTap,
    this.sedangMemuat = false,
    this.ikon,
    this.tinggi = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sedangMemuat ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: tinggi,
        decoration: BoxDecoration(
          gradient: onTap == null || sedangMemuat
              ? LinearGradient(colors: [
                  WarnaAcakehan.abu300,
                  WarnaAcakehan.abu400,
                ])
              : GradienAcakehan.tombolPrimer,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null && !sedangMemuat
              ? [
                  BoxShadow(
                    color: WarnaAcakehan.primer.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: sedangMemuat
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color:       Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ikon != null) ...[
                      Icon(ikon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      teks,
                      style: const TextStyle(
                        color:       Colors.white,
                        fontSize:    16,
                        fontWeight:  FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ============================================================
//  WIDGET: KolamInputKustom
//  TextField yang sudah disesuaikan tema Acakehan
// ============================================================
class KolamInputKustom extends StatefulWidget {
  final String         label;
  final String         hint;
  final IconData       ikon;
  final bool           isKataSandi;
  final TextEditingController kontroler;
  final String?        Function(String?)? validator;
  final TextInputType  jenisKeyboard;
  final TextInputAction aksiKeyboard;

  const KolamInputKustom({
    super.key,
    required this.label,
    required this.hint,
    required this.ikon,
    required this.kontroler,
    this.isKataSandi     = false,
    this.validator,
    this.jenisKeyboard   = TextInputType.text,
    this.aksiKeyboard    = TextInputAction.next,
  });

  @override
  State<KolamInputKustom> createState() => _KolamInputKustumState();
}

class _KolamInputKustumState extends State<KolamInputKustom> {
  bool _sembunyikanTeks = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:  widget.kontroler,
      obscureText: widget.isKataSandi && _sembunyikanTeks,
      keyboardType: widget.jenisKeyboard,
      textInputAction: widget.aksiKeyboard,
      validator:   widget.validator,
      style: const TextStyle(
        fontSize:   15,
        fontWeight: FontWeight.w500,
        color:      WarnaAcakehan.abu800,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText:  widget.hint,
        prefixIcon: Icon(widget.ikon, size: 20),
        suffixIcon: widget.isKataSandi
            ? IconButton(
                icon: Icon(
                  _sembunyikanTeks ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20,
                ),
                onPressed: () => setState(() => _sembunyikanTeks = !_sembunyikanTeks),
              )
            : null,
      ),
    );
  }
}

// ============================================================
//  WIDGET: KartuRingkasan
//  Kartu statistik kecil dengan label, nilai, dan ikon
// ============================================================
class KartuRingkasan extends StatelessWidget {
  final String  label;
  final String  nilai;
  final IconData ikon;
  final Color   warnaIkon;
  final Color   warnaBgIkon;
  final bool    isPositif;

  const KartuRingkasan({
    super.key,
    required this.label,
    required this.nilai,
    required this.ikon,
    required this.warnaIkon,
    required this.warnaBgIkon,
    this.isPositif = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DekorasiAcakehan.kartuUtama,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        warnaBgIkon,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(ikon, color: warnaIkon, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize:   12,
              fontWeight: FontWeight.w600,
              color:      WarnaAcakehan.abu500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nilai,
            style: TextStyle(
              fontSize:   15,
              fontWeight: FontWeight.w800,
              color:      warnaIkon,
              fontFamily: 'Sora',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  WIDGET: SkeletonMuat
//  Shimmer placeholder saat data sedang dimuat
// ============================================================
class SkeletonMuat extends StatelessWidget {
  final double lebar;
  final double tinggi;
  final double radiusBorder;

  const SkeletonMuat({
    super.key,
    this.lebar        = double.infinity,
    this.tinggi       = 16,
    this.radiusBorder = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor:      WarnaAcakehan.abu200,
      highlightColor: WarnaAcakehan.abu100,
      child: Container(
        width:  lebar,
        height: tinggi,
        decoration: BoxDecoration(
          color:        WarnaAcakehan.abu200,
          borderRadius: BorderRadius.circular(radiusBorder),
        ),
      ),
    );
  }
}

// ============================================================
//  WIDGET: KotakKosong
//  Tampilan state kosong ketika tidak ada data
// ============================================================
class KotakKosong extends StatelessWidget {
  final String  judul;
  final String  deskripsi;
  final IconData ikon;
  final Widget? aksi;

  const KotakKosong({
    super.key,
    required this.judul,
    required this.deskripsi,
    this.ikon  = Icons.inbox_rounded,
    this.aksi,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:        WarnaAcakehan.abu100,
                shape:        BoxShape.circle,
              ),
              child: Icon(ikon, size: 48, color: WarnaAcakehan.abu400),
            ),
            const SizedBox(height: 20),
            Text(
              judul,
              style: const TextStyle(
                fontSize:   17,
                fontWeight: FontWeight.w700,
                color:      WarnaAcakehan.abu700,
                fontFamily: 'Sora',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              deskripsi,
              style: const TextStyle(
                fontSize:  14,
                color:     WarnaAcakehan.abu500,
                height:    1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (aksi != null) ...[
              const SizedBox(height: 24),
              aksi!,
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }
}

// ============================================================
//  WIDGET: BannerError
//  Banner merah untuk menampilkan pesan error
// ============================================================
class BannerError extends StatelessWidget {
  final String pesan;
  final VoidCallback? onTutup;

  const BannerError({
    super.key,
    required this.pesan,
    this.onTutup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        WarnaAcakehan.pengeluaranBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: WarnaAcakehan.pengeluaran.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_rounded, color: WarnaAcakehan.pengeluaran, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pesan,
              style: const TextStyle(
                color:      WarnaAcakehan.pengeluaran,
                fontSize:   13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onTutup != null)
            GestureDetector(
              onTap: onTutup,
              child: const Icon(Icons.close_rounded, color: WarnaAcakehan.pengeluaran, size: 18),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2);
  }
}
