-- ============================================================
--  ACAKEHAN — Aplikasi Catatan Keuangan Harian
--  File    : acakehan_query_referensi.sql
--  Fungsi  : Kumpulan query SQL siap pakai untuk semua
--            kebutuhan backend Acakehan.
--            Kompatibel MySQL & PostgreSQL (catatan perbedaan
--            ditandai dengan komentar inline).
-- ============================================================


-- ============================================================
--  BAGIAN 1: QUERY AUTENTIKASI
-- ============================================================

-- [1.1] Cek apakah email sudah terdaftar (saat registrasi)
SELECT COUNT(*) AS jumlah_email
FROM   tbl_pengguna
WHERE  email = 'budi@acakehan.test';


-- [1.2] Ambil data pengguna untuk proses login
SELECT
    pengguna_id,
    nama_lengkap,
    email,
    password_hash,
    status_aktif,
    peran_user,
    terakhir_login
FROM   tbl_pengguna
WHERE  email        = 'budi@acakehan.test'
  AND  status_aktif = 1;


-- [1.3] Perbarui timestamp terakhir login
UPDATE tbl_pengguna
SET    terakhir_login   = NOW()
WHERE  pengguna_id      = 1;


-- ============================================================
--  BAGIAN 2: QUERY TRANSAKSI
-- ============================================================

-- [2.1] Tambah transaksi baru
INSERT INTO tbl_transaksi
    (pengguna_id, kategori_id, jumlah_nominal, tipe_transaksi,
     tanggal_transaksi, catatan_tambahan)
VALUES
    (1, 8, 75000.00, 'pengeluaran', '2024-07-21', 'Makan siang bersama tim');


-- [2.2] Ambil riwayat transaksi dengan filter + pagination
-- MySQL:
SELECT
    t.transaksi_id,
    k.nama_kategori,
    k.ikon_kategori,
    k.tipe_kategori,
    t.jumlah_nominal,
    t.tipe_transaksi,
    t.tanggal_transaksi,
    t.catatan_tambahan,
    t.tanggal_dicatat
FROM
    tbl_transaksi t
    JOIN tbl_kategori k ON k.kategori_id = t.kategori_id
WHERE
    t.pengguna_id   = 1
    AND t.status_hapus   = 0
    -- Filter opsional (hapus yang tidak dipakai):
    AND t.tipe_transaksi  = 'pengeluaran'          -- filter tipe
    AND MONTH(t.tanggal_transaksi) = 7             -- filter bulan (MySQL)
    AND YEAR(t.tanggal_transaksi)  = 2024          -- filter tahun (MySQL)
    -- PostgreSQL: EXTRACT(MONTH FROM t.tanggal_transaksi) = 7
    --             EXTRACT(YEAR  FROM t.tanggal_transaksi) = 2024
ORDER BY
    t.tanggal_transaksi DESC,
    t.tanggal_dicatat   DESC
LIMIT  20   -- per_halaman
OFFSET 0;   -- (halaman - 1) * per_halaman


-- [2.3] Hitung total data untuk pagination
SELECT COUNT(*) AS total_data
FROM   tbl_transaksi t
WHERE  t.pengguna_id   = 1
  AND  t.status_hapus  = 0
  AND  t.tipe_transaksi = 'pengeluaran'
  AND  MONTH(t.tanggal_transaksi) = 7
  AND  YEAR(t.tanggal_transaksi)  = 2024;


-- [2.4] Detail satu transaksi berdasarkan ID
SELECT
    t.transaksi_id,
    t.pengguna_id,
    k.kategori_id,
    k.nama_kategori,
    k.ikon_kategori,
    k.tipe_kategori,
    t.jumlah_nominal,
    t.tipe_transaksi,
    t.tanggal_transaksi,
    t.catatan_tambahan,
    t.bukti_struk,
    t.tanggal_dicatat
FROM
    tbl_transaksi t
    JOIN tbl_kategori k ON k.kategori_id = t.kategori_id
WHERE
    t.transaksi_id = 1
    AND t.pengguna_id  = 1   -- Pastikan transaksi milik pengguna yang request
    AND t.status_hapus = 0;


