"""
============================================================
  ACAKEHAN — Aplikasi Catatan Keuangan Harian
  File   : controllers/controller_transaksi.py
  Fungsi : Endpoint Pencatatan & Manajemen Transaksi
  Pola   : MVC — Layer Controller
  Metode : POST /api/transaksi            (tambah transaksi baru)
           GET  /api/transaksi            (daftar riwayat transaksi)
           GET  /api/transaksi/<id>       (detail satu transaksi)
           DELETE /api/transaksi/<id>     (hapus lunak / soft delete)
============================================================
"""

from flask import Blueprint, request, g
from datetime import datetime, timezone
from sqlalchemy import extract, and_

from extensions import db
from models.model_database import Transaksi, Kategori, Anggaran, Notifikasi
from middleware.autentikasi_jwt import wajib_login
from utils.pembantu import (
    validasiNominalUang,
    validasiFormatTanggal,
    formatRupiah,
    buatResponAPI,
)
from config.konfigurasi import KonfigurasiUtama as Konfigurasi


routerTransaksi = Blueprint("transaksi", __name__, url_prefix="/api/transaksi")


# ============================================================
#  FUNGSI PRIVAT: Cek & Picu Notifikasi Anggaran
# ============================================================
def _periksaBatasAnggaran(
    penggunaId: int,
    kategoriId: int,
    nominalBaru: float,
    tanggalTransaksi
) -> dict:
    """
    Memeriksa apakah penambahan transaksi pengeluaran menyebabkan
    total terpakai melewati batas peringatan anggaran (default: 80%).

    Fungsi ini dipanggil setelah transaksi berhasil disimpan.
    Jika batas terlampaui DAN notifikasi belum pernah dikirim
    di periode ini, sistem akan:
      1. Membuat record Notifikasi di database
      2. Mengupdate statusNotifikasi di tabel Anggaran
      3. Mengembalikan data notifikasi untuk dikirim ke klien

    Args:
        penggunaId      : ID pengguna pemilik transaksi
        kategoriId      : ID kategori transaksi
        nominalBaru     : Jumlah nominal transaksi yang baru dicatat
        tanggalTransaksi: Objek date transaksi (untuk menentukan periode)

    Returns:
        dict berisi info status anggaran dan notifikasi (jika ada)
    """
    # Tentukan periode bulan & tahun dari tanggal transaksi
    bulanPeriode = tanggalTransaksi.month
    tahunPeriode = tanggalTransaksi.year

    # Cari anggaran yang relevan untuk pengguna, kategori, dan periode ini
    anggaran = Anggaran.query.filter_by(
        pengguna_id    = penggunaId,
        kategori_id    = kategoriId,
        periodesBulan  = bulanPeriode,
        periodeTahun   = tahunPeriode,
    ).first()

    # Jika tidak ada anggaran yang ditetapkan, tidak perlu pengecekan lebih lanjut
    if not anggaran:
        return {
            "adaAnggaran":      False,
            "adaNotifikasi":    False,
            "pesanAnggaran":    "Tidak ada anggaran yang ditetapkan untuk kategori ini."
        }

    # ── Update total terpakai di anggaran ───────────────────────────
    # Tambahkan nominal transaksi baru ke total yang sudah ada
    totalBaru = float(anggaran.totalTerpakai) + nominalBaru
    anggaran.totalTerpakai = totalBaru

    # ── Hitung persentase penggunaan anggaran ────────────────────────
    # Formula: (total terpakai / batas maksimal) × 100
    persenTerpakai = (totalBaru / float(anggaran.batasMaksimal)) * 100

    infoAnggaran = {
        "adaAnggaran":    True,
        "anggaranId":     anggaran.anggaran_id,
        "batasMaksimal":  float(anggaran.batasMaksimal),
        "totalTerpakai":  totalBaru,
        "persenTerpakai": round(persenTerpakai, 2),
        "adaNotifikasi":  False,
        "notifikasi":     None,
    }

    # ── Logika peringatan: apakah sudah melewati batas 80%? ─────────
    # statusNotifikasi = 0 → notifikasi 80% belum pernah dikirim bulan ini
    # statusNotifikasi = 1 → sudah dikirim, jangan kirim lagi (anti-spam)
    sudahMelampauiBatas = persenTerpakai >= Konfigurasi.BATAS_PERSEN_PERINGATAN
    notifikasiBelumTerkirim = anggaran.statusNotifikasi == 0

    if sudahMelampauiBatas and notifikasiBelumTerkirim:
        # Tentukan isi pesan berdasarkan seberapa parah kondisi anggaran
        if persenTerpakai >= 100:
            judulPesan = "⛔ Anggaran Habis!"
            isiPesan = (
                f"Anggaran kategori '{anggaran.kategori.namaKategori}' "
                f"untuk {_namaBulan(bulanPeriode)} {tahunPeriode} "
                f"telah HABIS ({round(persenTerpakai, 1)}%). "
                f"Total terpakai: {formatRupiah(totalBaru)} "
                f"dari batas {formatRupiah(float(anggaran.batasMaksimal))}."
            )
            tipeNotif = "peringatan"
        else:
            judulPesan = f"⚠️ Anggaran Mendekati Batas ({round(persenTerpakai, 1)}%)"
            isiPesan = (
                f"Pengeluaran kategori '{anggaran.kategori.namaKategori}' "
                f"sudah mencapai {round(persenTerpakai, 1)}% dari anggaran "
                f"{_namaBulan(bulanPeriode)} {tahunPeriode}. "
                f"Sisa anggaran: {formatRupiah(float(anggaran.batasMaksimal) - totalBaru)}."
            )
            tipeNotif = "peringatan"

        # Buat record notifikasi di database untuk riwayat
        notifikasiBaru = Notifikasi(
            pengguna_id    = penggunaId,
            anggaran_id    = anggaran.anggaran_id,
            judulPesan     = judulPesan,
            isiPesan       = isiPesan,
            tipeNotifikasi = tipeNotif,
            statusBaca     = 0,
            tanggalKirim   = datetime.now(timezone.utc),
        )
        db.session.add(notifikasiBaru)

        # Tandai bahwa notifikasi sudah dikirim agar tidak terulang
        anggaran.statusNotifikasi = 1

        infoAnggaran["adaNotifikasi"] = True
        infoAnggaran["notifikasi"]    = {
            "judul": judulPesan,
            "pesan": isiPesan,
            "tipe":  tipeNotif,
        }

    return infoAnggaran


