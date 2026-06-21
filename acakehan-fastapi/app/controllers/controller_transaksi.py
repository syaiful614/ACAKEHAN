"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : app/controllers/controller_transaksi.py
  Fungsi : Logika bisnis untuk Pencatatan & Manajemen Transaksi
           termasuk pengecekan otomatis batas anggaran 80%
  Pola   : MVC — Layer Controller
============================================================
"""

from datetime import datetime, timezone
from typing import Optional, List

from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import extract, func, and_

from app.models.model_db import Transaksi, Kategori, Anggaran, Notifikasi, Pengguna
from app.schemas.skema_data import (
    SkemaTambahTransaksi, SkemaDataTransaksi,
    SkemaDataKategori, SkemaInfoAnggaran, SkemaResponTransaksi
)
from app.config.pengaturan import ambilPengaturan
from app.utils.pembantu import formatRupiah, namaBulan

cfg = ambilPengaturan()


# ============================================================
#  FUNGSI PRIVAT: Periksa Batas Anggaran
# ============================================================
def _periksaDanPerbaruiAnggaran(
    db:              Session,
    penggunaId:      int,
    kategoriId:      int,
    nominalTambahan: float,
    tanggalTransaksi
) -> SkemaInfoAnggaran:
    """
    Memeriksa dan memperbarui status anggaran setelah transaksi pengeluaran baru.

    Logika lengkap:
        1. Cari anggaran yang cocok (pengguna + kategori + periode bulan ini)
        2. Tambahkan nominal baru ke totalTerpakai
        3. Hitung persentase terpakai: (totalTerpakai / batasMaksimal) × 100
        4. Jika persentase >= BATAS_PERSEN_PERINGATAN (default 80%) DAN
           notifikasi belum dikirim bulan ini:
           → Buat record Notifikasi di DB
           → Tandai statusNotifikasi = True (anti-duplikasi notif)
        5. Kembalikan info anggaran lengkap termasuk notifikasi (jika ada)

    Args:
        db              : Sesi database aktif
        penggunaId      : ID pengguna pemilik transaksi
        kategoriId      : ID kategori transaksi
        nominalTambahan : Jumlah nominal transaksi baru
        tanggalTransaksi: Objek date untuk menentukan periode bulan/tahun

    Returns:
        SkemaInfoAnggaran berisi status anggaran dan notifikasi
    """
    bulanIni  = tanggalTransaksi.month
    tahunIni  = tanggalTransaksi.year

    # ── Cari anggaran yang relevan ───────────────────────────────
    anggaran = db.query(Anggaran).filter(
        Anggaran.penggunaId   == penggunaId,
        Anggaran.kategoriId   == kategoriId,
        Anggaran.periodesBulan == bulanIni,
        Anggaran.periodeTahun  == tahunIni,
    ).first()

    # Tidak ada anggaran yang ditetapkan → tidak perlu pengecekan
    if not anggaran:
        return SkemaInfoAnggaran(
            adaAnggaran = False,
            pesan       = "Tidak ada anggaran yang ditetapkan untuk kategori ini di periode ini."
        )

    # ── Perbarui total terpakai ───────────────────────────────────
    totalSebelumnya = float(anggaran.totalTerpakai)
    totalBaru       = totalSebelumnya + nominalTambahan
    anggaran.totalTerpakai = totalBaru

    # ── Hitung persentase penggunaan ─────────────────────────────
    batasMaksimal  = float(anggaran.batasMaksimal)
    persenTerpakai = round((totalBaru / batasMaksimal) * 100, 2) if batasMaksimal > 0 else 0.0
    sisaAnggaran   = max(0.0, batasMaksimal - totalBaru)

    infoAnggaran = SkemaInfoAnggaran(
        adaAnggaran    = True,
        anggaranId     = anggaran.anggaranId,
        batasMaksimal  = batasMaksimal,
        totalTerpakai  = totalBaru,
        sisaAnggaran   = sisaAnggaran,
        persenTerpakai = persenTerpakai,
        adaNotifikasi  = False,
        pesan          = f"Anggaran terpakai: {persenTerpakai}% dari {formatRupiah(batasMaksimal)}."
    )

    # ── Logika Notifikasi: cek apakah batas 80% sudah terlampaui ─
    # Syarat kirim notifikasi:
    #   (a) Persentase >= batas peringatan (default 80%)
    #   (b) statusNotifikasi == False (belum pernah dikirim bulan ini)
    sudahMelampauiBatas     = persenTerpakai >= cfg.BATAS_PERSEN_PERINGATAN
    notifikasiBelumDikirim  = not anggaran.statusNotifikasi

    if sudahMelampauiBatas and notifikasiBelumDikirim:
        labelPeriode = f"{namaBulan(bulanIni)} {tahunIni}"
        namaKategori = anggaran.kategori.namaKategori if anggaran.kategori else "?"

        # Tentukan isi notifikasi berdasarkan tingkat keparahan
        if persenTerpakai >= cfg.BATAS_PERSEN_KRITIS:
            judulPesan = f"⛔ Anggaran '{namaKategori}' Telah Habis!"
            isiPesan = (
                f"Pengeluaran kategori '{namaKategori}' pada {labelPeriode} "
                f"telah melebihi batas maksimal! "
                f"Total terpakai: {formatRupiah(totalBaru)} "
                f"(batas: {formatRupiah(batasMaksimal)}). "
                "Harap tinjau kembali pengeluaran Anda."
            )
        else:
            judulPesan = f"⚠️ Peringatan Anggaran '{namaKategori}' ({persenTerpakai}%)"
            isiPesan = (
                f"Pengeluaran kategori '{namaKategori}' pada {labelPeriode} "
                f"sudah mencapai {persenTerpakai}% dari anggaran. "
                f"Sisa anggaran: {formatRupiah(sisaAnggaran)} "
                f"dari {formatRupiah(batasMaksimal)}. "
                "Bijak dalam mengatur keuangan Anda!"
            )

        # Buat record notifikasi di database
        notifikasiBaru = Notifikasi(
            penggunaId     = penggunaId,
            anggaranId     = anggaran.anggaranId,
            judulPesan     = judulPesan,
            isiPesan       = isiPesan,
            tipeNotifikasi = "peringatan",
            statusBaca     = False,
            tanggalKirim   = datetime.now(timezone.utc),
        )
        db.add(notifikasiBaru)

        # Tandai anggaran bahwa notifikasi sudah dikirim (anti-spam)
        anggaran.statusNotifikasi = True

        # Sertakan data notifikasi di respons agar app mobile bisa menampilkan popup
        infoAnggaran.adaNotifikasi = True
        infoAnggaran.notifikasi    = {
            "judul": judulPesan,
            "pesan": isiPesan,
            "tipe":  "peringatan"
        }

    return infoAnggaran


# ============================================================
#  CONTROLLER: Tambah Transaksi Baru
# ============================================================
def kontrolerTambahTransaksi(
    dataBaru:  SkemaTambahTransaksi,
    pengguna:  Pengguna,
    db:        Session
) -> SkemaResponTransaksi:
    """
    Mencatat transaksi keuangan baru dan menjalankan pengecekan anggaran otomatis.

    Alur lengkap:
        1. Validasi kategori ada dan bisa diakses pengguna ini
        2. Pastikan tipe kategori sesuai tipe transaksi
        3. Simpan transaksi ke database
        4. Jika pengeluaran → panggil _periksaDanPerbaruiAnggaran()
        5. Commit semua perubahan (transaksi + anggaran + notifikasi)
        6. Kembalikan respons lengkap

    Args:
        dataBaru  : Data tervalidasi dari SkemaTambahTransaksi
        pengguna  : Objek Pengguna dari dependency JWT
        db        : Sesi database

    Returns:
        SkemaResponTransaksi berisi detail transaksi + info anggaran
    """

    # ── Langkah 1: Validasi kategori ─────────────────────────────
    # Pengguna boleh pakai kategori miliknya sendiri ATAU kategori global (pengguna_id = NULL)
    kategori = db.query(Kategori).filter(
        Kategori.kategoriId == dataBaru.kategoriId,
        (Kategori.penggunaId == pengguna.penggunaId) |
        (Kategori.penggunaId.is_(None))
    ).first()

    if not kategori:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "berhasil": False,
                "pesan":    f"Kategori dengan ID {dataBaru.kategoriId} tidak ditemukan "
                            "atau tidak dapat diakses oleh akun Anda.",
                "kode":     "KATEGORI_TIDAK_ADA"
            }
        )

    # ── Langkah 2: Validasi tipe kategori vs tipe transaksi ──────
    # Kategori "Makanan" (tipe pengeluaran) tidak bisa untuk transaksi pemasukan
    if kategori.tipeKategori != dataBaru.tipeTransaksi:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "berhasil": False,
                "pesan":    (
                    f"Kategori '{kategori.namaKategori}' adalah kategori '{kategori.tipeKategori}', "
                    f"tidak sesuai dengan tipe transaksi '{dataBaru.tipeTransaksi}' yang dipilih. "
                    "Harap pilih kategori yang sesuai."
                ),
                "kode":     "TIPE_TIDAK_SESUAI"
            }
        )

    # ── Langkah 3: Buat dan simpan transaksi ─────────────────────
    transaksiBaru = Transaksi(
        penggunaId       = pengguna.penggunaId,
        kategoriId       = kategori.kategoriId,
        jumlahNominal    = dataBaru.jumlahNominal,
        tipeTransaksi    = dataBaru.tipeTransaksi,
        tanggalTransaksi = dataBaru.tanggalTransaksi,
        catatanTambahan  = dataBaru.catatanTambahan,
        tanggalDicatat   = datetime.now(timezone.utc),
        statusHapus      = False,
    )

    db.add(transaksiBaru)
    db.flush()   # Dapatkan transaksiId sebelum commit

    # ── Langkah 4: Pengecekan anggaran (KHUSUS pengeluaran) ──────
    infoAnggaran: Optional[SkemaInfoAnggaran] = None

    if dataBaru.tipeTransaksi == "pengeluaran":
        infoAnggaran = _periksaDanPerbaruiAnggaran(
            db              = db,
            penggunaId      = pengguna.penggunaId,
            kategoriId      = kategori.kategoriId,
            nominalTambahan = float(dataBaru.jumlahNominal),
            tanggalTransaksi = dataBaru.tanggalTransaksi,
        )

    # ── Langkah 5: Commit semua perubahan sekaligus ───────────────
    # Satu commit untuk: transaksi + update anggaran + notifikasi baru
    db.commit()
    db.refresh(transaksiBaru)

    # ── Langkah 6: Susun respons ─────────────────────────────────
    dataKategori = SkemaDataKategori(
        kategoriId   = kategori.kategoriId,
        namaKategori = kategori.namaKategori,
        ikonKategori = kategori.ikonKategori,
        tipeKategori = kategori.tipeKategori,
        adalahGlobal = kategori.penggunaId is None,
    )

    dataTransaksi = SkemaDataTransaksi(
        transaksiId      = transaksiBaru.transaksiId,
        penggunaId       = transaksiBaru.penggunaId,
        kategori         = dataKategori,
        jumlahNominal    = float(transaksiBaru.jumlahNominal),
        tipeTransaksi    = transaksiBaru.tipeTransaksi,
        tanggalTransaksi = transaksiBaru.tanggalTransaksi,
        catatanTambahan  = transaksiBaru.catatanTambahan,
        tanggalDicatat   = transaksiBaru.tanggalDicatat,
    )

    return SkemaResponTransaksi(transaksi=dataTransaksi, anggaran=infoAnggaran)


# ============================================================
#  CONTROLLER: Daftar Riwayat Transaksi (dengan Filter & Pagination)
# ============================================================
def kontrolerDaftarTransaksi(
    pengguna:    Pengguna,
    db:          Session,
    tipe:        Optional[str] = None,
    bulan:       Optional[int] = None,
    tahun:       Optional[int] = None,
    kategoriId:  Optional[int] = None,
    halaman:     int = 1,
    perHalaman:  int = 20,
) -> dict:
    """
    Mengambil riwayat transaksi pengguna dengan filter opsional dan pagination.

    Args:
        pengguna   : Pengguna yang sedang login
        db         : Sesi database
        tipe       : Filter tipe ("pemasukan" / "pengeluaran")
        bulan      : Filter bulan (1-12)
        tahun      : Filter tahun (YYYY)
        kategoriId : Filter berdasarkan kategori spesifik
        halaman    : Nomor halaman (mulai dari 1)
        perHalaman : Jumlah data per halaman (max 100)
    """
    # Query dasar: transaksi pengguna ini yang belum dihapus
    query = db.query(Transaksi).filter(
        Transaksi.penggunaId == pengguna.penggunaId,
        Transaksi.statusHapus == False
    )

    # Terapkan filter opsional
    if tipe in ("pemasukan", "pengeluaran"):
        query = query.filter(Transaksi.tipeTransaksi == tipe)

    if bulan and 1 <= bulan <= 12:
        query = query.filter(extract("month", Transaksi.tanggalTransaksi) == bulan)

    if tahun and tahun >= 2000:
        query = query.filter(extract("year", Transaksi.tanggalTransaksi) == tahun)

    if kategoriId:
        query = query.filter(Transaksi.kategoriId == kategoriId)

    # Hitung total data untuk info pagination
    totalData = query.count()

    # Terapkan urutan dan pagination
    perHalaman  = min(100, max(1, perHalaman))
    halaman     = max(1, halaman)
    totalHalaman = max(1, -(-totalData // perHalaman))  # Ceiling division

    daftarTransaksi = (
        query
        .order_by(Transaksi.tanggalTransaksi.desc(), Transaksi.tanggalDicatat.desc())
        .offset((halaman - 1) * perHalaman)
        .limit(perHalaman)
        .all()
    )

    # Serialisasi setiap transaksi ke schema
    dataTransaksi = []
    for t in daftarTransaksi:
        kat = None
        if t.kategori:
            kat = SkemaDataKategori(
                kategoriId   = t.kategori.kategoriId,
                namaKategori = t.kategori.namaKategori,
                ikonKategori = t.kategori.ikonKategori,
                tipeKategori = t.kategori.tipeKategori,
                adalahGlobal = t.kategori.penggunaId is None,
            )
        dataTransaksi.append(SkemaDataTransaksi(
            transaksiId      = t.transaksiId,
            penggunaId       = t.penggunaId,
            kategori         = kat,
            jumlahNominal    = float(t.jumlahNominal),
            tipeTransaksi    = t.tipeTransaksi,
            tanggalTransaksi = t.tanggalTransaksi,
            catatanTambahan  = t.catatanTambahan,
            tanggalDicatat   = t.tanggalDicatat,
        ))

    return {
        "transaksi":   dataTransaksi,
        "totalData":   totalData,
        "halaman":     halaman,
        "perHalaman":  perHalaman,
        "totalHalaman": totalHalaman,
        "adaHalamanBerikutnya": halaman < totalHalaman,
    }


# ============================================================
#  CONTROLLER: Hapus Transaksi (Soft Delete)
# ============================================================
def kontrolerHapusTransaksi(transaksiId: int, pengguna: Pengguna, db: Session) -> dict:
    """
    Menghapus transaksi secara lunak (soft delete).
    Data tidak benar-benar dihapus — hanya statusHapus = True.

    Args:
        transaksiId : ID transaksi yang akan dihapus
        pengguna    : Pengguna yang sedang login (hanya bisa hapus miliknya sendiri)
        db          : Sesi database

    Returns:
        Dictionary konfirmasi penghapusan

    Raises:
        HTTPException 404 : Jika transaksi tidak ditemukan atau bukan milik pengguna ini
    """
    transaksi = db.query(Transaksi).filter(
        Transaksi.transaksiId == transaksiId,
        Transaksi.penggunaId  == pengguna.penggunaId,
        Transaksi.statusHapus == False
    ).first()

    if not transaksi:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "berhasil": False,
                "pesan":    f"Transaksi dengan ID {transaksiId} tidak ditemukan "
                            "atau sudah dihapus sebelumnya.",
                "kode":     "TRANSAKSI_TIDAK_ADA"
            }
        )

    # Tandai sebagai terhapus — data tetap ada di DB untuk keperluan audit
    transaksi.statusHapus = True
    db.commit()

    return {"transaksiId": transaksiId, "pesanHapus": "Transaksi berhasil dihapus."}