-- [2.5] Soft delete transaksi
UPDATE tbl_transaksi
SET    status_hapus  = 1,
       diperbarui_pada = NOW()
WHERE  transaksi_id  = 1
  AND  pengguna_id   = 1   -- Keamanan: hanya bisa hapus milik sendiri
  AND  status_hapus  = 0;


-- ============================================================
--  BAGIAN 3: QUERY ANGGARAN
-- ============================================================

-- [3.1] Ambil anggaran aktif pengguna bulan ini
SELECT
    a.anggaran_id,
    k.nama_kategori,
    k.ikon_kategori,
    a.batas_maksimal,
    a.total_terpakai,
    ROUND((a.total_terpakai / a.batas_maksimal) * 100, 2) AS persen_terpakai,
    GREATEST(0, a.batas_maksimal - a.total_terpakai)       AS sisa_anggaran,
    a.status_notifikasi
FROM
    tbl_anggaran  a
    JOIN tbl_kategori k ON k.kategori_id = a.kategori_id
WHERE
    a.pengguna_id    = 1
    AND a.periodes_bulan  = 7
    AND a.periode_tahun   = 2024
ORDER BY
    persen_terpakai DESC;


-- [3.2] Perbarui total_terpakai setelah ada transaksi pengeluaran baru
--       (dijalankan oleh backend setelah INSERT transaksi)
UPDATE tbl_anggaran
SET    total_terpakai  = total_terpakai + 75000.00,
       diperbarui_pada  = NOW()
WHERE  pengguna_id     = 1
  AND  kategori_id     = 8
  AND  periodes_bulan  = 7
  AND  periode_tahun   = 2024;


-- [3.3] Cek apakah perlu kirim notifikasi (persen >= 80% dan belum pernah notif)
SELECT
    anggaran_id,
    ROUND((total_terpakai / batas_maksimal) * 100, 2)    AS persen_terpakai,
    GREATEST(0, batas_maksimal - total_terpakai)           AS sisa_anggaran,
    status_notifikasi
FROM   tbl_anggaran
WHERE  pengguna_id     = 1
  AND  kategori_id     = 8
  AND  periodes_bulan  = 7
  AND  periode_tahun   = 2024
  AND  (total_terpakai / batas_maksimal) * 100 >= 80.00
  AND  status_notifikasi = 0;


-- [3.4] Tandai notifikasi sudah terkirim (anti-spam bulan ini)
UPDATE tbl_anggaran
SET    status_notifikasi = 1,
       diperbarui_pada   = NOW()
WHERE  anggaran_id       = 1;


-- [3.5] Tambah anggaran baru
INSERT INTO tbl_anggaran
    (pengguna_id, kategori_id, batas_maksimal, periodes_bulan, periode_tahun)
VALUES
    (1, 14, 500000.00, 8, 2024);  -- Anggaran Hiburan Agustus 2024


-- ============================================================
--  BAGIAN 4: QUERY DASHBOARD
-- ============================================================

-- [4.1] Ringkasan keuangan bulan ini (pemasukan, pengeluaran, saldo)
--       SATU query efisien menggunakan CASE WHEN
SELECT
    SUM(CASE WHEN tipe_transaksi = 'pemasukan'
             THEN jumlah_nominal ELSE 0 END)   AS total_pemasukan,
    SUM(CASE WHEN tipe_transaksi = 'pengeluaran'
             THEN jumlah_nominal ELSE 0 END)   AS total_pengeluaran,
    SUM(CASE
            WHEN tipe_transaksi = 'pemasukan'   THEN  jumlah_nominal
            WHEN tipe_transaksi = 'pengeluaran' THEN -jumlah_nominal
        END)                                   AS saldo_bersih,
    COUNT(transaksi_id)                        AS jumlah_transaksi
FROM
    tbl_transaksi