def _namaBulan(nomorBulan: int) -> str:
    """Mengonversi nomor bulan ke nama bulan dalam Bahasa Indonesia."""
    daftarBulan = [
        "", "Januari", "Februari", "Maret", "April", "Mei", "Juni",
        "Juli", "Agustus", "September", "Oktober", "November", "Desember"
    ]
    return daftarBulan[nomorBulan] if 1 <= nomorBulan <= 12 else "?"


# ============================================================
#  ENDPOINT: POST /api/transaksi
#  Fungsi  : Mencatat transaksi baru (pemasukan / pengeluaran)
# ============================================================
@routerTransaksi.route("", methods=["POST"])
@wajib_login
def tambahTransaksi():
    """
    Mencatat transaksi keuangan baru milik pengguna yang sedang login.

    Header wajib:
        Authorization: Bearer <tokenAkses>

    Body JSON:
        {
            "kategoriId"       : 3,
            "jumlahNominal"    : 150000,
            "tipeTransaksi"    : "pengeluaran",
            "tanggalTransaksi" : "2024-07-15",
            "catatanTambahan"  : "Makan siang bersama tim" (opsional)
        }

    Alur Proses:
        1. Middleware @wajib_login memvalidasi token JWT
        2. Validasi kelengkapan dan format field input
        3. Pastikan kategori ada dan tipenya sesuai tipe transaksi
        4. Simpan transaksi ke database
        5. Jika pengeluaran → periksa batas anggaran secara otomatis
        6. Kembalikan respons + info anggaran + notifikasi (jika ada)
    """
    try:
        # Data pengguna sudah tersedia dari middleware @wajib_login
        penggunaAktif = g.pengguna_aktif

        # ── Langkah 1: Ambil dan periksa body request ────────────────
        dataRequest = request.get_json(silent=True)
        if not dataRequest:
            return buatResponAPI(
                berhasil=False,
                pesan="Body request tidak valid atau bukan format JSON.",
                kode_status=400
            )

        kategoriId       = dataRequest.get("kategoriId")
        jumlahInput      = dataRequest.get("jumlahNominal")
        tipeTransaksi    = dataRequest.get("tipeTransaksi",    "").strip().lower()
        tanggalStr       = dataRequest.get("tanggalTransaksi", "").strip()
        catatanTambahan  = dataRequest.get("catatanTambahan",  "").strip() or None

        # ── Langkah 2: Validasi field wajib tidak boleh kosong ───────
        fieldKosong = []
        if kategoriId    is None: fieldKosong.append("kategoriId")
        if jumlahInput   is None: fieldKosong.append("jumlahNominal")
        if not tipeTransaksi:     fieldKosong.append("tipeTransaksi")
        if not tanggalStr:        fieldKosong.append("tanggalTransaksi")

        if fieldKosong:
            return buatResponAPI(
                berhasil=False,
                pesan=f"Field berikut wajib diisi: {', '.join(fieldKosong)}.",
                kode_status=422
            )

        # ── Langkah 3: Validasi nilai tipe transaksi ─────────────────
        nilaiTipeValid = ("pemasukan", "pengeluaran")
        if tipeTransaksi not in nilaiTipeValid:
            return buatResponAPI(
                berhasil=False,
                pesan=f"Nilai tipeTransaksi tidak valid. "
                      f"Gunakan salah satu dari: {', '.join(nilaiTipeValid)}.",
                kode_status=422
            )

        # ── Langkah 4: Validasi nominal uang ─────────────────────────
        hasilValidasiNominal = validasiNominalUang(jumlahInput)
        if not hasilValidasiNominal["valid"]:
            return buatResponAPI(
                berhasil=False,
                pesan=hasilValidasiNominal["pesan"],
                kode_status=422
            )
        jumlahNominal = hasilValidasiNominal["nilai"]

        # ── Langkah 5: Validasi format tanggal ───────────────────────
        hasilValidasiTanggal = validasiFormatTanggal(tanggalStr)
        if not hasilValidasiTanggal["valid"]:
            return buatResponAPI(
                berhasil=False,
                pesan=hasilValidasiTanggal["pesan"],
                kode_status=422
            )
        objTanggal = hasilValidasiTanggal["tanggal"]

        # ── Langkah 6: Verifikasi kategori ada di database ───────────
        # Kategori valid adalah: milik pengguna ini ATAU kategori global (pengguna_id=NULL)
        kategori = Kategori.query.filter(
            Kategori.kategori_id == kategoriId,
            (Kategori.pengguna_id == penggunaAktif.pengguna_id) |
            (Kategori.pengguna_id.is_(None))
        ).first()

        if not kategori:
            return buatResponAPI(
                berhasil=False,
                pesan=f"Kategori dengan ID {kategoriId} tidak ditemukan "
                       "atau tidak dapat diakses oleh akun Anda.",
                kode_status=404
            )

        # ── Langkah 7: Pastikan tipe kategori sesuai tipe transaksi ──
        # Contoh: kategori "Makanan" (pengeluaran) tidak bisa dipakai
        # untuk mencatat transaksi berjenis "pemasukan"
        if kategori.tipeKategori != tipeTransaksi:
            return buatResponAPI(
                berhasil=False,
                pesan=(
                    f"Kategori '{kategori.namaKategori}' adalah kategori "
                    f"'{kategori.tipeKategori}', tidak cocok dengan tipe "
                    f"transaksi '{tipeTransaksi}' yang Anda pilih."
                ),
                kode_status=422
            )

        # ── Langkah 8: Buat dan simpan transaksi ke database ─────────
        transaksiBaru = Transaksi(
            pengguna_id       = penggunaAktif.pengguna_id,
            kategori_id       = kategori.kategori_id,
            jumlahNominal     = jumlahNominal,
            tipeTransaksi     = tipeTransaksi,
            tanggalTransaksi  = objTanggal,
            catatanTambahan   = catatanTambahan,
            tanggalDicatat    = datetime.now(timezone.utc),
            statusHapus       = 0,
        )

        db.session.add(transaksiBaru)
        db.session.flush()   # Flush agar transaksi_id tersedia sebelum commit

        # ── Langkah 9: Pengecekan anggaran (KHUSUS pengeluaran) ──────
        # Logika ini hanya berjalan untuk transaksi bertipe pengeluaran.
        # Untuk pemasukan, tidak ada batas anggaran yang perlu diperiksa.
        infoAnggaran = None
        if tipeTransaksi == "pengeluaran":
            infoAnggaran = _periksaBatasAnggaran(
                penggunaId       = penggunaAktif.pengguna_id,
                kategoriId       = kategori.kategori_id,
                nominalBaru      = jumlahNominal,
                tanggalTransaksi = objTanggal,
            )

        # Commit semua perubahan: transaksi + update anggaran + notifikasi
        db.session.commit()

        # ── Langkah 10: Susun dan kembalikan respons ─────────────────
        dataRespons = {
            "transaksi":   transaksiBaru.ke_dict(),
            "anggaran":    infoAnggaran,
        }

        # Jika ada notifikasi anggaran, sertakan di respons agar
        # aplikasi mobile bisa langsung menampilkan popup peringatan
        pesanSukses = (
            f"Transaksi {tipeTransaksi} sebesar {formatRupiah(jumlahNominal)} "
            f"berhasil dicatat."
        )
        if infoAnggaran and infoAnggaran.get("adaNotifikasi"):
            pesanSukses += (
                f" ⚠️ Perhatian: {infoAnggaran['notifikasi']['pesan']}"
            )

        return buatResponAPI(
            berhasil    = True,
            pesan       = pesanSukses,
            data        = dataRespons,
            kode_status = 201
        )

    except Exception as galat:
        db.session.rollback()
        print(f"[ERROR] tambahTransaksi: {str(galat)}")
        return buatResponAPI(
            berhasil    = False,
            pesan       = "Terjadi kesalahan pada server saat mencatat transaksi. "
                          "Silakan coba lagi.",
            kode_status = 500
        )


