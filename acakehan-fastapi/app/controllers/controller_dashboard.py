"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : app/controllers/controller_dashboard.py
  Fungsi : Logika bisnis untuk ringkasan Dashboard keuangan:
           - Ringkasan bulan berjalan (pemasukan, pengeluaran, saldo)
           - Pengeluaran per kategori (data pie chart)
           - Tren 6 bulan terakhir (data line chart)
           - Status semua anggaran aktif
           - Jumlah notifikasi belum dibaca
  Pola   : MVC — Layer Controller
============================================================
"""

from datetime import datetime, timezone
from typing import List

from sqlalchemy.orm import Session
from sqlalchemy import extract, func, and_, case

from app.models.model_db import Transaksi, Anggaran, Notifikasi, Pengguna, Kategori
from app.schemas.skema_data import (
    SkemaDataDashboard,
    SkemaRingkasanBulanan,
    SkemaPengeluaranPerKategori,
    SkemaTrenBulanan,
    SkemaStatusAnggaran,
)
from app.config.pengaturan import ambilPengaturan
from app.utils.pembantu import namaBulan, periodeBulanIni

cfg = ambilPengaturan()


# ============================================================
#  CONTROLLER: Ambil Data Dashboard Lengkap
# ============================================================
def kontrolerAmbilDashboard(pengguna: Pengguna, db: Session) -> SkemaDataDashboard:
    """
    Mengumpulkan semua data yang dibutuhkan halaman Dashboard:

        1. Ringkasan keuangan bulan berjalan
        2. Breakdown pengeluaran per kategori (pie chart)
        3. Tren 6 bulan terakhir (line chart)
        4. Status semua anggaran aktif
        5. Jumlah notifikasi belum dibaca

    Semua query dijalankan sekali dalam fungsi ini untuk efisiensi.

    Args:
        pengguna : Pengguna yang sedang login
        db       : Sesi database

    Returns:
        SkemaDataDashboard berisi semua data dashboard
    """
    periode    = periodeBulanIni()
    bulanIni   = periode["bulan"]
    tahunIni   = periode["tahun"]
    penggunaId = pengguna.penggunaId

    # Jalankan semua query agregasi secara paralel (dalam satu fungsi)
    ringkasanBulanIni      = _hitungRingkasanBulanan(db, penggunaId, bulanIni, tahunIni)
    pengeluaranPerKategori = _hitungPengeluaranPerKategori(db, penggunaId, bulanIni, tahunIni)
    trenEnamBulan          = _hitungTrenEnamBulan(db, penggunaId)
    statusAnggaran         = _ambilStatusAnggaran(db, penggunaId, bulanIni, tahunIni)
    jumlahNotifBelumBaca   = _hitungNotifikasiBelumDibaca(db, penggunaId)

    return SkemaDataDashboard(
        ringkasanBulanIni      = ringkasanBulanIni,
        pengeluaranPerKategori = pengeluaranPerKategori,
        trenEnamBulanTerakhir  = trenEnamBulan,
        statusSemuaAnggaran    = statusAnggaran,
        notifikasiBelumDibaca  = jumlahNotifBelumBaca,
    )


# ============================================================
#  FUNGSI PRIVAT: Ringkasan Keuangan Bulanan
# ============================================================
def _hitungRingkasanBulanan(
    db: Session, penggunaId: int, bulan: int, tahun: int
) -> SkemaRingkasanBulanan:
    """
    Menghitung total pemasukan, total pengeluaran, dan saldo bersih
    untuk periode bulan dan tahun yang ditentukan.

    Menggunakan satu query SQL agregasi dengan CASE WHEN untuk efisiensi —
    menghindari dua query terpisah untuk pemasukan dan pengeluaran.

    SQL yang dihasilkan (ilustrasi):
        SELECT
            SUM(CASE WHEN tipe = 'pemasukan'   THEN jumlah ELSE 0 END) AS total_pemasukan,
            SUM(CASE WHEN tipe = 'pengeluaran' THEN jumlah ELSE 0 END) AS total_pengeluaran,
            COUNT(*) AS jumlah_transaksi
        FROM tbl_transaksi
        WHERE pengguna_id = :id AND MONTH(tanggal) = :bulan AND YEAR(tanggal) = :tahun
          AND status_hapus = 0
    """
    hasil = db.query(
        # Total pemasukan: jumlahkan nominal hanya untuk baris dengan tipe 'pemasukan'
        func.coalesce(
            func.sum(
                case(
                    (Transaksi.tipeTransaksi == "pemasukan", Transaksi.jumlahNominal),
                    else_=0
                )
            ), 0
        ).label("totalPemasukan"),

        # Total pengeluaran: sama, untuk tipe 'pengeluaran'
        func.coalesce(
            func.sum(
                case(
                    (Transaksi.tipeTransaksi == "pengeluaran", Transaksi.jumlahNominal),
                    else_=0
                )
            ), 0
        ).label("totalPengeluaran"),

        # Jumlah total baris transaksi di periode ini
        func.count(Transaksi.transaksiId).label("jumlahTransaksi"),

    ).filter(
        Transaksi.penggunaId  == penggunaId,
        Transaksi.statusHapus == False,
        extract("month", Transaksi.tanggalTransaksi) == bulan,
        extract("year",  Transaksi.tanggalTransaksi) == tahun,
    ).first()

    totalPemasukan   = float(hasil.totalPemasukan   or 0)
    totalPengeluaran = float(hasil.totalPengeluaran or 0)

    return SkemaRingkasanBulanan(
        bulan            = bulan,
        tahun            = tahun,
        totalPemasukan   = totalPemasukan,
        totalPengeluaran = totalPengeluaran,
        saldoBersih      = totalPemasukan - totalPengeluaran,
        jumlahTransaksi  = hasil.jumlahTransaksi or 0,
    )


# ============================================================
#  FUNGSI PRIVAT: Pengeluaran Per Kategori
# ============================================================
def _hitungPengeluaranPerKategori(
    db: Session, penggunaId: int, bulan: int, tahun: int
) -> List[SkemaPengeluaranPerKategori]:
    """
    Menghitung total pengeluaran per kategori untuk bulan ini.
    Hasilnya digunakan sebagai data grafik Pie Chart di dashboard.

    Diurutkan dari kategori dengan pengeluaran terbesar ke terkecil.
    """
    # Subquery: total seluruh pengeluaran bulan ini (untuk menghitung persentase)
    subQueryTotal = db.query(
        func.coalesce(func.sum(Transaksi.jumlahNominal), 0)
    ).filter(
        Transaksi.penggunaId  == penggunaId,
        Transaksi.tipeTransaksi == "pengeluaran",
        Transaksi.statusHapus == False,
        extract("month", Transaksi.tanggalTransaksi) == bulan,
        extract("year",  Transaksi.tanggalTransaksi) == tahun,
    ).scalar() or 0

    totalKeseluruhan = float(subQueryTotal)

    # Query utama: GROUP BY kategori
    hasilQuery = db.query(
        Kategori.namaKategori,
        Kategori.ikonKategori,
        func.sum(Transaksi.jumlahNominal).label("totalNominal"),
        func.count(Transaksi.transaksiId).label("jumlahTransaksi"),
    ).join(
        Transaksi, Transaksi.kategoriId == Kategori.kategoriId
    ).filter(
        Transaksi.penggunaId    == penggunaId,
        Transaksi.tipeTransaksi == "pengeluaran",
        Transaksi.statusHapus   == False,
        extract("month", Transaksi.tanggalTransaksi) == bulan,
        extract("year",  Transaksi.tanggalTransaksi) == tahun,
    ).group_by(
        Kategori.kategoriId,
        Kategori.namaKategori,
        Kategori.ikonKategori,
    ).order_by(
        func.sum(Transaksi.jumlahNominal).desc()   # Terbesar ke terkecil
    ).all()

    daftarHasil = []
    for baris in hasilQuery:
        nominalKategori = float(baris.totalNominal or 0)
        persenDariTotal = round((nominalKategori / totalKeseluruhan * 100), 2) \
                          if totalKeseluruhan > 0 else 0.0

        daftarHasil.append(SkemaPengeluaranPerKategori(
            namaKategori    = baris.namaKategori,
            ikonKategori    = baris.ikonKategori,
            totalNominal    = nominalKategori,
            jumlahTransaksi = baris.jumlahTransaksi,
            persenDariTotal = persenDariTotal,
        ))

    return daftarHasil


# ============================================================
#  FUNGSI PRIVAT: Tren 6 Bulan Terakhir
# ============================================================
def _hitungTrenEnamBulan(
    db: Session, penggunaId: int
) -> List[SkemaTrenBulanan]:
    """
    Mengambil data pemasukan dan pengeluaran untuk 6 bulan terakhir.
    Digunakan untuk grafik Garis (Line Chart) tren keuangan.

    Pendekatan: query semua transaksi 6 bulan terakhir, lalu kelompokkan
    di Python — menghindari query terpisah per bulan yang tidak efisien.
    """
    from datetime import date
    from dateutil.relativedelta import relativedelta

    sekarang      = datetime.utcnow()
    # Awal periode: 6 bulan yang lalu, tanggal 1
    awalPeriode   = (sekarang - relativedelta(months=5)).replace(day=1)

    # Satu query untuk semua 6 bulan sekaligus
    hasilQuery = db.query(
        extract("month", Transaksi.tanggalTransaksi).label("bulan"),
        extract("year",  Transaksi.tanggalTransaksi).label("tahun"),
        func.coalesce(
            func.sum(case(
                (Transaksi.tipeTransaksi == "pemasukan", Transaksi.jumlahNominal),
                else_=0
            )), 0
        ).label("totalPemasukan"),
        func.coalesce(
            func.sum(case(
                (Transaksi.tipeTransaksi == "pengeluaran", Transaksi.jumlahNominal),
                else_=0
            )), 0
        ).label("totalPengeluaran"),
    ).filter(
        Transaksi.penggunaId  == penggunaId,
        Transaksi.statusHapus == False,
        Transaksi.tanggalTransaksi >= awalPeriode.date(),
    ).group_by(
        extract("year",  Transaksi.tanggalTransaksi),
        extract("month", Transaksi.tanggalTransaksi),
    ).order_by(
        extract("year",  Transaksi.tanggalTransaksi).asc(),
        extract("month", Transaksi.tanggalTransaksi).asc(),
    ).all()

    # Buat peta data yang ada dari DB
    petaData = {
        (int(b.tahun), int(b.bulan)): b for b in hasilQuery
    }

    # Isi 6 bulan secara lengkap — bulan tanpa transaksi tetap muncul dengan nilai 0
    daftarTren = []
    for i in range(5, -1, -1):
        tgl   = sekarang - relativedelta(months=i)
        kunci = (tgl.year, tgl.month)

        if kunci in petaData:
            dataBulan = petaData[kunci]
            totalPemasukan   = float(dataBulan.totalPemasukan   or 0)
            totalPengeluaran = float(dataBulan.totalPengeluaran or 0)
        else:
            totalPemasukan   = 0.0
            totalPengeluaran = 0.0

        daftarTren.append(SkemaTrenBulanan(
            bulan            = tgl.month,
            tahun            = tgl.year,
            labelBulan       = f"{namaBulan(tgl.month)} {tgl.year}",
            totalPemasukan   = totalPemasukan,
            totalPengeluaran = totalPengeluaran,
            saldoBersih      = totalPemasukan - totalPengeluaran,
        ))

    return daftarTren


# ============================================================
#  FUNGSI PRIVAT: Status Semua Anggaran Aktif
# ============================================================
def _ambilStatusAnggaran(
    db: Session, penggunaId: int, bulan: int, tahun: int
) -> List[SkemaStatusAnggaran]:
    """
    Mengambil status semua anggaran yang ditetapkan pengguna untuk bulan ini.
    Digunakan untuk menampilkan progress bar anggaran di dashboard.
    """
    daftarAnggaran = db.query(Anggaran).filter(
        Anggaran.penggunaId   == penggunaId,
        Anggaran.periodesBulan == bulan,
        Anggaran.periodeTahun  == tahun,
    ).all()

    daftarStatus = []
    for ang in daftarAnggaran:
        batas        = float(ang.batasMaksimal)
        terpakai     = float(ang.totalTerpakai)
        persen       = round((terpakai / batas * 100), 2) if batas > 0 else 0.0
        sisa         = max(0.0, batas - terpakai)
        namaKategori = ang.kategori.namaKategori if ang.kategori else "?"

        daftarStatus.append(SkemaStatusAnggaran(
            namaKategori   = namaKategori,
            batasMaksimal  = batas,
            totalTerpakai  = terpakai,
            persenTerpakai = persen,
            sisaAnggaran   = sisa,
            # Anggaran "aman" jika penggunaan masih di bawah batas peringatan
            statusAman     = persen < cfg.BATAS_PERSEN_PERINGATAN,
        ))

    # Urutkan: yang mendekati batas (paling kritis) di atas
    daftarStatus.sort(key=lambda x: x.persenTerpakai, reverse=True)
    return daftarStatus


# ============================================================
#  FUNGSI PRIVAT: Jumlah Notifikasi Belum Dibaca
# ============================================================
def _hitungNotifikasiBelumDibaca(db: Session, penggunaId: int) -> int:
    """
    Menghitung jumlah notifikasi yang belum dibaca oleh pengguna.
    Ditampilkan sebagai badge di ikon notifikasi aplikasi.
    """
    return db.query(func.count(Notifikasi.notifikasiId)).filter(
        Notifikasi.penggunaId == penggunaId,
        Notifikasi.statusBaca == False
    ).scalar() or 0
