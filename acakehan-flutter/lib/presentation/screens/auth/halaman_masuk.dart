// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/presentation/screens/auth/halaman_masuk.dart
//  Fungsi : Halaman Login — form email & kata sandi,
//           validasi input, animasi masuk, koneksi ke API.
//  Estetik: Dark teal gradient background, kartu putih mengambang,
//           tipografi Sora bold, input fields bergaya soft-fill.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/provider_auth.dart';
import '../../theme/tema_acakehan.dart';
import '../../widgets/common/widget_umum.dart';
import '../../../core/constants/konstanta_app.dart';

class HalamanMasuk extends ConsumerStatefulWidget {
  const HalamanMasuk({super.key});

  @override
  ConsumerState<HalamanMasuk> createState() => _HalamanMasukState();
}

class _HalamanMasukState extends ConsumerState<HalamanMasuk>
    with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────
  final _kunciForm       = GlobalKey<FormState>();
  final _kontrolerEmail  = TextEditingController();
  final _kontrolerSandi  = TextEditingController();

  // ── Animation controller untuk efek logo ──────────────────
  late final AnimationController _kontrolerAnim;
  late final Animation<double>   _animSkala;

  @override
  void initState() {
    super.initState();
    _kontrolerAnim = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    );
    _animSkala = CurvedAnimation(
      parent: _kontrolerAnim,
      curve:  Curves.elasticOut,
    );
    // Mulai animasi setelah frame pertama selesai render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kontrolerAnim.forward();
    });
  }

  @override
  void dispose() {
    _kontrolerAnim.dispose();
    _kontrolerEmail.dispose();
    _kontrolerSandi.dispose();
    super.dispose();
  }

  // ── Aksi Login ────────────────────────────────────────────
  Future<void> _prosesLogin() async {
    // Sembunyikan keyboard
    FocusScope.of(context).unfocus();

    // Validasi form sebelum kirim request
    if (!(_kunciForm.currentState?.validate() ?? false)) return;

    final berhasil = await ref.read(providerAuthNotifier.notifier).masuk(
          email:     _kontrolerEmail.text.trim(),
          kataSandi: _kontrolerSandi.text,
        );

    if (berhasil && mounted) {
      // Navigasi ke dashboard setelah login berhasil
      context.go(NamaRoute.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAuth  = ref.watch(providerAuthNotifier);
    final ukuranLayar = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        children: [
          // ── Latar Belakang Gradien ─────────────────────────
          Container(
            width:  double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: GradienAcakehan.latarLogin,
            ),
          ),

          // ── Motif dekoratif lingkaran besar (subtle) ───────
          Positioned(
            top:   -80,
            right: -60,
            child: Container(
              width:  250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WarnaAcakehan.primer.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left:   -40,
            child: Container(
              width:  200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WarnaAcakehan.primerMuda.withOpacity(0.1),
              ),
            ),
          ),

          // ── Konten Utama ───────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: ukuranLayar.height -
                      MediaQuery.paddingOf(context).top -
                      MediaQuery.paddingOf(context).bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 48),

                      // ── Logo & Nama Aplikasi ─────────────────
                      _bangunBagianLogo(),

                      const SizedBox(height: 40),

                      // ── Kartu Form Login ─────────────────────
                      _bangunKartuForm(stateAuth),

                      const SizedBox(height: 24),

                      // ── Tautan ke Halaman Daftar ─────────────
                      _bangunTautanDaftar(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Builder: Bagian Logo ──────────────────────────────────
  Widget _bangunBagianLogo() {
    return Column(
      children: [
        // Logo animasi dengan ScaleTransition
        ScaleTransition(
          scale: _animSkala,
          child: Container(
            width:  84,
            height: 84,
            decoration: BoxDecoration(
              gradient:     GradienAcakehan.tombolPrimer,
              borderRadius: BorderRadius.circular(24),
              boxShadow:    DekorasiAcakehan.shadowKuat,
            ),
            child: const Center(
              child: Text(
                '₿',
                style: TextStyle(
                  fontSize:  40,
                  color:     Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Nama aplikasi
        Text(
          TeksApp.namaAplikasi,
          style: const TextStyle(
            fontFamily:    'Sora',
            fontSize:      32,
            fontWeight:    FontWeight.w800,
            color:         Colors.white,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

        const SizedBox(height: 6),

        Text(
          TeksApp.tagline,
          style: TextStyle(
            fontSize:  13,
            color:     Colors.white.withOpacity(0.65),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
      ],
    );
  }

  // ── Builder: Kartu Form Login ─────────────────────────────
  Widget _bangunKartuForm(StateAuth stateAuth) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.2),
            blurRadius: 40,
            offset:     const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _kunciForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Judul kartu
            const Text(
              'Selamat Datang 👋',
              style: TextStyle(
                fontFamily:  'Sora',
                fontSize:    22,
                fontWeight:  FontWeight.w700,
                color:       WarnaAcakehan.abu900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Masuk untuk mulai mencatat keuangan',
              style: TextStyle(
                fontSize:  13,
                color:     WarnaAcakehan.abu500,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 28),

            // ── Input Email ───────────────────────────────────
            KolamInputKustom(
              label:       'Email',
              hint:        'nama@email.com',
              ikon:        Icons.email_rounded,
              kontroler:   _kontrolerEmail,
              jenisKeyboard: TextInputType.emailAddress,
              aksiKeyboard:  TextInputAction.next,
              validator: (nilai) {
                if (nilai == null || nilai.trim().isEmpty) {
                  return 'Email tidak boleh kosong';
                }
                final polaEmail = RegExp(r'^[\w\-\.]+@[\w\-]+\.[a-z]{2,}$');
                if (!polaEmail.hasMatch(nilai.trim())) {
                  return 'Format email tidak valid';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Input Kata Sandi ──────────────────────────────
            KolamInputKustom(
              label:       'Kata Sandi',
              hint:        'Minimal 8 karakter',
              ikon:        Icons.lock_rounded,
              kontroler:   _kontrolerSandi,
              isKataSandi: true,
              aksiKeyboard: TextInputAction.done,
              validator: (nilai) {
                if (nilai == null || nilai.isEmpty) {
                  return 'Kata sandi tidak boleh kosong';
                }
                if (nilai.length < 8) {
                  return 'Kata sandi minimal 8 karakter';
                }
                return null;
              },
            ),

            // ── Lupa Kata Sandi ───────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: implementasi fitur lupa kata sandi
                },
                child: const Text(
                  'Lupa kata sandi?',
                  style: TextStyle(
                    color:     WarnaAcakehan.primer,
                    fontWeight: FontWeight.w600,
                    fontSize:  13,
                  ),
                ),
              ),
            ),

            // ── Banner Error ──────────────────────────────────
            if (stateAuth.pesanError != null) ...[
              const SizedBox(height: 4),
              BannerError(
                pesan: stateAuth.pesanError!,
                onTutup: () =>
                    ref.read(providerAuthNotifier.notifier).hapusError(),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 8),

            // ── Tombol Masuk ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: TombolGradien(
                teks:         'Masuk',
                onTap:        _prosesLogin,
                sedangMemuat: stateAuth.sedangMemuat,
                ikon:         Icons.login_rounded,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 600.ms)
        .slideY(begin: 0.2, curve: Curves.easeOutCubic);
  }

  // ── Builder: Tautan Daftar ────────────────────────────────
  Widget _bangunTautanDaftar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Belum punya akun? ',
          style: TextStyle(
            color:     Colors.white.withOpacity(0.7),
            fontSize:  14,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          onTap: () => context.push(NamaRoute.daftar),
          child: const Text(
            'Daftar Sekarang',
            style: TextStyle(
              color:       WarnaAcakehan.primerMuda,
              fontSize:    14,
              fontWeight:  FontWeight.w700,
              decoration:  TextDecoration.underline,
              decorationColor: WarnaAcakehan.primerMuda,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms, duration: 500.ms);
  }
}
