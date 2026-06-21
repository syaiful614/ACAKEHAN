// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/presentation/screens/auth/halaman_daftar.dart
//  Fungsi : Halaman Registrasi — form nama, email, kata sandi,
//           konfirmasi kata sandi, validasi input, koneksi API.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/provider_auth.dart';
import '../../theme/tema_acakehan.dart';
import '../../widgets/common/widget_umum.dart';
import '../../../core/constants/konstanta_app.dart';

class HalamanDaftar extends ConsumerStatefulWidget {
  const HalamanDaftar({super.key});

  @override
  ConsumerState<HalamanDaftar> createState() => _HalamanDaftarState();
}

class _HalamanDaftarState extends ConsumerState<HalamanDaftar>
    with TickerProviderStateMixin {

  final _kunciForm              = GlobalKey<FormState>();
  final _kontrolerNama          = TextEditingController();
  final _kontrolerEmail         = TextEditingController();
  final _kontrolerSandi         = TextEditingController();
  final _kontrolerKonfirmasiSandi = TextEditingController();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kontrolerAnim.forward();
    });
  }

  @override
  void dispose() {
    _kontrolerAnim.dispose();
    _kontrolerNama.dispose();
    _kontrolerEmail.dispose();
    _kontrolerSandi.dispose();
    _kontrolerKonfirmasiSandi.dispose();
    super.dispose();
  }

  Future<void> _prosesDaftar() async {
    FocusScope.of(context).unfocus();
    if (!(_kunciForm.currentState?.validate() ?? false)) return;

    final berhasil = await ref.read(providerAuthNotifier.notifier).daftar(
      namaLengkap:          _kontrolerNama.text.trim(),
      email:                _kontrolerEmail.text.trim(),
      kataSandi:            _kontrolerSandi.text,
      konfirmasiKataSandi:  _kontrolerKonfirmasiSandi.text,
    );

    if (berhasil && mounted) {
      context.go(NamaRoute.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAuth   = ref.watch(providerAuthNotifier);
    final ukuranLayar = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        children: [
          // Latar gradien
          Container(
            width:  double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: GradienAcakehan.latarLogin,
            ),
          ),

          // Dekorasi lingkaran
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

          // Konten utama
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
                      const SizedBox(height: 40),
                      _bangunBagianLogo(),
                      const SizedBox(height: 32),
                      _bangunKartuForm(stateAuth),
                      const SizedBox(height: 24),
                      _bangunTautanMasuk(),
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

  Widget _bangunBagianLogo() {
    return Column(
      children: [
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
                  fontSize:   40,
                  color:      Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
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
          'Buat akun baru',
          style: TextStyle(
            fontSize:      13,
            color:         Colors.white.withOpacity(0.65),
            fontWeight:    FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
      ],
    );
  }

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
            const Text(
              'Daftar Akun 🎉',
              style: TextStyle(
                fontFamily:    'Sora',
                fontSize:      22,
                fontWeight:    FontWeight.w700,
                color:         WarnaAcakehan.abu900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Isi data diri untuk membuat akun baru',
              style: TextStyle(
                fontSize:   13,
                color:      WarnaAcakehan.abu500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),

            // Input Nama Lengkap
            KolamInputKustom(
              label:        'Nama Lengkap',
              hint:         'Nama lengkap Anda',
              ikon:         Icons.person_rounded,
              kontroler:    _kontrolerNama,
              aksiKeyboard: TextInputAction.next,
              validator: (nilai) {
                if (nilai == null || nilai.trim().isEmpty) {
                  return 'Nama lengkap tidak boleh kosong';
                }
                if (nilai.trim().length < 3) {
                  return 'Nama minimal 3 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Input Email
            KolamInputKustom(
              label:          'Email',
              hint:           'nama@email.com',
              ikon:           Icons.email_rounded,
              kontroler:      _kontrolerEmail,
              jenisKeyboard:  TextInputType.emailAddress,
              aksiKeyboard:   TextInputAction.next,
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

            // Input Kata Sandi
            KolamInputKustom(
              label:        'Kata Sandi',
              hint:         'Minimal 8 karakter',
              ikon:         Icons.lock_rounded,
              kontroler:    _kontrolerSandi,
              isKataSandi:  true,
              aksiKeyboard: TextInputAction.next,
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
            const SizedBox(height: 16),

            // Input Konfirmasi Kata Sandi
            KolamInputKustom(
              label:        'Konfirmasi Kata Sandi',
              hint:         'Ulangi kata sandi',
              ikon:         Icons.lock_outline_rounded,
              kontroler:    _kontrolerKonfirmasiSandi,
              isKataSandi:  true,
              aksiKeyboard: TextInputAction.done,
              validator: (nilai) {
                if (nilai == null || nilai.isEmpty) {
                  return 'Konfirmasi kata sandi tidak boleh kosong';
                }
                if (nilai != _kontrolerSandi.text) {
                  return 'Kata sandi tidak cocok';
                }
                return null;
              },
            ),

            // Banner Error
            if (stateAuth.pesanError != null) ...[
              const SizedBox(height: 16),
              BannerError(
                pesan:   stateAuth.pesanError!,
                onTutup: () =>
                    ref.read(providerAuthNotifier.notifier).hapusError(),
              ),
            ],

            const SizedBox(height: 24),

            // Tombol Daftar
            SizedBox(
              width: double.infinity,
              child: TombolGradien(
                teks:         'Daftar Sekarang',
                onTap:        _prosesDaftar,
                sedangMemuat: stateAuth.sedangMemuat,
                ikon:         Icons.person_add_rounded,
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

  Widget _bangunTautanMasuk() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Sudah punya akun? ',
          style: TextStyle(
            color:      Colors.white.withOpacity(0.7),
            fontSize:   14,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          onTap: () => context.pop(),
          child: const Text(
            'Masuk',
            style: TextStyle(
              color:           WarnaAcakehan.primerMuda,
              fontSize:        14,
              fontWeight:      FontWeight.w700,
              decoration:      TextDecoration.underline,
              decorationColor: WarnaAcakehan.primerMuda,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms, duration: 500.ms);
  }
}
