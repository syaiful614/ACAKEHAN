-- ============================================================
--  ACAKEHAN — Aplikasi Catatan Keuangan Harian
--  File    : acakehan_seed_data.sql
--  Fungsi  : Data awal & data uji coba realistis
--            Kompatibel dengan MySQL & PostgreSQL
--            (ganti NOW() dengan CURRENT_TIMESTAMP jika perlu)
--
--  JALANKAN SETELAH: acakehan_mysql_ddl.sql / acakehan_postgresql_ddl.sql
--
--  ISI SKRIP:
--    Bagian A — Akun pengguna contoh (3 akun)
--    Bagian B — Kategori custom (tambahan dari pengguna)
--    Bagian C — Anggaran Juli 2024
--    Bagian D — Transaksi Juli 2024 (realistis)
--    Bagian E — Notifikasi
--    Bagian F — Verifikasi data dengan query SELECT
-- ============================================================

-- Gunakan database yang benar
-- MySQL:      USE db_acakehan;
-- PostgreSQL: SET search_path TO acakehan, public;


-- ============================================================
--  BAGIAN A: Akun Pengguna Contoh
--
--  CATATAN KEAMANAN:
--  Kolom password_hash di bawah adalah nilai NYATA dari bcrypt
--  untuk kata sandi "Test1234!" (12 rounds).
--  Di aplikasi nyata, hash ini dihasilkan oleh backend —
--  JANGAN pernah memasukkan password polos ke database.
-- ============================================================

INSERT INTO tbl_pengguna
    (nama_lengkap, email, password_hash, nomor_telepon, status_aktif, peran_user, tanggal_daftar)
VALUES
    (
        'Budi Santoso',
        'budi@acakehan.test',
        -- bcrypt hash untuk kata sandi: Test1234!
        '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewYpzKR.NnFO0Ew6',
        '08123456789',
        1,
        'pengguna',
        '2024-06-01 08:00:00'
    ),
    (
        'Sari Dewi',
        'sari@acakehan.test',
        '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewYpzKR.NnFO0Ew6',
        '08234567890',
        1,
        'pengguna',
        '2024-06-15 10:30:00'
    ),
    (
        'Admin Acakehan',
        'admin@acakehan.test',
        '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewYpzKR.NnFO0Ew6',
        '08111000001',
        1,
        'admin',
        '2024-01-01 00:00:00'
    );

-- Catatan referensi ID yang akan dipakai di bawah:
--   pengguna_id = 1 → Budi Santoso
--   pengguna_id = 2 → Sari Dewi
--   pengguna_id = 3 → Admin Acakehan


-- ============================================================
--  BAGIAN B: Kategori Custom Pengguna
--  Tambahan di luar kategori global yang sudah ada.
-- ============================================================

-- Kategori custom milik Budi (pengguna_id = 1)
INSERT INTO tbl_kategori (nama_kategori, ikon_kategori, tipe_kategori, pengguna_id)
VALUES
    ('Side Project',    'icon-code',       'pemasukan',    1),
    ('Kost & Sewa',     'icon-home',       'pengeluaran',  1),
    ('Langganan Apps',  'icon-apps',       'pengeluaran',  1);

-- Kategori custom milik Sari (pengguna_id = 2)
INSERT INTO tbl_kategori (nama_kategori, ikon_kategori, tipe_kategori, pengguna_id)
VALUES
    ('Jualan Online',   'icon-store',      'pemasukan',    2),
    ('Kecantikan',      'icon-beauty',     'pengeluaran',  2);

-- Catatan referensi kategori global (dari seed DDL):
--   kategori_id = 1  → Gaji          (pemasukan)
--   kategori_id = 2  → Bonus         (pemasukan)
--   kategori_id = 8  → Makanan       (pengeluaran)
--   kategori_id = 9  → Transportasi  (pengeluaran)
--   kategori_id = 10 → Belanja       (pengeluaran)
--   kategori_id = 11 → Tagihan       (pengeluaran)
--   kategori_id = 14 → Hiburan       (pengeluaran)


-- ============================================================
--  BAGIAN C: Anggaran Juli 2024 — Milik Budi (pengguna_id = 1)
-- ============================================================

INSERT INTO tbl_anggaran
    (pengguna_id, kategori_id, batas_maksimal, periodes_bulan, periode_tahun, total_terpakai, status_notifikasi)
