// ============================================================
//  ACAKEHAN — Aplikasi Catatan Keuangan Harian
//  File   : lib/presentation/widgets/dashboard/widget_dashboard.dart
//  Fungsi : Koleksi widget khusus halaman Dashboard:
//           KartuSaldo, GrafikPie, ItemTransaksi, ProgressAnggaran
// ============================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/utils/format_helper.dart';
import '../../../data/models/model_data.dart';
import '../../theme/tema_acakehan.dart';
import '../common/widget_umum.dart';

// ── Palet warna untuk grafik pie ──────────────────────────────
const List<Color> _warnaGrafik = [
  Color(0xFF0D9488),
  Color(0xFFF97316),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF3B82F6),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF6366F1),
];

// ============================================================
//  WIDGET: KartuSaldoUtama
//  Kartu gradien utama yang menampilkan saldo, pemasukan,
//  dan pengeluaran bulan berjalan.
// ============================================================
class KartuSaldoUtama extends StatelessWidget {
  final ModelRingkasanBulanan ringkasan;
  final String namaPengguna;

  const KartuSaldoUtama({
    super.key,
    required this.ringkasan,
    required this.namaPengguna,
  });

  @override
  Widget build(BuildContext context) {
    final isPositif = ringkasan.saldoBersih >= 0;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient:     GradienAcakehan.kartuSaldo,
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Salam & periode ───────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, ${namaPengguna.split(' ').first} 👋',
                      style: TextStyle(
                        color:      Colors.white.withOpacity(0.8),
                        fontSize:   13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      FormatHelper.labelPeriode(
                          ringkasan.bulan, ringkasan.tahun),
                      style: const TextStyle(
                        color:       Colors.white,
                        fontSize:    15,
                        fontWeight:  FontWeight.w700,
                        fontFamily:  'Sora',
                      ),
                    ),
                  ],
                ),
              ),
              // Badge jumlah transaksi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${ringkasan.jumlahTransaksi} transaksi',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Saldo Bersih ──────────────────────────────────
          Text(
            'Saldo Bersih',
            style: TextStyle(
              color:      Colors.white.withOpacity(0.65),
              fontSize:   12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                FormatHelper.rupiah(ringkasan.saldoBersih.abs()),
                style: const TextStyle(
                  color:       Colors.white,
                  fontSize:    30,
                  fontWeight:  FontWeight.w800,
                  fontFamily:  'Sora',
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPositif
                        ? Colors.green.withOpacity(0.25)
                        : Colors.red.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPositif ? '▲ Surplus' : '▼ Defisit',
                    style: TextStyle(
                      color:      isPositif ? Colors.greenAccent : Colors.redAccent,
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Pemisah ───────────────────────────────────────
          Divider(color: Colors.white.withOpacity(0.15), height: 1),
          const SizedBox(height: 20),

          // ── Pemasukan & Pengeluaran ───────────────────────
          Row(
            children: [
              Expanded(
                child: _BaganKeuangan(
                  label:  'Pemasukan',
                  nilai:  FormatHelper.rupiahRingkas(ringkasan.totalPemasukan),
                  ikon:   Icons.arrow_downward_rounded,
                  warna:  Colors.greenAccent,
                ),
              ),
              Container(
                width:  1,
                height: 44,
                color:  Colors.white.withOpacity(0.15),
              ),
              Expanded(
                child: _BaganKeuangan(
                  label:  'Pengeluaran',
                  nilai:  FormatHelper.rupiahRingkas(ringkasan.totalPengeluaran),
                  ikon:   Icons.arrow_upward_rounded,
                  warna:  Colors.orangeAccent,
                  isKanan: true,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.05);
  }
}

class _BaganKeuangan extends StatelessWidget {
  final String label;
  final String nilai;
  final IconData ikon;
  final Color   warna;
  final bool    isKanan;

  const _BaganKeuangan({
    required this.label,
    required this.nilai,
    required this.ikon,
    required this.warna,
    this.isKanan = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left:  isKanan ? 20 : 0,
        right: isKanan ? 0 : 20,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color:        warna.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(ikon, color: warna, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color:      Colors.white.withOpacity(0.65),
                  fontSize:   11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                nilai,
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Sora',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  WIDGET: GrafikPiePengeluaran
//  Pie chart interaktif dengan legenda kategori
// ============================================================
class GrafikPiePengeluaran extends StatefulWidget {
  final List<ModelPengeluaranKategori> data;

  const GrafikPiePengeluaran({super.key, required this.data});

  @override
  State<GrafikPiePengeluaran> createState() => _GrafikPiePengeluaranState();
}

class _GrafikPiePengeluaranState extends State<GrafikPiePengeluaran> {
  int indeksAktif = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const KotakKosong(
        judul:       'Belum Ada Pengeluaran',
        deskripsi:   'Mulai catat pengeluaran untuk melihat grafik distribusi.',
        ikon:        Icons.pie_chart_outline_rounded,
      );
    }

    return Container(
      padding:     const EdgeInsets.all(20),
      decoration:  DekorasiAcakehan.kartuUtama,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:        WarnaAcakehan.primerPudar,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.donut_large_rounded,
                  color: WarnaAcakehan.primer,
                  size:  18,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengeluaran per Kategori',
                    style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
                      color:      WarnaAcakehan.abu800,
                      fontFamily: 'Sora',
                    ),
                  ),
                  Text(
                    'Bulan ini',
                    style: TextStyle(
                      fontSize:  11,
                      color:     WarnaAcakehan.abu400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Grafik Pie + Pusat ────────────────────────────
          SizedBox(
            height: 200,
            child: Row(
              children: [
                // Grafik
                Expanded(
                  flex: 5,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace:     3,
                      centerSpaceRadius: 52,
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              indeksAktif = -1;
                              return;
                            }
                            indeksAktif = pieTouchResponse
                                .touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: _bangunSeksiPie(),
                      centerSpaceColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Legenda
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.data
                        .asMap()
                        .entries
                        .take(6)
                        .map((entri) => _BaganLegenda(
                              label: entri.value.namaKategori,
                              persen: entri.value.persenDariTotal,
                              warna: _warnaGrafik[
                                  entri.key % _warnaGrafik.length],
                              isAktif: indeksAktif == entri.key,
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms);
  }

  List<PieChartSectionData> _bangunSeksiPie() {
    return widget.data.asMap().entries.map((entri) {
      final isAktif = indeksAktif == entri.key;
      final warna   = _warnaGrafik[entri.key % _warnaGrafik.length];

      return PieChartSectionData(
        value:      entri.value.persenDariTotal,
        color:      warna,
        radius:     isAktif ? 62 : 52,
        title:      isAktif
            ? '${entri.value.persenDariTotal.toStringAsFixed(1)}%'
            : '',
        titleStyle: const TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.w700,
          color:      Colors.white,
        ),
      );
    }).toList();
  }
}

class _BaganLegenda extends StatelessWidget {
  final String label;
  final double persen;
  final Color  warna;
  final bool   isAktif;

  const _BaganLegenda({
    required this.label,
    required this.persen,
    required this.warna,
    required this.isAktif,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin:   const EdgeInsets.symmetric(vertical: 3),
      padding:  EdgeInsets.symmetric(
        horizontal: isAktif ? 8 : 0,
        vertical:   isAktif ? 4 : 0,
      ),
      decoration: BoxDecoration(
        color:        isAktif ? warna.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width:  10,
            height: 10,
            decoration: BoxDecoration(
              color:  warna,
              shape:  BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize:   11,
                fontWeight: isAktif ? FontWeight.w700 : FontWeight.w500,
                color:      isAktif ? warna : WarnaAcakehan.abu600,
              ),
            ),
          ),
          Text(
            '${persen.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w700,
              color:      isAktif ? warna : WarnaAcakehan.abu500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  WIDGET: ItemTransaksi
//  Satu baris transaksi di daftar riwayat
// ============================================================
class ItemTransaksi extends StatelessWidget {
  final ModelTransaksi transaksi;
  final VoidCallback?  onTap;

  const ItemTransaksi({
    super.key,
    required this.transaksi,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPemasukan = transaksi.adalahPemasukan;
    final warnaTipe   = isPemasukan ? WarnaAcakehan.pemasukan : WarnaAcakehan.pengeluaran;
    final warnaBg     = isPemasukan ? WarnaAcakehan.pemasukanBg : WarnaAcakehan.pengeluaranBg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow:    DekorasiAcakehan.shadowKartu,
        ),
        child: Row(
          children: [
            // ── Ikon kategori ─────────────────────────────
            Container(
              width:  44,
              height: 44,
              decoration: BoxDecoration(
                color:        warnaBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _ikonKategori(transaksi.kategori?.namaKategori ?? ''),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ── Info transaksi ────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaksi.kategori?.namaKategori ?? 'Lainnya',
                    style: const TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      WarnaAcakehan.abu800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    transaksi.catatanTambahan?.isNotEmpty == true
                        ? transaksi.catatanTambahan!
                        : FormatHelper.tanggalRelatif(transaksi.tanggalTransaksi),
                    style: const TextStyle(
                      fontSize:  12,
                      color:     WarnaAcakehan.abu400,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Nominal & tanggal ─────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPemasukan ? '+' : '-'} ${FormatHelper.rupiah(transaksi.jumlahNominal)}',
                  style: TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w800,
                    color:      warnaTipe,
                    fontFamily: 'Sora',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  FormatHelper.tanggalPendek(transaksi.tanggalTransaksi),
                  style: const TextStyle(
                    fontSize:  11,
                    color:     WarnaAcakehan.abu400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Peta nama kategori ke emoji yang relevan
  String _ikonKategori(String nama) {
    final peta = {
      'makanan': '🍽️', 'food': '🍽️',
      'transportasi': '🚗', 'transport': '🚗',
      'belanja': '🛍️', 'shopping': '🛍️',
      'tagihan': '💡', 'bill': '💡', 'utilitas': '💡',
      'kesehatan': '💊', 'health': '💊',
      'hiburan': '🎬', 'entertainment': '🎬',
      'pendidikan': '📚', 'education': '📚',
      'gaji': '💼', 'salary': '💼',
      'investasi': '📈', 'invest': '📈',
      'olahraga': '🏃', 'sport': '🏃',
      'perawatan': '💆', 'care': '💆',
      'sosial': '🤝', 'donasi': '🤝',
      'bonus': '🎁', 'hadiah': '🎁',
      'tabungan': '🏦', 'saving': '🏦',
      'cicilan': '💳', 'utang': '💳',
      'freelance': '💻',
    };

    final kunciKecil = nama.toLowerCase();
    for (final kunci in peta.keys) {
      if (kunciKecil.contains(kunci)) return peta[kunci]!;
    }
    return '💰';
  }
}

// ============================================================
//  WIDGET: BarProgressAnggaran
//  Progress bar untuk status anggaran bulan ini
// ============================================================
class BarProgressAnggaran extends StatelessWidget {
  final ModelStatusAnggaran anggaran;

  const BarProgressAnggaran({super.key, required this.anggaran});

  @override
  Widget build(BuildContext context) {
    final persen    = (anggaran.persenTerpakai / 100).clamp(0.0, 1.0);
    final warnaBar  = anggaran.statusAman
        ? WarnaAcakehan.pemasukan
        : anggaran.persenTerpakai >= 100
            ? WarnaAcakehan.pengeluaran
            : WarnaAcakehan.peringatan;

    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow:    DekorasiAcakehan.shadowKartu,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  anggaran.namaKategori,
                  style: const TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      WarnaAcakehan.abu800,
                  ),
                ),
              ),
              Text(
                FormatHelper.persen(anggaran.persenTerpakai),
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w800,
                  color:      warnaBar,
                  fontFamily: 'Sora',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value:           persen,
              minHeight:       7,
              backgroundColor: warnaBar.withOpacity(0.12),
              valueColor:      AlwaysStoppedAnimation<Color>(warnaBar),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terpakai: ${FormatHelper.rupiahRingkas(anggaran.totalTerpakai)}',
                style: const TextStyle(
                  fontSize:  11,
                  color:     WarnaAcakehan.abu400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Sisa: ${FormatHelper.rupiahRingkas(anggaran.sisaAnggaran)}',
                style: TextStyle(
                  fontSize:  11,
                  color:     anggaran.statusAman
                      ? WarnaAcakehan.abu500
                      : WarnaAcakehan.pengeluaran,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
