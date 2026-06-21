// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/presentation/screens/dashboard/halaman_dashboard.dart
//  Fungsi : Halaman Dashboard Utama — menampilkan:
//           • Kartu saldo bersih bulan ini
//           • Ringkasan pemasukan & pengeluaran
//           • Grafik pie pengeluaran per kategori
//           • Status progress bar anggaran
//           • Daftar transaksi terbaru
//           • Bottom navigation bar
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/konstanta_app.dart';
import '../../../core/utils/format_helper.dart';
import '../../../data/repositories/repositori_dashboard.dart';
import '../../providers/provider_auth.dart';
import '../../providers/provider_dashboard.dart';
import '../../theme/tema_acakehan.dart';
import '../../widgets/common/widget_umum.dart';
import '../../widgets/dashboard/widget_dashboard.dart';

class HalamanDashboard extends ConsumerStatefulWidget {
  const HalamanDashboard({super.key});

  @override
  ConsumerState<HalamanDashboard> createState() => _HalamanDashboardState();
}

class _HalamanDashboardState extends ConsumerState<HalamanDashboard> {
  int _indeksTabAktif = 0;
  final _kontrolerScroll = ScrollController();

  @override
  void dispose() {
    _kontrolerScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:           Colors.transparent,
        statusBarIconBrightness:  Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: WarnaAcakehan.latarTerang,
        body: IndexedStack(
          index: _indeksTabAktif,
          children: const [
            _TabDashboard(),
            _TabTransaksi(),
            _TabAnggaran(),
            _TabProfil(),
          ],
        ),

        // ── Bottom Navigation Bar ──────────────────────────
        bottomNavigationBar: _BottomNavBar(
          indeksAktif: _indeksTabAktif,
          onPilih:     (i) => setState(() => _indeksTabAktif = i),
        ),

        // ── FAB: Tambah Transaksi ──────────────────────────
        floatingActionButton: _FabTambahTransaksi(
          onTap: () => _tampilkanFormTransaksi(context),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  void _tampilkanFormTransaksi(BuildContext context) {
    showModalBottomSheet(
      context:         context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:         (_) => const _FormTambahTransaksi(),
    );
  }
}

// ============================================================
//  TAB 1: Dashboard Utama
// ============================================================
class _TabDashboard extends ConsumerWidget {
  const _TabDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataDashboard  = ref.watch(providerDashboard);
    final penggunaAktif  = ref.watch(providerPenggunaAktif);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color:           WarnaAcakehan.primer,
        onRefresh:       () => ref.refresh(providerDashboard.future),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header App ─────────────────────────────────
            SliverToBoxAdapter(
              child: _HeaderDashboard(
                namaPengguna: penggunaAktif?.namaLengkap ?? 'Pengguna',
                inisial:      penggunaAktif?.inisialNama ?? 'AC',
              ),
            ),

            // ── Konten berdasarkan state data ──────────────
            dataDashboard.when(
              loading: () => const SliverToBoxAdapter(
                child: _SkeletonDashboard(),
              ),
              error: (galat, _) => SliverToBoxAdapter(
                child: _TampilError(
                  pesan:    galat.toString().replaceFirst('Exception: ', ''),
                  onCoba:   () => ref.invalidate(providerDashboard),
                ),
              ),
              data: (dashboard) => SliverToBoxAdapter(
                child: _IsiDashboard(dashboard: dashboard),
              ),
            ),

            // ── Padding bawah untuk bottom nav ─────────────
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }
}

// ── Header dengan nama pengguna dan avatar ─────────────────────
class _HeaderDashboard extends StatelessWidget {
  final String namaPengguna;
  final String inisial;