VALUES
    -- Makanan: anggaran Rp 1.500.000, sudah terpakai Rp 1.280.000 (85,3%) → SUDAH NOTIF
    (1, 8,  1500000.00, 7, 2024, 1280000.00, 1),
    -- Transportasi: anggaran Rp 500.000, terpakai Rp 210.000 (42%) → AMAN
    (1, 9,   500000.00, 7, 2024,  210000.00, 0),
    -- Tagihan: anggaran Rp 800.000, terpakai Rp 750.000 (93,75%) → SUDAH NOTIF
    (1, 11,  800000.00, 7, 2024,  750000.00, 1),
    -- Hiburan: anggaran Rp 400.000, terpakai Rp 80.000 (20%) → AMAN
    (1, 14,  400000.00, 7, 2024,   80000.00, 0),
    -- Belanja: anggaran Rp 600.000, belum ada pengeluaran
    (1, 10,  600000.00, 7, 2024,       0.00, 0);

-- Anggaran Juli 2024 — Milik Sari (pengguna_id = 2)
INSERT INTO tbl_anggaran
    (pengguna_id, kategori_id, batas_maksimal, periodes_bulan, periode_tahun, total_terpakai, status_notifikasi)
VALUES
    (2, 8,  1200000.00, 7, 2024,  600000.00, 0),
    (2, 9,   400000.00, 7, 2024,  150000.00, 0);


-- ============================================================
--  BAGIAN D: Transaksi Juli 2024 — Data Realistis
-- ============================================================

-- ── Transaksi BUDI (pengguna_id = 1) ────────────────────────

-- Pemasukan
INSERT INTO tbl_transaksi
    (pengguna_id, kategori_id, jumlah_nominal, tipe_transaksi, tanggal_transaksi, catatan_tambahan)
VALUES
    (1, 1, 8000000.00, 'pemasukan', '2024-07-01', 'Gaji bulanan Juli 2024'),
    (1, 2,  500000.00, 'pemasukan', '2024-07-05', 'Bonus proyek Q2'),
    (1, 3,  750000.00, 'pemasukan', '2024-07-10', 'Freelance desain logo klien baru');

-- Pengeluaran — Makanan (sudah 85% dari anggaran)
INSERT INTO tbl_transaksi
    (pengguna_id, kategori_id, jumlah_nominal, tipe_transaksi, tanggal_transaksi, catatan_tambahan)
VALUES
    (1, 8,   85000.00, 'pengeluaran', '2024-07-01', 'Sarapan + makan siang kantor'),
    (1, 8,  125000.00, 'pengeluaran', '2024-07-02', 'Makan malam bersama keluarga'),
    (1, 8,   45000.00, 'pengeluaran', '2024-07-03', 'Kopi dan snack'),
    (1, 8,  200000.00, 'pengeluaran', '2024-07-07', 'Groceries mingguan'),
    (1, 8,   75000.00, 'pengeluaran', '2024-07-08', 'Makan siang + minuman'),
    (1, 8,  180000.00, 'pengeluaran', '2024-07-10', 'Dinner restoran'),
    (1, 8,   90000.00, 'pengeluaran', '2024-07-12', 'Snack dan jajanan'),
    (1, 8,  210000.00, 'pengeluaran', '2024-07-14', 'Belanja bahan makanan'),
    (1, 8,   95000.00, 'pengeluaran', '2024-07-17', 'Makan siang kantor'),
    (1, 8,  175000.00, 'pengeluaran', '2024-07-20', 'Makan bersama teman lama');

-- Pengeluaran — Transportasi
INSERT INTO tbl_transaksi
    (pengguna_id, kategori_id, jumlah_nominal, tipe_transaksi, tanggal_transaksi, catatan_tambahan)
VALUES
    (1, 9,   50000.00, 'pengeluaran', '2024-07-01', 'Ojek online ke kantor'),
    (1, 9,   35000.00, 'pengeluaran', '2024-07-03', 'Grab pergi-pulang'),
    (1, 9,   75000.00, 'pengeluaran', '2024-07-06', 'Bensin motor'),
    (1, 9,   25000.00, 'pengeluaran', '2024-07-08', 'Parkir dan tol'),
    (1, 9,   25000.00, 'pengeluaran', '2024-07-15', 'KRL commuter line');

-- Pengeluaran — Tagihan (sudah 93,75% → kritis)
INSERT INTO tbl_transaksi
    (pengguna_id, kategori_id, jumlah_nominal, tipe_transaksi, tanggal_transaksi, catatan_tambahan)
VALUES
    (1, 11, 350000.00, 'pengeluaran', '2024-07-05', 'Listrik bulan Juli'),
    (1, 11, 150000.00, 'pengeluaran', '2024-07-05', 'Internet Indihome'),
    (1, 11, 150000.00, 'pengeluaran', '2024-07-10', 'Pulsa & paket data'),
    (1, 11, 100000.00, 'pengeluaran', '2024-07-15', 'Air PDAM');

