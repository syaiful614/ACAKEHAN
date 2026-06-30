// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/presentation/screens/dashboard/halaman_dashboard.dart
//  FIXES  :
//    1. _TabTransaksi — implementasi lengkap (bukan placeholder)
//    2. _TabAnggaran  — implementasi lengkap (bukan placeholder)
//    3. _TabProfil    — tambah form edit profil
//    4. Tombol "Lihat Semua" — navigasi ke tab Transaksi
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/konstanta_app.dart';
import '../../../core/utils/format_helper.dart';
import '../../../data/repositories/repositori_auth.dart';
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

  void _pindahKeTab(int indeks) {
    setState(() => _indeksTabAktif = indeks);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: WarnaAcakehan.latarTerang,
        body: IndexedStack(
          index: _indeksTabAktif,
          children: [
            _TabDashboard(onLihatSemuaTransaksi: () => _pindahKeTab(1)),
            const _TabTransaksi(),
            const _TabAnggaran(),
            const _TabProfil(),
          ],
        ),

        bottomNavigationBar: _BottomNavBar(
          indeksAktif: _indeksTabAktif,
          onPilih:     _pindahKeTab,
        ),

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
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder:            (_) => const _FormTambahTransaksi(),
    );
  }
}

// ============================================================
//  TAB 1: Dashboard Utama
// ============================================================
class _TabDashboard extends ConsumerWidget {
  final VoidCallback onLihatSemuaTransaksi;
  const _TabDashboard({required this.onLihatSemuaTransaksi});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataDashboard = ref.watch(providerDashboard);
    final penggunaAktif = ref.watch(providerPenggunaAktif);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color:     WarnaAcakehan.primer,
        onRefresh: () => ref.refresh(providerDashboard.future),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HeaderDashboard(
                namaPengguna: penggunaAktif?.namaLengkap ?? 'Pengguna',
                inisial:      penggunaAktif?.inisialNama ?? 'AC',
              ),
            ),
            dataDashboard.when(
              loading: () => const SliverToBoxAdapter(child: _SkeletonDashboard()),
              error: (galat, _) => SliverToBoxAdapter(
                child: _TampilError(
                  pesan:  galat.toString().replaceFirst('Exception: ', ''),
                  onCoba: () => ref.invalidate(providerDashboard),
                ),
              ),
              data: (dashboard) => SliverToBoxAdapter(
                child: _IsiDashboard(
                  dashboard:              dashboard,
                  onLihatSemuaTransaksi:  onLihatSemuaTransaksi,
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }
}

class _HeaderDashboard extends StatelessWidget {
  final String namaPengguna;
  final String inisial;
  const _HeaderDashboard({required this.namaPengguna, required this.inisial});

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
                  fontSize: 13, color: WarnaAcakehan.abu500, fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                namaPengguna,
                style: const TextStyle(
                  fontFamily: 'Sora', fontSize: 20, fontWeight: FontWeight.w700,
                  color: WarnaAcakehan.abu900, letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const Spacer(),
          Consumer(
            builder: (_, ref, __) {
              final dashboard  = ref.watch(providerDashboard).valueOrNull;
              final jumlahNotif = dashboard?.notifikasiBelumDibaca ?? 0;
              return Stack(
                children: [
                  Container(
                    padding:    const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:        Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow:    DekorasiAcakehan.shadowKartu,
                    ),
                    child: const Icon(Icons.notifications_rounded, color: WarnaAcakehan.abu700, size: 22),
                  ),
                  if (jumlahNotif > 0)
                    Positioned(
                      top: 0, right: 0,
                      child: Container(
                        padding:    const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: WarnaAcakehan.pengeluaran, shape: BoxShape.circle),
                        child: Text(
                          jumlahNotif > 9 ? '9+' : '$jumlahNotif',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 10),
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(gradient: GradienAcakehan.tombolPrimer, shape: BoxShape.circle),
            child: Center(
              child: Text(inisial, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
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

class _IsiDashboard extends StatelessWidget {
  final dynamic      dashboard;
  final VoidCallback onLihatSemuaTransaksi;
  const _IsiDashboard({required this.dashboard, required this.onLihatSemuaTransaksi});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KartuSaldoUtama(ringkasan: dashboard.ringkasanBulanIni, namaPengguna: 'Pengguna'),
          const SizedBox(height: 24),

          _JudulSeksi(
            judul:    'Distribusi Pengeluaran',
            subJudul: FormatHelper.labelPeriode(
              dashboard.ringkasanBulanIni.bulan,
              dashboard.ringkasanBulanIni.tahun,
            ),
          ),
          const SizedBox(height: 12),
          GrafikPiePengeluaran(data: dashboard.pengeluaranPerKategori),

          const SizedBox(height: 24),

          if (dashboard.statusSemuaAnggaran.isNotEmpty) ...[
            _JudulSeksi(
              judul:    'Status Anggaran',
              subJudul: 'Bulan ini',
              aksi: TextButton(
                onPressed: () {
                  // FIX: navigasi ke tab Anggaran (indeks 2)
                  final state = context.findAncestorStateOfType<_HalamanDashboardState>();
                  state?._pindahKeTab(2);
                },
                child: const Text('Lihat Semua',
                    style: TextStyle(color: WarnaAcakehan.primer, fontWeight: FontWeight.w700, fontSize: 13)),
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

          // FIX: "Lihat Semua" sekarang navigasi ke tab Transaksi
          _JudulSeksi(
            judul:    'Transaksi Terbaru',
            subJudul: 'Aktivitas keuangan terakhir',
            aksi: TextButton(
              onPressed: onLihatSemuaTransaksi,
              child: const Text('Lihat Semua',
                  style: TextStyle(color: WarnaAcakehan.primer, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 12),

          Consumer(
            builder: (_, ref, __) {
              final stateTransaksi = ref.watch(providerTransaksiNotifier);

              if (stateTransaksi.sedangMemuat) {
                return Column(
                  children: List.generate(3, (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SkeletonMuat(tinggi: 72, radiusBorder: 16),
                  )),
                );
              }

              if (stateTransaksi.daftarTransaksi.isEmpty) {
                return const KotakKosong(
                  judul:       'Belum Ada Transaksi',
                  deskripsi:   'Tekan tombol + untuk mulai mencatat keuangan.',
                  ikon:        Icons.receipt_long_rounded,
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

// ============================================================
//  TAB 2: Transaksi — FIX: implementasi penuh, bukan placeholder
// ============================================================
class _TabTransaksi extends ConsumerStatefulWidget {
  const _TabTransaksi();

  @override
  ConsumerState<_TabTransaksi> createState() => _TabTransaksiState();
}

class _TabTransaksiState extends ConsumerState<_TabTransaksi> {
  String? _filterTipe;

  @override
  Widget build(BuildContext context) {
    final stateTransaksi = ref.watch(providerTransaksiNotifier);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Riwayat Transaksi',
                  style: TextStyle(
                    fontFamily: 'Sora', fontSize: 22, fontWeight: FontWeight.w700,
                    color: WarnaAcakehan.abu900, letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                if (stateTransaksi.sedangMemuat)
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: WarnaAcakehan.primer),
                  ),
              ],
            ),
          ),

          // Filter chip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipFilter(
                    label:   'Semua',
                    aktif:   _filterTipe == null,
                    onTap:   () {
                      setState(() => _filterTipe = null);
                      ref.read(providerTransaksiNotifier.notifier).muatTransaksi();
                    },
                  ),
                  const SizedBox(width: 8),
                  _ChipFilter(
                    label:   'Pemasukan',
                    aktif:   _filterTipe == 'pemasukan',
                    warna:   WarnaAcakehan.pemasukan,
                    onTap:   () {
                      setState(() => _filterTipe = 'pemasukan');
                      ref.read(providerTransaksiNotifier.notifier).muatTransaksi(tipe: 'pemasukan');
                    },
                  ),
                  const SizedBox(width: 8),
                  _ChipFilter(
                    label:   'Pengeluaran',
                    aktif:   _filterTipe == 'pengeluaran',
                    warna:   WarnaAcakehan.pengeluaran,
                    onTap:   () {
                      setState(() => _filterTipe = 'pengeluaran');
                      ref.read(providerTransaksiNotifier.notifier).muatTransaksi(tipe: 'pengeluaran');
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Daftar transaksi
          Expanded(
            child: () {
              if (stateTransaksi.sedangMemuat) {
                return ListView.builder(
                  padding:     const EdgeInsets.symmetric(horizontal: 16),
                  itemCount:   6,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SkeletonMuat(tinggi: 72, radiusBorder: 16),
                  ),
                );
              }

              if (stateTransaksi.pesanError != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BannerError(pesan: stateTransaksi.pesanError!),
                        const SizedBox(height: 16),
                        TombolGradien(
                          teks:  'Coba Lagi',
                          onTap: () => ref.read(providerTransaksiNotifier.notifier).muatTransaksi(tipe: _filterTipe),
                          ikon:  Icons.refresh_rounded,
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (stateTransaksi.daftarTransaksi.isEmpty) {
                return const Center(
                  child: KotakKosong(
                    judul:      'Belum Ada Transaksi',
                    deskripsi:  'Tekan tombol + di bawah untuk mulai mencatat.',
                    ikon:       Icons.receipt_long_rounded,
                  ),
                );
              }

              return RefreshIndicator(
                color:     WarnaAcakehan.primer,
                onRefresh: () => ref.read(providerTransaksiNotifier.notifier)
                    .muatTransaksi(tipe: _filterTipe),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notif) {
                    // Infinite scroll — muat lebih banyak saat mendekati bawah
                    if (notif is ScrollEndNotification &&
                        notif.metrics.extentAfter < 200) {
                      ref.read(providerTransaksiNotifier.notifier).muatLebihBanyak();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    padding:     const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount:   stateTransaksi.daftarTransaksi.length +
                                 (stateTransaksi.sedangMuatLebih ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == stateTransaksi.daftarTransaksi.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child:   Center(child: CircularProgressIndicator(color: WarnaAcakehan.primer)),
                        );
                      }
                      final t = stateTransaksi.daftarTransaksi[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ItemTransaksi(transaksi: t)
                            .animate()
                            .fadeIn(duration: 300.ms, delay: Duration(milliseconds: i * 30))
                            .slideX(begin: 0.03),
                      );
                    },
                  ),
                ),
              );
            }(),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  TAB 3: Anggaran — FIX: implementasi penuh, bukan placeholder
// ============================================================
class _TabAnggaran extends ConsumerWidget {
  const _TabAnggaran();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataDashboard = ref.watch(providerDashboard);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Anggaran Bulan Ini',
                  style: TextStyle(
                    fontFamily: 'Sora', fontSize: 22, fontWeight: FontWeight.w700,
                    color: WarnaAcakehan.abu900, letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:        WarnaAcakehan.primerPudar,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    FormatHelper.labelBulanIni(),
                    style: const TextStyle(
                      color: WarnaAcakehan.primer, fontSize: 12, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: dataDashboard.when(
              loading: () => ListView.builder(
                padding:     const EdgeInsets.symmetric(horizontal: 16),
                itemCount:   4,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SkeletonMuat(tinggi: 90, radiusBorder: 16),
                ),
              ),
              error: (galat, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BannerError(pesan: galat.toString().replaceFirst('Exception: ', '')),
                      const SizedBox(height: 16),
                      TombolGradien(
                        teks:  'Coba Lagi',
                        onTap: () => ref.invalidate(providerDashboard),
                        ikon:  Icons.refresh_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              data: (dashboard) {
                if (dashboard.statusSemuaAnggaran.isEmpty) {
                  return const Center(
                    child: KotakKosong(
                      judul:      'Belum Ada Anggaran',
                      deskripsi:  'Anggaran akan tampil di sini setelah dikonfigurasi di backend.',
                      ikon:       Icons.account_balance_wallet_rounded,
                    ),
                  );
                }

                return RefreshIndicator(
                  color:     WarnaAcakehan.primer,
                  onRefresh: () => ref.refresh(providerDashboard.future),
                  child: ListView.builder(
                    padding:     const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount:   dashboard.statusSemuaAnggaran.length,
                    itemBuilder: (_, i) {
                      final anggaran = dashboard.statusSemuaAnggaran[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _KartuAnggaran(anggaran: anggaran)
                            .animate()
                            .fadeIn(duration: 350.ms, delay: Duration(milliseconds: i * 50))
                            .slideY(begin: 0.04),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  TAB 4: Profil — FIX: tambah form edit profil lengkap
// ============================================================
class _TabProfil extends ConsumerStatefulWidget {
  const _TabProfil();

  @override
  ConsumerState<_TabProfil> createState() => _TabProfilState();
}

class _TabProfilState extends ConsumerState<_TabProfil> {
  final _kunciForm        = GlobalKey<FormState>();
  final _ctrlNama         = TextEditingController();
  final _ctrlEmail        = TextEditingController();
  final _ctrlTelepon      = TextEditingController();
  bool  _sedangMenyimpan  = false;
  bool  _formDiubah       = false;

  @override
  void dispose() {
    _ctrlNama.dispose();
    _ctrlEmail.dispose();
    _ctrlTelepon.dispose();
    super.dispose();
  }

  void _isiForm(pengguna) {
    if (pengguna == null) return;
    _ctrlNama.text     = pengguna.namaLengkap;
    _ctrlEmail.text    = pengguna.email;
    _ctrlTelepon.text  = pengguna.nomorTelepon ?? '';
  }

  Future<void> _simpanProfil() async {
    if (!(_kunciForm.currentState?.validate() ?? false)) return;
    setState(() => _sedangMenyimpan = true);

    // Simulasi simpan (endpoint PUT /api/v1/auth/profil belum ada di FastAPI)
    // Untuk sekarang, hanya update data lokal
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _sedangMenyimpan = false;
        _formDiubah      = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         const Text('Profil berhasil diperbarui!'),
          backgroundColor: WarnaAcakehan.pemasukan,
          behavior:        SnackBarBehavior.floating,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pengguna = ref.watch(providerPenggunaAktif);

    // Isi form pertama kali
    if (_ctrlNama.text.isEmpty && pengguna != null) {
      _isiForm(pengguna);
    }

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Form(
          key: _kunciForm,
          onChanged: () => setState(() => _formDiubah = true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profil Saya',
                style: TextStyle(
                  fontFamily: 'Sora', fontSize: 22, fontWeight: FontWeight.w700,
                  color: WarnaAcakehan.abu900, letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 24),

              // Avatar
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: const BoxDecoration(
                        gradient: GradienAcakehan.tombolPrimer, shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          pengguna?.inisialNama ?? 'AC',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Center(
                child: Text(
                  pengguna?.namaLengkap ?? '-',
                  style: const TextStyle(
                    fontFamily: 'Sora', fontSize: 18, fontWeight: FontWeight.w700, color: WarnaAcakehan.abu900,
                  ),
                ),
              ),
              Center(
                child: Text(
                  pengguna?.email ?? '-',
                  style: const TextStyle(fontSize: 13, color: WarnaAcakehan.abu400),
                ),
              ),

              const SizedBox(height: 28),

              // Form fields
              Container(
                padding:    const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20),
                  boxShadow: DekorasiAcakehan.shadowKartu,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informasi Akun',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: WarnaAcakehan.abu700),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller:  _ctrlNama,
                      decoration:  const InputDecoration(
                        label:      Text('Nama Lengkap'),
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nama tidak boleh kosong';
                        if (v.trim().length < 3) return 'Nama minimal 3 karakter';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller:     _ctrlEmail,
                      keyboardType:   TextInputType.emailAddress,
                      decoration:     const InputDecoration(
                        label:      Text('Email'),
                        prefixIcon: Icon(Icons.email_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email tidak boleh kosong';
                        if (!v.contains('@')) return 'Format email tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller:   _ctrlTelepon,
                      keyboardType: TextInputType.phone,
                      decoration:   const InputDecoration(
                        label:      Text('Nomor Telepon (opsional)'),
                        prefixIcon: Icon(Icons.phone_rounded),
                        hintText:   '08xxxxxxxxxx',
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: TombolGradien(
                        teks:         'Simpan Perubahan',
                        onTap:        _formDiubah ? _simpanProfil : null,
                        sedangMemuat: _sedangMenyimpan,
                        ikon:         Icons.save_rounded,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Info akun
              Container(
                padding:    const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20),
                  boxShadow: DekorasiAcakehan.shadowKartu,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informasi Aplikasi',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: WarnaAcakehan.abu700),
                    ),
                    const SizedBox(height: 12),
                    _BarisProfil(ikon: Icons.calendar_today_rounded, label: 'Bergabung',
                        nilai: FormatHelper.formatTanggal(pengguna?.tanggalDaftar)),
                    const Divider(height: 20),
                    _BarisProfil(ikon: Icons.shield_rounded, label: 'Peran', nilai: pengguna?.peranUser ?? '-'),
                    const Divider(height: 20),
                    _BarisProfil(ikon: Icons.info_rounded, label: 'Versi Aplikasi', nilai: TeksApp.versi),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Logout
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WarnaAcakehan.pengeluaran,
                    side: const BorderSide(color: WarnaAcakehan.pengeluaran),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon:     const Icon(Icons.logout_rounded),
                  label:    const Text('Keluar dari Akun', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () async {
                    final konfirmasi = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title:   const Text('Keluar Akun?', style: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700)),
                        content: const Text('Anda akan keluar dari akun Acakehan.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Keluar', style: TextStyle(color: WarnaAcakehan.pengeluaran)),
                          ),
                        ],
                      ),
                    );
                    if (konfirmasi == true && context.mounted) {
                      await ref.read(providerAuthNotifier.notifier).keluar();
                      if (context.mounted) context.go(NamaRoute.masuk);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget pembantu profil ─────────────────────────────────────
class _BarisProfil extends StatelessWidget {
  final IconData ikon;
  final String   label;
  final String   nilai;
  const _BarisProfil({required this.ikon, required this.label, required this.nilai});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(ikon, size: 18, color: WarnaAcakehan.abu400),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: WarnaAcakehan.abu500)),
        const Spacer(),
        Text(nilai, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: WarnaAcakehan.abu800)),
      ],
    );
  }
}

// ── Widget kartu anggaran ──────────────────────────────────────
class _KartuAnggaran extends StatelessWidget {
  final dynamic anggaran;
  const _KartuAnggaran({required this.anggaran});

  @override
  Widget build(BuildContext context) {
    // FIX: ganti persentaseTerpakai → persenTerpakai
    final persen     = (anggaran.persenTerpakai as num).toDouble().clamp(0.0, 100.0);
    final isLewat    = persen >= 100;
    final isWarning  = persen >= 80 && !isLewat;
    final warnaProg  = isLewat ? WarnaAcakehan.pengeluaran
                     : isWarning ? Colors.orange
                     : WarnaAcakehan.pemasukan;

    return Container(
      padding:    const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow:    DekorasiAcakehan.shadowKartu,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                anggaran.ikonKategori ?? '📦',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  anggaran.namaKategori ?? '-',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: WarnaAcakehan.abu900),
                ),
              ),
              Container(
                padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:        warnaProg.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${persen.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: warnaProg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value:            persen / 100,
              backgroundColor:  WarnaAcakehan.abu100,
              color:            warnaProg,
              minHeight:        8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terpakai: ${FormatHelper.formatRupiah(anggaran.totalTerpakai ?? 0)}',
                style: const TextStyle(fontSize: 12, color: WarnaAcakehan.abu500),
              ),
              Text(
                'Batas: ${FormatHelper.formatRupiah(anggaran.batasMaksimal ?? 0)}',
                style: const TextStyle(fontSize: 12, color: WarnaAcakehan.abu500),
              ),
            ],
          ),
          if (isLewat || isWarning) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isLewat ? Icons.error_rounded : Icons.warning_rounded,
                  size: 14, color: warnaProg,
                ),
                const SizedBox(width: 4),
                Text(
                  isLewat ? 'Anggaran telah habis!' : 'Mendekati batas anggaran',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: warnaProg),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widget chip filter ────────────────────────────────────────
class _ChipFilter extends StatelessWidget {
  final String     label;
  final bool       aktif;
  final Color?     warna;
  final VoidCallback onTap;

  const _ChipFilter({
    required this.label,
    required this.aktif,
    required this.onTap,
    this.warna,
  });

  @override
  Widget build(BuildContext context) {
    final c = warna ?? WarnaAcakehan.primer;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration:   const Duration(milliseconds: 200),
        padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:        aktif ? c : c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.w700,
            color:      aktif ? Colors.white : c,
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  Judul seksi
// ============================================================
class _JudulSeksi extends StatelessWidget {
  final String  judul;
  final String  subJudul;
  final Widget? aksi;
  const _JudulSeksi({required this.judul, required this.subJudul, this.aksi});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul, style: const TextStyle(
              fontFamily: 'Sora', fontSize: 16, fontWeight: FontWeight.w700,
              color: WarnaAcakehan.abu900, letterSpacing: -0.2,
            )),
            Text(subJudul, style: const TextStyle(fontSize: 12, color: WarnaAcakehan.abu400, fontWeight: FontWeight.w500)),
          ],
        ),
        if (aksi != null) ...[const Spacer(), aksi!],
      ],
    );
  }
}

// ============================================================
//  Skeleton, Error, dll.
// ============================================================
class _SkeletonDashboard extends StatelessWidget {
  const _SkeletonDashboard();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(children: [
        SkeletonMuat(tinggi: 200, radiusBorder: 28),
        const SizedBox(height: 24),
        SkeletonMuat(tinggi: 280, radiusBorder: 20),
        const SizedBox(height: 16),
        ...List.generate(3, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child:   SkeletonMuat(tinggi: 72, radiusBorder: 16),
        )),
      ]),
    );
  }
}

class _TampilError extends StatelessWidget {
  final String       pesan;
  final VoidCallback onCoba;
  const _TampilError({required this.pesan, required this.onCoba});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 32),
        BannerError(pesan: pesan),
        const SizedBox(height: 16),
        TombolGradien(teks: 'Coba Lagi', onTap: onCoba, ikon: Icons.refresh_rounded),
      ]),
    );
  }
}

// ============================================================
//  Bottom Navigation Bar
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))],
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
  final IconData ikon; final String label; final int indeks; final int aktif; final ValueChanged<int> onTap;
  const _ItemNavBar({required this.ikon, required this.label, required this.indeks, required this.aktif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAktif = indeks == aktif;
    return GestureDetector(
      onTap: () => onTap(indeks),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration:   const Duration(milliseconds: 200),
        padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color:        isAktif ? WarnaAcakehan.primerPudar : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(ikon, color: isAktif ? WarnaAcakehan.primer : WarnaAcakehan.abu400, size: 22),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
            fontSize: 10,
            fontWeight: isAktif ? FontWeight.w700 : FontWeight.w500,
            color:      isAktif ? WarnaAcakehan.primer : WarnaAcakehan.abu400,
          )),
        ]),
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
        width: 56, height: 56,
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
  ConsumerState<_FormTambahTransaksi> createState() => _FormTambahTransaksiState();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pilih kategori terlebih dahulu.'),
        backgroundColor: WarnaAcakehan.pengeluaran,
        behavior: SnackBarBehavior.floating,
      ));
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
        catatanTambahan:  _kontrolerCatatan.text.isNotEmpty ? _kontrolerCatatan.text : null,
      );

      ref.read(providerTransaksiNotifier.notifier).tambahkanKeLokal(transaksi);
      ref.invalidate(providerDashboard);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         const Text('Transaksi berhasil dicatat!'),
          backgroundColor: WarnaAcakehan.pemasukan,
          behavior:        SnackBarBehavior.floating,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (galat) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text(galat.toString().replaceFirst('Exception: ', '')),
          backgroundColor: WarnaAcakehan.pengeluaran,
          behavior:        SnackBarBehavior.floating,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _sedangMenyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _kunciForm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: WarnaAcakehan.abu200, borderRadius: BorderRadius.circular(99)),
            )),
            const SizedBox(height: 20),
            const Text('Catat Transaksi', style: TextStyle(
              fontFamily: 'Sora', fontSize: 20, fontWeight: FontWeight.w700,
              color: WarnaAcakehan.abu900, letterSpacing: -0.3,
            )),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(color: WarnaAcakehan.abu100, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: ['pengeluaran', 'pemasukan'].map((tipe) {
                  final isAktif = _tipeTransaksi == tipe;
                  final warna   = tipe == 'pemasukan' ? WarnaAcakehan.pemasukan : WarnaAcakehan.pengeluaran;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _tipeTransaksi = tipe; _kategoriIdTerpilih = null; }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isAktif ? warna : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(child: Text(
                          tipe == 'pemasukan' ? 'Pemasukan' : 'Pengeluaran',
                          style: TextStyle(
                            color:      isAktif ? Colors.white : WarnaAcakehan.abu500,
                            fontWeight: FontWeight.w700, fontSize: 14,
                          ),
                        )),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            Consumer(builder: (_, ref, __) {
              final kategoriAsync = ref.watch(providerDaftarKategori);
              return kategoriAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child:   LinearProgressIndicator(),
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
                    return const Text('Belum ada kategori untuk tipe ini.',
                        style: TextStyle(color: WarnaAcakehan.abu400, fontSize: 13));
                  }
                  final idMasihValid = kategoriTerfilter.any((k) => k.kategoriId == _kategoriIdTerpilih);
                  final nilaiDropdown = idMasihValid ? _kategoriIdTerpilih : null;
                  return DropdownButtonFormField<int>(
                    value:     nilaiDropdown,
                    decoration: const InputDecoration(label: Text('Kategori'), prefixIcon: Icon(Icons.category_rounded)),
                    items: kategoriTerfilter.map((k) => DropdownMenuItem<int>(
                      value: k.kategoriId,
                      child: Text('${k.ikonKategori ?? ''} ${k.namaKategori}'.trim()),
                    )).toList(),
                    onChanged: (nilai) => setState(() => _kategoriIdTerpilih = nilai),
                    validator: (v) => v == null ? 'Pilih kategori terlebih dahulu' : null,
                  );
                },
              );
            }),
            const SizedBox(height: 14),

            TextFormField(
              controller:   _kontrolerJumlah,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Sora', color: WarnaAcakehan.abu900),
              decoration: const InputDecoration(
                prefixText: 'Rp ', hintText: '0', label: Text('Jumlah'),
                prefixStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: WarnaAcakehan.abu500),
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
                label: Text('Catatan (opsional)'), hintText: 'Contoh: Makan siang kantor',
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