# ============================================================
#  ENDPOINT: GET /api/transaksi
#  Fungsi  : Ambil daftar riwayat transaksi pengguna (dengan filter)
# ============================================================
@routerTransaksi.route("", methods=["GET"])
@wajib_login
def daftarTransaksi():
    """
    Mengambil riwayat transaksi milik pengguna yang sedang login.

    Query parameter opsional:
        ?tipe=pengeluaran       → filter berdasarkan tipe
        ?bulan=7&tahun=2024     → filter berdasarkan periode bulan/tahun
        ?kategori_id=3          → filter berdasarkan kategori
        ?halaman=1&per_halaman=20 → pagination
    """
    try:
        penggunaAktif = g.pengguna_aktif

        # Ambil parameter query dari URL
        filterTipe       = request.args.get("tipe",        "").strip().lower() or None
        filterBulan      = request.args.get("bulan",       type=int)
        filterTahun      = request.args.get("tahun",       type=int)
        filterKategoriId = request.args.get("kategori_id", type=int)
        halaman          = max(1, request.args.get("halaman",      default=1,  type=int))
        perHalaman       = min(100, request.args.get("per_halaman", default=20, type=int))

        # Mulai query dasar: transaksi milik pengguna yang belum dihapus
        queryDasar = Transaksi.query.filter_by(
            pengguna_id = penggunaAktif.pengguna_id,
            statusHapus = 0
        )

        # Terapkan filter opsional
        if filterTipe in ("pemasukan", "pengeluaran"):
            queryDasar = queryDasar.filter_by(tipeTransaksi=filterTipe)

        if filterBulan and 1 <= filterBulan <= 12:
            queryDasar = queryDasar.filter(
                extract("month", Transaksi.tanggalTransaksi) == filterBulan
            )

        if filterTahun and filterTahun >= 2000:
            queryDasar = queryDasar.filter(
                extract("year", Transaksi.tanggalTransaksi) == filterTahun
            )

        if filterKategoriId:
            queryDasar = queryDasar.filter_by(kategori_id=filterKategoriId)

        # Urutkan dari transaksi terbaru, lalu terapkan pagination
        hasilPaginasi = (
            queryDasar
            .order_by(Transaksi.tanggalTransaksi.desc(), Transaksi.tanggalDicatat.desc())
            .paginate(page=halaman, per_page=perHalaman, error_out=False)
        )

        return buatResponAPI(
            berhasil = True,
            pesan    = f"Berhasil mengambil {len(hasilPaginasi.items)} data transaksi.",
            data     = {
                "transaksi":   [t.ke_dict() for t in hasilPaginasi.items],
                "pagination": {
                    "totalData":     hasilPaginasi.total,
                    "totalHalaman":  hasilPaginasi.pages,
                    "halamanSaat":   hasilPaginasi.page,
                    "perHalaman":    perHalaman,
                    "adaHalamanBerikutnya": hasilPaginasi.has_next,
                    "adaHalamanSebelumnya": hasilPaginasi.has_prev,
                }
            }
        )

    except Exception as galat:
        print(f"[ERROR] daftarTransaksi: {str(galat)}")
        return buatResponAPI(
            berhasil=False,
            pesan="Terjadi kesalahan saat mengambil data transaksi.",
            kode_status=500
        )