-- Pengeluaran — Hiburan (20% — aman)
INSERT INTO tbl_transaksi
    (pengguna_id, kategori_id, jumlah_nominal, tipe_transaksi, tanggal_transaksi, catatan_tambahan)
VALUES
    (1, 14,  50000.00, 'pengeluaran', '2024-07-07', 'Netflix bulanan'),
    (1, 14,  30000.00, 'pengeluaran', '2024-07-13', 'Spotify Premium');

-- ── Transaksi SARI (pengguna_id = 2) ────────────────────────

INSERT INTO tbl_transaksi
    (pengguna_id, kategori_id, jumlah_nominal, tipe_transaksi, tanggal_transaksi, catatan_tambahan)
VALUES
    (2, 1,  5500000.00, 'pemasukan',  '2024-07-01', 'Gaji bulanan'),
    (2, 8,   120000.00, 'pengeluaran', '2024-07-02', 'Belanja sayur dan buah'),
    (2, 8,    85000.00, 'pengeluaran', '2024-07-05', 'Makan siang di kantin'),
    (2, 8,   195000.00, 'pengeluaran', '2024-07-09', 'Groceries mingguan'),
    (2, 8,    75000.00, 'pengeluaran', '2024-07-14', 'Jajan dan kopi'),
    (2, 8,   125000.00, 'pengeluaran', '2024-07-19', 'Makan malam keluarga'),
    (2, 9,    60000.00, 'pengeluaran', '2024-07-01', 'Ojek online'),
    (2, 9,    45000.00, 'pengeluaran', '2024-07-08', 'Grab car'),
    (2, 9,    45000.00, 'pengeluaran', '2024-07-15', 'KRL + ojek');


-- ============================================================
--  BAGIAN E: Notifikasi
-- ============================================================

INSERT INTO tbl_notifikasi
    (pengguna_id, anggaran_id, judul_pesan, isi_pesan, tipe_notifikasi, status_baca, tanggal_kirim)
VALUES
    (
        1,
        1,  -- anggaran Makanan Budi
        '⚠️ Peringatan Anggaran Makanan (85.3%)',
        'Pengeluaran kategori Makanan & Minuman sudah mencapai 85.3% dari anggaran Juli 2024. '
        'Sisa anggaran: Rp 220.000 dari Rp 1.500.000. Bijak dalam mengatur keuangan Anda!',
        'peringatan',
        1,  -- sudah dibaca
        '2024-07-20 19:30:00'
    ),
    (
        1,
        3,  -- anggaran Tagihan Budi
        '⛔ Peringatan Anggaran Tagihan (93.75%)',
        'Pengeluaran kategori Tagihan & Utilitas sudah mencapai 93.75% dari anggaran Juli 2024. '
        'Sisa anggaran: Rp 50.000 dari Rp 800.000. Harap tinjau kembali pengeluaran Anda!',
        'peringatan',
        0,  -- belum dibaca
        '2024-07-15 20:00:00'
    ),
    (
        1,
        NULL,
        '🎉 Selamat Datang di Acakehan!',
        'Halo Budi! Selamat datang di Acakehan. Mulai catat keuangan harianmu dan '
        'capai kebebasan finansial. Yuk buat anggaran pertamamu!',
        'info',
        1,
        '2024-06-01 08:05:00'
    );


-- ============================================================
--  BAGIAN F: Kueri Verifikasi — Jalankan untuk mengecek data
-- ============================================================

-- F1: Tampilkan semua pengguna
SELECT
    pengguna_id,
    nama_lengkap,
    email,
    peran_user,
    status_aktif,
    tanggal_daftar
FROM tbl_pengguna
ORDER BY pengguna_id;


-- F2: Hitung jumlah kategori global vs custom
SELECT
    CASE WHEN pengguna_id IS NULL THEN 'Global (Sistem)' ELSE 'Custom (Pengguna)' END AS jenis,
    tipe_kategori,
    COUNT(*) AS jumlah
FROM tbl_kategori
GROUP BY
    CASE WHEN pengguna_id IS NULL THEN 'Global (Sistem)' ELSE 'Custom (Pengguna)' END,
    tipe_kategori
ORDER BY jenis, tipe_kategori;