  const _HeaderDashboard({
    required this.namaPengguna,
    required this.inisial,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _sapaanWaktu(),
                style: const TextStyle(
                  fontSize:   13,
                  color:      WarnaAcakehan.abu500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                namaPengguna,
                style: const TextStyle(
                  fontFamily:  'Sora',
                  fontSize:    20,
                  fontWeight:  FontWeight.w700,
                  color:       WarnaAcakehan.abu900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Ikon notifikasi
          Consumer(
            builder: (_, ref, __) {
              final dashboard = ref.watch(providerDashboard).valueOrNull;
              final jumlahNotif = dashboard?.notifikasiBelumDibaca ?? 0;
              return Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:        Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow:    DekorasiAcakehan.shadowKartu,
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: WarnaAcakehan.abu700,
                      size:  22,
                    ),
                  ),
                  if (jumlahNotif > 0)
                    Positioned(
                      top:   0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: WarnaAcakehan.pengeluaran,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          jumlahNotif > 9 ? '9+' : '$jumlahNotif',
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          const SizedBox(width: 10),

          // Avatar pengguna
          Container(
            width:  40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: GradienAcakehan.tombolPrimer,
              shape:    BoxShape.circle,
            ),
            child: Center(
              child: Text(
                inisial,
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  String _sapaanWaktu() {
    final jam = DateTime.now().hour;
    if (jam < 12) return '☀️ Selamat Pagi,';
    if (jam < 15) return '🌤️ Selamat Siang,';
    if (jam < 18) return '🌅 Selamat Sore,';
    return '🌙 Selamat Malam,';
  }
}

// ── Isi utama dashboard setelah data berhasil dimuat ──────────
class _IsiDashboard extends StatelessWidget {
  final dashboard;

  const _IsiDashboard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Kartu Saldo Utama ───────────────────────────
          KartuSaldoUtama(
            ringkasan:     dashboard.ringkasanBulanIni,
            namaPengguna:  'Pengguna',
          ),

          const SizedBox(height: 24),

          // ── Grafik Pengeluaran per Kategori ─────────────
          _JudulSeksi(
            judul:    'Distribusi Pengeluaran',
            subJudul: FormatHelper.labelPeriode(
              dashboard.ringkasanBulanIni.bulan,
              dashboard.ringkasanBulanIni.tahun,
            ),
          ),
          const SizedBox(height: 12),

          GrafikPiePengeluaran(
            data: dashboard.pengeluaranPerKategori,
          ),

          const SizedBox(height: 24),

          // ── Status Anggaran ─────────────────────────────
          if (dashboard.statusSemuaAnggaran.isNotEmpty) ...[
            _JudulSeksi(
              judul:    'Status Anggaran',
              subJudul: 'Bulan ini',
              aksi:     TextButton(
                onPressed: () {},
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    color:      WarnaAcakehan.primer,
                    fontWeight: FontWeight.w700,
                    fontSize:   13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            ...dashboard.statusSemuaAnggaran
                .take(3)
                .map((a) => BarProgressAnggaran(anggaran: a)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: 0.05)),
          ],

          const SizedBox(height: 24),

          // ── Transaksi Terbaru ───────────────────────────
          _JudulSeksi(
            judul:    'Transaksi Terbaru',
            subJudul: 'Aktivitas keuangan terakhir',
            aksi:     TextButton(
              onPressed: () {},
              child: const Text(
                'Lihat Semua',
                style: TextStyle(
                  color:      WarnaAcakehan.primer,
                  fontWeight: FontWeight.w700,
                  fontSize:   13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Daftar transaksi dari provider terpisah
          Consumer(
            builder: (_, ref, __) {
              final stateTransaksi = ref.watch(providerTransaksiNotifier);

              if (stateTransaksi.sedangMemuat) {
                return Column(
                  children: List.generate(
                    3,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SkeletonMuat(tinggi: 72, radiusBorder: 16),
                    ),
                  ),
                );
              }

              if (stateTransaksi.daftarTransaksi.isEmpty) {
                return const KotakKosong(
                  judul:      'Belum Ada Transaksi',
                  deskripsi:  'Tekan tombol + untuk mulai mencatat keuangan.',
                  ikon:       Icons.receipt_long_rounded,
                );
              }

              return Column(
                children: stateTransaksi.daftarTransaksi
                    .take(5)
                    .map((t) => ItemTransaksi(transaksi: t)
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideX(begin: 0.05))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Judul seksi dengan subJudul dan aksi ──────────────────────
class _JudulSeksi extends StatelessWidget {
  final String  judul;
  final String  subJudul;
  final Widget? aksi;

  const _JudulSeksi({
    required this.judul,
    required this.subJudul,
    this.aksi,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              judul,
              style: const TextStyle(
                fontFamily:  'Sora',
                fontSize:    16,
                fontWeight:  FontWeight.w700,
                color:       WarnaAcakehan.abu900,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              subJudul,
              style: const TextStyle(
                fontSize:  12,
                color:     WarnaAcakehan.abu400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (aksi != null) ...[const Spacer(), aksi!],
      ],
    );
  }
}

// ── Skeleton loading ──────────────────────────────────────────
class _SkeletonDashboard extends StatelessWidget {
  const _SkeletonDashboard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          SkeletonMuat(tinggi: 200, radiusBorder: 28),
          const SizedBox(height: 24),
          SkeletonMuat(tinggi: 280, radiusBorder: 20),
          const SizedBox(height: 16),
          ...List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SkeletonMuat(tinggi: 72, radiusBorder: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tampilan error ────────────────────────────────────────────
class _TampilError extends StatelessWidget {
  final String       pesan;
  final VoidCallback onCoba;

  const _TampilError({required this.pesan, required this.onCoba});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          BannerError(pesan: pesan),
          const SizedBox(height: 16),
          TombolGradien(
            teks:  'Coba Lagi',
            onTap: onCoba,
            ikon:  Icons.refresh_rounded,
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  TAB 2–4: Placeholder (dikembangkan di sprint berikutnya)
// ============================================================
class _TabTransaksi extends StatelessWidget {
  const _TabTransaksi();

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderTab(
      judul: 'Transaksi',
      ikon:  Icons.receipt_long_rounded,
    );
  }
}

class _TabAnggaran extends StatelessWidget {
  const _TabAnggaran();

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderTab(
      judul: 'Anggaran',
      ikon:  Icons.account_balance_wallet_rounded,
    );
  }
}

class _TabProfil extends ConsumerWidget {
  const _TabProfil();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pengguna = ref.watch(providerPenggunaAktif);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width:  80,
              height: 80,
              decoration: const BoxDecoration(
                gradient: GradienAcakehan.tombolPrimer,
                shape:    BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  pengguna?.inisialNama ?? 'AC',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              pengguna?.namaLengkap ?? '-',
              style: const TextStyle(
                fontFamily:  'Sora',
                fontSize:    20,
                fontWeight:  FontWeight.w700,
                color:       WarnaAcakehan.abu900,
              ),
            ),
            Text(
              pengguna?.email ?? '-',
              style: const TextStyle(
                fontSize:  14,
                color:     WarnaAcakehan.abu400,
              ),
            ),
            const SizedBox(height: 40),
            TombolGradien(
              teks:  'Keluar dari Akun',
              onTap: () async {
                await ref.read(providerAuthNotifier.notifier).keluar();
                if (context.mounted) context.go(NamaRoute.masuk);
              },
              ikon:  Icons.logout_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String   judul;
  final IconData ikon;

  const _PlaceholderTab({required this.judul, required this.ikon});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: KotakKosong(
        judul:      judul,
        deskripsi:  'Fitur ini akan tersedia di versi berikutnya.',
        ikon:       ikon,
      ),
    );
  }
}

// ============================================================
//  Bottom Navigation Bar Kustom
// ============================================================
class _BottomNavBar extends StatelessWidget {
  final int               indeksAktif;
  final ValueChanged<int> onPilih;

  const _BottomNavBar({required this.indeksAktif, required this.onPilih});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset:     const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ItemNavBar(ikon: Icons.home_rounded,                   label: 'Beranda',   indeks: 0, aktif: indeksAktif, onTap: onPilih),
              _ItemNavBar(ikon: Icons.receipt_long_rounded,           label: 'Transaksi', indeks: 1, aktif: indeksAktif, onTap: onPilih),
              const SizedBox(width: 48),
              _ItemNavBar(ikon: Icons.account_balance_wallet_rounded, label: 'Anggaran',  indeks: 2, aktif: indeksAktif, onTap: onPilih),
              _ItemNavBar(ikon: Icons.person_rounded,                 label: 'Profil',    indeks: 3, aktif: indeksAktif, onTap: onPilih),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemNavBar extends StatelessWidget {
  final IconData          ikon;
  final String            label;
  final int               indeks;
  final int               aktif;
  final ValueChanged<int> onTap;

  const _ItemNavBar({
    required this.ikon,
    required this.label,
    required this.indeks,
    required this.aktif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAktif = indeks == aktif;
    return GestureDetector(
      onTap:    () => onTap(indeks),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration:  const Duration(milliseconds: 200),
        padding:   const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color:        isAktif ? WarnaAcakehan.primerPudar : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ikon,
              color: isAktif ? WarnaAcakehan.primer : WarnaAcakehan.abu400,
              size:  22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize:   10,
                fontWeight: isAktif ? FontWeight.w700 : FontWeight.w500,
                color:      isAktif ? WarnaAcakehan.primer : WarnaAcakehan.abu400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  FAB Tambah Transaksi
// ============================================================
class _FabTambahTransaksi extends StatelessWidget {
  final VoidCallback onTap;
  const _FabTambahTransaksi({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  56,
        height: 56,
        decoration: BoxDecoration(
          gradient:  GradienAcakehan.tombolPrimer,
          shape:     BoxShape.circle,
          boxShadow: DekorasiAcakehan.shadowKuat,
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ============================================================
//  Bottom Sheet: Form Tambah Transaksi
// ============================================================
class _FormTambahTransaksi extends ConsumerStatefulWidget {
  const _FormTambahTransaksi();

  @override
  ConsumerState<_FormTambahTransaksi> createState() =>
      _FormTambahTransaksiState();
}

class _FormTambahTransaksiState extends ConsumerState<_FormTambahTransaksi> {
  final _kunciForm        = GlobalKey<FormState>();
  final _kontrolerJumlah  = TextEditingController();
  final _kontrolerCatatan = TextEditingController();

  String _tipeTransaksi      = 'pengeluaran';
  int?   _kategoriIdTerpilih;
  bool   _sedangMenyimpan    = false;

  @override
  void dispose() {
    _kontrolerJumlah.dispose();
    _kontrolerCatatan.dispose();
    super.dispose();
  }

  Future<void> _simpanTransaksi() async {
    if (!(_kunciForm.currentState?.validate() ?? false)) return;
    if (_kategoriIdTerpilih == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori terlebih dahulu.'),
          backgroundColor: WarnaAcakehan.pengeluaran,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sedangMenyimpan = true);

    try {
      final repositori = ref.read(repositoriTransaksiProvider);
      final transaksi  = await repositori.tambahTransaksi(
        kategoriId:       _kategoriIdTerpilih!,
        jumlahNominal:    double.parse(_kontrolerJumlah.text.replaceAll('.', '')),
        tipeTransaksi:    _tipeTransaksi,
        tanggalTransaksi: DateTime.now().toIso8601String().substring(0, 10),
        catatanTambahan:  _kontrolerCatatan.text.isNotEmpty
            ? _kontrolerCatatan.text
            : null,
      );

      ref.read(providerTransaksiNotifier.notifier).tambahkanKeLokal(transaksi);
      ref.invalidate(providerDashboard);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         const Text('Transaksi berhasil dicatat!'),
            backgroundColor: WarnaAcakehan.pemasukan,
            behavior:        SnackBarBehavior.floating,
            shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (galat) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text(galat.toString().replaceFirst('Exception: ', '')),
            backgroundColor: WarnaAcakehan.pengeluaran,
            behavior:        SnackBarBehavior.floating,
            shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sedangMenyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left:   24,
        right:  24,
        top:    24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _kunciForm,
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width:  40,
                height: 4,
                decoration: BoxDecoration(
                  color:        WarnaAcakehan.abu200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Catat Transaksi',
              style: TextStyle(
                fontFamily:    'Sora',
                fontSize:      20,
                fontWeight:    FontWeight.w700,
                color:         WarnaAcakehan.abu900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color:        WarnaAcakehan.abu100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: ['pengeluaran', 'pemasukan'].map((tipe) {
                  final isAktif = _tipeTransaksi == tipe;
                  final warna   = tipe == 'pemasukan'
                      ? WarnaAcakehan.pemasukan
                      : WarnaAcakehan.pengeluaran;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _tipeTransaksi = tipe;
                        _kategoriIdTerpilih = null;
                      }),
                      child: AnimatedContainer(
                        duration:  const Duration(milliseconds: 200),
                        margin:    const EdgeInsets.all(4),
                        padding:   const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color:        isAktif ? warna : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Text(
                            tipe == 'pemasukan' ? 'Pemasukan' : 'Pengeluaran',
                            style: TextStyle(
                              color:      isAktif ? Colors.white : WarnaAcakehan.abu500,
                              fontWeight: FontWeight.w700,
                              fontSize:   14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Dropdown Kategori (terfilter sesuai tipe transaksi) ──
            Consumer(
              builder: (_, ref, __) {
                final kategoriAsync = ref.watch(providerDaftarKategori);
                return kategoriAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  ),
                  error: (galat, _) => Text(
                    'Gagal memuat kategori: ${galat.toString().replaceFirst('Exception: ', '')}',
                    style: const TextStyle(color: WarnaAcakehan.pengeluaran, fontSize: 12),
                  ),
                  data: (daftarKategori) {
                    final kategoriTerfilter = daftarKategori
                        .where((k) => k.tipeKategori == _tipeTransaksi)
                        .toList();

                    if (kategoriTerfilter.isEmpty) {
                      return const Text(
                        'Belum ada kategori untuk tipe ini.',
                        style: TextStyle(color: WarnaAcakehan.abu400, fontSize: 13),
                      );
                    }

                    // Reset pilihan jika kategori sebelumnya tidak ada di daftar terfilter
                    final idMasihValid = kategoriTerfilter
                        .any((k) => k.kategoriId == _kategoriIdTerpilih);
                    final nilaiDropdown = idMasihValid ? _kategoriIdTerpilih : null;

                    return DropdownButtonFormField<int>(
                      value: nilaiDropdown,
                      decoration: const InputDecoration(
                        label:      Text('Kategori'),
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                      items: kategoriTerfilter.map((k) {
                        return DropdownMenuItem<int>(
                          value: k.kategoriId,
                          child: Text('${k.ikonKategori ?? ''} ${k.namaKategori}'.trim()),
                        );
                      }).toList(),
                      onChanged: (nilai) => setState(() => _kategoriIdTerpilih = nilai),
                      validator: (v) => v == null ? 'Pilih kategori terlebih dahulu' : null,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller:   _kontrolerJumlah,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize:   22,
                fontWeight: FontWeight.w800,
                fontFamily: 'Sora',
                color:      WarnaAcakehan.abu900,
              ),
              decoration: const InputDecoration(
                prefixText:  'Rp ',
                prefixStyle: TextStyle(
                  fontSize:   22,
                  fontWeight: FontWeight.w800,
                  color:      WarnaAcakehan.abu500,
                ),
                hintText: '0',
                label:    Text('Jumlah'),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Jumlah wajib diisi';
                final angka = double.tryParse(v.replaceAll('.', ''));
                if (angka == null || angka <= 0) return 'Jumlah harus lebih dari 0';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller:      _kontrolerCatatan,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                label:      Text('Catatan (opsional)'),
                hintText:   'Contoh: Makan siang kantor',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: TombolGradien(
                teks:         'Simpan Transaksi',
                onTap:        _simpanTransaksi,
                sedangMemuat: _sedangMenyimpan,
                ikon:         Icons.check_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}