# ============================================================
#  ENDPOINT: DELETE /api/transaksi/<transaksi_id>
#  Fungsi  : Hapus lunak (soft delete) transaksi
# ============================================================
@routerTransaksi.route("/<int:transaksiId>", methods=["DELETE"])
@wajib_login
def hapusTransaksi(transaksiId: int):
    """
    Menghapus transaksi secara lunak (soft delete).
    Data tidak benar-benar dihapus dari database — hanya
    menandai statusHapus = 1 agar data tetap bisa diaudit.
    """
    try:
        penggunaAktif = g.pengguna_aktif

        # Cari transaksi yang dimiliki oleh pengguna ini
        transaksi = Transaksi.query.filter_by(
            transaksi_id = transaksiId,
            pengguna_id  = penggunaAktif.pengguna_id,
            statusHapus  = 0
        ).first()

        if not transaksi:
            return buatResponAPI(
                berhasil=False,
                pesan=f"Transaksi dengan ID {transaksiId} tidak ditemukan "
                       "atau sudah dihapus sebelumnya.",
                kode_status=404
            )

        # Tandai sebagai terhapus (soft delete)
        transaksi.statusHapus = 1
        db.session.commit()

        return buatResponAPI(
            berhasil = True,
            pesan    = "Transaksi berhasil dihapus."
        )

    except Exception as galat:
        db.session.rollback()
        print(f"[ERROR] hapusTransaksi: {str(galat)}")
        return buatResponAPI(
            berhasil=False,
            pesan="Terjadi kesalahan saat menghapus transaksi.",
            kode_status=500
        )