-- F3: Ringkasan transaksi Juli 2024 per pengguna
SELECT
    p.nama_lengkap,
    SUM(CASE WHEN t.tipe_transaksi = 'pemasukan'   THEN t.jumlah_nominal ELSE 0 END) AS total_pemasukan,
    SUM(CASE WHEN t.tipe_transaksi = 'pengeluaran' THEN t.jumlah_nominal ELSE 0 END) AS total_pengeluaran,
    SUM(CASE
            WHEN t.tipe_transaksi = 'pemasukan'   THEN  t.jumlah_nominal
            WHEN t.tipe_transaksi = 'pengeluaran' THEN -t.jumlah_nominal
        END)                                                                           AS saldo_bersih,
    COUNT(t.transaksi_id)                                                              AS jumlah_transaksi
FROM
    tbl_transaksi t
    JOIN tbl_pengguna p ON p.pengguna_id = t.pengguna_id
WHERE
    t.status_hapus        = 0
    AND MONTH(t.tanggal_transaksi) = 7    -- MySQL
    AND YEAR(t.tanggal_transaksi)  = 2024 -- MySQL
    -- PostgreSQL: EXTRACT(MONTH FROM t.tanggal_transaksi) = 7
    --             EXTRACT(YEAR  FROM t.tanggal_transaksi) = 2024
GROUP BY
    p.pengguna_id, p.nama_lengkap
ORDER BY
    p.pengguna_id;


-- F4: Status semua anggaran Budi bulan Juli 2024
SELECT
    k.nama_kategori,
    a.batas_maksimal,
    a.total_terpakai,
    ROUND((a.total_terpakai / a.batas_maksimal) * 100, 2)  AS persen_terpakai,
    a.batas_maksimal - a.total_terpakai                     AS sisa_anggaran,
    CASE
        WHEN (a.total_terpakai / a.batas_maksimal) >= 1.00 THEN '🔴 Kritis'
        WHEN (a.total_terpakai / a.batas_maksimal) >= 0.80 THEN '🟡 Peringatan'
        ELSE                                                     '🟢 Aman'
    END                                                     AS status,
    CASE a.status_notifikasi WHEN 1 THEN 'Sudah' ELSE 'Belum' END AS notif_terkirim
FROM
    tbl_anggaran  a
    JOIN tbl_kategori k ON k.kategori_id = a.kategori_id
WHERE
    a.pengguna_id   = 1
    AND a.periodes_bulan = 7
    AND a.periode_tahun  = 2024
ORDER BY
    persen_terpakai DESC;


-- F5: Pengeluaran per kategori Budi Juli 2024 (untuk pie chart)
SELECT
    k.nama_kategori,
    k.ikon_kategori,
    SUM(t.jumlah_nominal)                                         AS total_nominal,
    COUNT(t.transaksi_id)                                         AS jumlah_transaksi,
    ROUND(SUM(t.jumlah_nominal) /
        (SELECT SUM(jumlah_nominal) FROM tbl_transaksi
         WHERE pengguna_id = 1 AND tipe_transaksi = 'pengeluaran'
           AND status_hapus = 0
           AND MONTH(tanggal_transaksi) = 7
           AND YEAR(tanggal_transaksi) = 2024) * 100, 2)          AS persen_dari_total
FROM
    tbl_transaksi t
    JOIN tbl_kategori k ON k.kategori_id = t.kategori_id
WHERE
    t.pengguna_id    = 1
    AND t.tipe_transaksi  = 'pengeluaran'
    AND t.status_hapus    = 0
    AND MONTH(t.tanggal_transaksi) = 7
    AND YEAR(t.tanggal_transaksi)  = 2024
GROUP BY
    k.kategori_id, k.nama_kategori, k.ikon_kategori
ORDER BY
    total_nominal DESC;


-- F6: Notifikasi belum dibaca milik Budi
SELECT
    n.notifikasi_id,
    n.judul_pesan,
    n.tipe_notifikasi,
    n.status_baca,
    n.tanggal_kirim
FROM
    tbl_notifikasi n
WHERE
    n.pengguna_id = 1
    AND n.status_baca = 0
ORDER BY
    n.tanggal_kirim DESC;


-- F7: Uji Stored Procedure pencatatan transaksi baru (MySQL)
--     Mencatat pengeluaran Makanan Rp 50.000 untuk Budi
--     Ini akan memicu notifikasi karena anggaran sudah 85%
-- CALL sp_catat_transaksi(
--     1,           -- pengguna_id
--     8,           -- kategori_id (Makanan)
--     50000.00,    -- jumlah_nominal
--     'pengeluaran',
--     CURDATE(),
--     'Makan siang test SP',
--     @transaksi_id,
--     @persen,
--     @perlu_notif
-- );
-- SELECT @transaksi_id AS id_baru, @persen AS persen_anggaran, @perlu_notif AS perlu_notifikasi;