WHERE
    pengguna_id  = 1
    AND status_hapus      = 0
    AND MONTH(tanggal_transaksi) = MONTH(NOW())  -- MySQL
    AND YEAR(tanggal_transaksi)  = YEAR(NOW());  -- MySQL
    -- PostgreSQL: EXTRACT(MONTH FROM tanggal_transaksi) = EXTRACT(MONTH FROM NOW())
    --             EXTRACT(YEAR  FROM tanggal_transaksi) = EXTRACT(YEAR  FROM NOW())


-- [4.2] Pengeluaran per kategori bulan ini (untuk grafik Pie Chart)
SELECT
    k.nama_kategori,
    k.ikon_kategori,
    SUM(t.jumlah_nominal)    AS total_nominal,
    COUNT(t.transaksi_id)    AS jumlah_transaksi,
    ROUND(
        SUM(t.jumlah_nominal) /
        (SELECT SUM(jumlah_nominal)
         FROM   tbl_transaksi
         WHERE  pengguna_id  = 1
           AND  status_hapus = 0
           AND  tipe_transaksi = 'pengeluaran'
           AND  MONTH(tanggal_transaksi) = MONTH(NOW())
           AND  YEAR(tanggal_transaksi)  = YEAR(NOW())
        ) * 100, 2
    )                        AS persen_dari_total
FROM
    tbl_transaksi t
    JOIN tbl_kategori k ON k.kategori_id = t.kategori_id
WHERE
    t.pengguna_id    = 1
    AND t.tipe_transaksi  = 'pengeluaran'
    AND t.status_hapus    = 0
    AND MONTH(t.tanggal_transaksi) = MONTH(NOW())
    AND YEAR(t.tanggal_transaksi)  = YEAR(NOW())
GROUP BY
    k.kategori_id, k.nama_kategori, k.ikon_kategori
ORDER BY
    total_nominal DESC;


-- [4.3] Tren 6 bulan terakhir (untuk grafik Line Chart)
--       Satu query untuk semua 6 bulan, dikelompokkan di aplikasi
SELECT
    YEAR(t.tanggal_transaksi)   AS tahun,
    MONTH(t.tanggal_transaksi)  AS bulan,
    SUM(CASE WHEN tipe_transaksi = 'pemasukan'
             THEN jumlah_nominal ELSE 0 END)  AS total_pemasukan,
    SUM(CASE WHEN tipe_transaksi = 'pengeluaran'
             THEN jumlah_nominal ELSE 0 END)  AS total_pengeluaran,
    SUM(CASE
            WHEN tipe_transaksi = 'pemasukan'   THEN  jumlah_nominal
            WHEN tipe_transaksi = 'pengeluaran' THEN -jumlah_nominal
        END)                                  AS saldo_bersih
FROM
    tbl_transaksi
WHERE
    pengguna_id   = 1
    AND status_hapus   = 0
    -- MySQL: 6 bulan terakhir
    AND tanggal_transaksi >= DATE_FORMAT(NOW() - INTERVAL 5 MONTH, '%Y-%m-01')
    -- PostgreSQL: AND tanggal_transaksi >= DATE_TRUNC('month', NOW() - INTERVAL '5 months')
GROUP BY
    YEAR(tanggal_transaksi),
    MONTH(tanggal_transaksi)
ORDER BY
    tahun  ASC,
    bulan  ASC;


-- [4.4] Jumlah notifikasi belum dibaca (untuk badge di UI)
SELECT COUNT(*) AS jumlah_belum_dibaca
FROM   tbl_notifikasi
WHERE  pengguna_id = 1
  AND  status_baca = 0;


-- ============================================================
--  BAGIAN 5: QUERY NOTIFIKASI
-- ============================================================

-- [5.1] Ambil semua notifikasi pengguna (terbaru di atas)
SELECT
    notifikasi_id,
    judul_pesan,
    isi_pesan,
    tipe_notifikasi,
    status_baca,
    tanggal_kirim
FROM   tbl_notifikasi
WHERE  pengguna_id = 1
ORDER BY
    status_baca   ASC,    -- yang belum dibaca duluan
    tanggal_kirim DESC
LIMIT 20;


-- [5.2] Tandai semua notifikasi sebagai sudah dibaca
UPDATE tbl_notifikasi
SET    status_baca = 1
WHERE  pengguna_id = 1
  AND  status_baca = 0;


-- [5.3] Tandai satu notifikasi sebagai sudah dibaca
UPDATE tbl_notifikasi
SET    status_baca = 1
WHERE  notifikasi_id = 2
  AND  pengguna_id   = 1;  -- Keamanan: pastikan milik pengguna yang request


-- ============================================================
--  BAGIAN 6: QUERY KATEGORI
-- ============================================================

-- [6.1] Ambil semua kategori yang bisa dipakai pengguna
--       (kategori global + kategori custom miliknya sendiri)
SELECT
    kategori_id,
    nama_kategori,
    ikon_kategori,
    tipe_kategori,
    CASE WHEN pengguna_id IS NULL THEN TRUE ELSE FALSE END AS adalah_global
FROM   tbl_kategori
WHERE
    pengguna_id IS NULL           -- kategori global sistem
    OR pengguna_id = 1            -- atau kategori custom pengguna ini
ORDER BY
    tipe_kategori ASC,
    adalah_global DESC,           -- global duluan
    nama_kategori ASC;


-- [6.2] Ambil hanya kategori pengeluaran (untuk form tambah anggaran)
SELECT
    kategori_id,
    nama_kategori,
    ikon_kategori
FROM   tbl_kategori
WHERE
    tipe_kategori = 'pengeluaran'
    AND (pengguna_id IS NULL OR pengguna_id = 1)
ORDER BY
    nama_kategori ASC;


-- ============================================================
--  BAGIAN 7: QUERY ADMIN
-- ============================================================

-- [7.1] Statistik pengguna (untuk halaman admin)
SELECT
    COUNT(*)                                             AS total_pengguna,
    SUM(CASE WHEN status_aktif = 1 THEN 1 ELSE 0 END)   AS pengguna_aktif,
    SUM(CASE WHEN peran_user = 'admin' THEN 1 ELSE 0 END) AS jumlah_admin,
    SUM(CASE WHEN tanggal_daftar >= DATE_SUB(NOW(), INTERVAL 30 DAY)
             THEN 1 ELSE 0 END)                          AS daftar_30_hari_terakhir
FROM tbl_pengguna;


-- [7.2] Total transaksi per pengguna (monitoring admin)
SELECT
    p.pengguna_id,
    p.nama_lengkap,
    p.email,
    COUNT(t.transaksi_id)         AS total_transaksi,
    SUM(t.jumlah_nominal)         AS total_nominal_semua,
    MAX(t.tanggal_transaksi)      AS transaksi_terakhir
FROM
    tbl_pengguna p
    LEFT JOIN tbl_transaksi t
        ON  t.pengguna_id  = p.pengguna_id
        AND t.status_hapus = 0
GROUP BY
    p.pengguna_id, p.nama_lengkap, p.email
ORDER BY
    total_transaksi DESC;


-- ============================================================
--  BAGIAN 8: MAINTENANCE
-- ============================================================

-- [8.1] Hapus permanen transaksi yang sudah soft-deleted lebih dari 90 hari
--       (jalankan sebagai cron job bulanan)
DELETE FROM tbl_transaksi
WHERE  status_hapus     = 1
  AND  diperbarui_pada  < NOW() - INTERVAL 90 DAY;
  -- PostgreSQL: AND diperbarui_pada < NOW() - INTERVAL '90 days'


-- [8.2] Hapus token refresh yang sudah kadaluarsa
DELETE FROM tbl_token_refresh
WHERE  tanggal_kadaluarsa < NOW()
   OR  digunakan          = 1;


-- [8.3] Statistik ukuran database (MySQL)
SELECT
    TABLE_NAME        AS 'Tabel',
    TABLE_ROWS        AS 'Estimasi Baris',
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Ukuran (MB)'
FROM
    information_schema.TABLES
WHERE
    TABLE_SCHEMA = 'db_acakehan'
ORDER BY
    (DATA_LENGTH + INDEX_LENGTH) DESC;
