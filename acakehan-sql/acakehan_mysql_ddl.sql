-- ============================================================
--  ACAKEHAN — Aplikasi Catatan Keuangan Harian
--  File    : acakehan_mysql_ddl.sql
--  DBMS    : MySQL 8.0+
--  Dibuat  : 2024
--  Deskripsi:
--    Skrip DDL lengkap untuk membuat database dan seluruh
--    tabel aplikasi Acakehan dari awal (dari nol).
--    Jalankan sekali saat setup awal proyek.
--
--  URUTAN EKSEKUSI (wajib diikuti karena ada Foreign Key):
--    1. tbl_pengguna
--    2. tbl_kategori
--    3. tbl_transaksi
--    4. tbl_anggaran
--    5. tbl_notifikasi
--    6. tbl_token_refresh  (opsional — untuk server-side logout)
--    7. tbl_log_aktivitas  (opsional — audit trail)
--    8. Data awal (INSERT kategori default)
-- ============================================================


-- ============================================================
--  LANGKAH 0: Buat & Pilih Database
-- ============================================================

-- Hapus database lama jika ada (HATI-HATI di produksi!)
-- Hapus tanda komentar di bawah HANYA jika ingin reset penuh:
-- DROP DATABASE IF EXISTS db_acakehan;

CREATE DATABASE IF NOT EXISTS db_acakehan
    CHARACTER SET  utf8mb4          -- Mendukung emoji & karakter Asia
    COLLATE        utf8mb4_unicode_ci;  -- Perbandingan string tidak case-sensitive

-- Gunakan database yang baru dibuat
USE db_acakehan;

-- Nonaktifkan foreign key check sementara selama proses pembuatan
-- agar urutan tabel tidak menimbulkan error dependensi
SET FOREIGN_KEY_CHECKS = 0;


-- ============================================================
--  TABEL 1: tbl_pengguna
--  Menyimpan data akun seluruh pengguna aplikasi Acakehan.
--  Tabel ini adalah "induk" dari hampir semua tabel lainnya.
-- ============================================================

DROP TABLE IF EXISTS tbl_pengguna;

CREATE TABLE tbl_pengguna (
    -- ── Primary Key ─────────────────────────────────────────
    pengguna_id        INT              NOT NULL AUTO_INCREMENT,

    -- ── Data Identitas ──────────────────────────────────────
    nama_lengkap       VARCHAR(100)     NOT NULL
                           COMMENT 'Nama lengkap pengguna',
    email              VARCHAR(150)     NOT NULL
                           COMMENT 'Email unik sebagai username login',
    password_hash      VARCHAR(255)     NOT NULL
                           COMMENT 'Hash bcrypt — JANGAN simpan password polos',
    nomor_telepon      VARCHAR(20)      NULL     DEFAULT NULL
                           COMMENT 'Nomor HP opsional',
    foto_profil        VARCHAR(255)     NULL     DEFAULT NULL
                           COMMENT 'Path atau URL foto profil',

    -- ── Status & Peran ──────────────────────────────────────
    status_aktif       TINYINT(1)       NOT NULL DEFAULT 1
                           COMMENT '1 = Aktif, 0 = Dinonaktifkan',
    peran_user         ENUM(
                           'pengguna',
                           'admin'
                       )                NOT NULL DEFAULT 'pengguna'
                           COMMENT 'Peran akun: pengguna biasa atau admin sistem',

    -- ── Timestamp ───────────────────────────────────────────
    tanggal_daftar     DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                           COMMENT 'Waktu pertama kali akun dibuat',
    terakhir_login     DATETIME         NULL     DEFAULT NULL
                           COMMENT 'Waktu terakhir pengguna berhasil login',
    diperbarui_pada    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP
                           COMMENT 'Otomatis diperbarui setiap ada perubahan data',

    -- ── Constraint ──────────────────────────────────────────
    CONSTRAINT pk_pengguna      PRIMARY KEY (pengguna_id),
    CONSTRAINT uq_pengguna_email UNIQUE KEY  (email)

) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Tabel akun pengguna aplikasi Acakehan';

-- Indeks tambahan untuk performa query
CREATE INDEX idx_pengguna_status     ON tbl_pengguna (status_aktif);
CREATE INDEX idx_pengguna_peran      ON tbl_pengguna (peran_user);
CREATE INDEX idx_pengguna_tgl_daftar ON tbl_pengguna (tanggal_daftar);


-- ============================================================
--  TABEL 2: tbl_kategori
--  Kategori transaksi keuangan.
--  pengguna_id = NULL  → kategori global (dibuat Admin, berlaku untuk semua)
--  pengguna_id = <id>  → kategori custom (dibuat oleh pengguna tertentu)
-- ============================================================

DROP TABLE IF EXISTS tbl_kategori;

CREATE TABLE tbl_kategori (
    -- ── Primary Key ─────────────────────────────────────────
    kategori_id        INT              NOT NULL AUTO_INCREMENT,

    -- ── Data Kategori ───────────────────────────────────────
    nama_kategori      VARCHAR(80)      NOT NULL
                           COMMENT 'Nama kategori, contoh: Makanan, Gaji, Transport',
    ikon_kategori      VARCHAR(100)     NULL     DEFAULT NULL
                           COMMENT 'Nama ikon atau kode emoji, contoh: icon-food, 🍔',
    tipe_kategori      ENUM(
                           'pemasukan',
                           'pengeluaran'
                       )                NOT NULL
                           COMMENT 'Jenis kategori: pemasukan atau pengeluaran',

    -- ── Kepemilikan ─────────────────────────────────────────
    -- NULL = kategori global milik sistem/admin
    pengguna_id        INT              NULL     DEFAULT NULL
                           COMMENT 'NULL = kategori global; <id> = kategori custom pengguna',

    -- ── Timestamp ───────────────────────────────────────────
    tanggal_dibuat     DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    diperbarui_pada    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,

    -- ── Constraint ──────────────────────────────────────────
    CONSTRAINT pk_kategori PRIMARY KEY (kategori_id),
    CONSTRAINT fk_kategori_pengguna
        FOREIGN KEY (pengguna_id)
        REFERENCES  tbl_pengguna (pengguna_id)
        ON DELETE   CASCADE     -- Hapus kategori jika pengguna dihapus
        ON UPDATE   CASCADE

) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Kategori transaksi: global (sistem) dan custom (pengguna)';

CREATE INDEX idx_kategori_pengguna ON tbl_kategori (pengguna_id);
CREATE INDEX idx_kategori_tipe     ON tbl_kategori (tipe_kategori);
-- Indeks gabungan untuk query: "ambil semua kategori pengeluaran milik user X"
CREATE INDEX idx_kategori_pengguna_tipe ON tbl_kategori (pengguna_id, tipe_kategori);


-- ============================================================
--  TABEL 3: tbl_transaksi
--  Inti aplikasi — menyimpan setiap catatan keuangan pengguna.
--  Menggunakan soft delete (status_hapus) agar data bisa diaudit.
-- ============================================================

DROP TABLE IF EXISTS tbl_transaksi;

CREATE TABLE tbl_transaksi (
    -- ── Primary Key ─────────────────────────────────────────
    transaksi_id       INT              NOT NULL AUTO_INCREMENT,

    -- ── Foreign Keys ────────────────────────────────────────
    pengguna_id        INT              NOT NULL
                           COMMENT 'Pemilik transaksi ini',
    kategori_id        INT              NOT NULL
                           COMMENT 'Kategori transaksi yang dipilih',

    -- ── Data Transaksi ──────────────────────────────────────
    jumlah_nominal     DECIMAL(15, 2)   NOT NULL
                           COMMENT 'Nilai uang. DECIMAL(15,2) = maks 999 triliun',
    tipe_transaksi     ENUM(
                           'pemasukan',
                           'pengeluaran'
                       )                NOT NULL
                           COMMENT 'Jenis aliran uang',
    tanggal_transaksi  DATE             NOT NULL
                           COMMENT 'Tanggal kejadian transaksi (bukan tanggal dicatat)',
    catatan_tambahan   TEXT             NULL     DEFAULT NULL
                           COMMENT 'Deskripsi atau keterangan bebas dari pengguna',
    bukti_struk        VARCHAR(255)     NULL     DEFAULT NULL
                           COMMENT 'Path atau URL foto struk / bukti transaksi',

    -- ── Metadata ────────────────────────────────────────────
    tanggal_dicatat    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                           COMMENT 'Waktu data dimasukkan ke sistem (bisa berbeda dengan tanggal_transaksi)',
    diperbarui_pada    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,
    status_hapus       TINYINT(1)       NOT NULL DEFAULT 0
                           COMMENT 'Soft delete: 0 = aktif, 1 = terhapus',

    -- ── Constraint ──────────────────────────────────────────
    CONSTRAINT pk_transaksi PRIMARY KEY (transaksi_id),

    CONSTRAINT fk_transaksi_pengguna
        FOREIGN KEY (pengguna_id)
        REFERENCES  tbl_pengguna (pengguna_id)
        ON DELETE   CASCADE
        ON UPDATE   CASCADE,

    CONSTRAINT fk_transaksi_kategori
        FOREIGN KEY (kategori_id)
        REFERENCES  tbl_kategori (kategori_id)
        ON DELETE   RESTRICT    -- Larang hapus kategori jika masih ada transaksinya
        ON UPDATE   CASCADE,

    -- Validasi: nominal harus selalu positif
    CONSTRAINT chk_transaksi_nominal_positif
        CHECK (jumlah_nominal > 0)

) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Catatan transaksi keuangan harian pengguna';

-- Indeks kritis untuk performa query dashboard & laporan
CREATE INDEX idx_transaksi_pengguna          ON tbl_transaksi (pengguna_id);
CREATE INDEX idx_transaksi_kategori          ON tbl_transaksi (kategori_id);
CREATE INDEX idx_transaksi_tanggal           ON tbl_transaksi (tanggal_transaksi);
CREATE INDEX idx_transaksi_tipe              ON tbl_transaksi (tipe_transaksi);
CREATE INDEX idx_transaksi_status_hapus      ON tbl_transaksi (status_hapus);

-- Indeks gabungan: query paling umum adalah "transaksi aktif milik user X di bulan Y"
CREATE INDEX idx_transaksi_pengguna_tanggal
    ON tbl_transaksi (pengguna_id, tanggal_transaksi, status_hapus);

-- Indeks gabungan: filter berdasarkan tipe + pengguna (untuk ringkasan pemasukan/pengeluaran)
CREATE INDEX idx_transaksi_pengguna_tipe
    ON tbl_transaksi (pengguna_id, tipe_transaksi, status_hapus);


-- ============================================================
--  TABEL 4: tbl_anggaran
--  Batas pengeluaran maksimal per kategori per bulan.
--  UNIQUE constraint mencegah satu pengguna membuat dua anggaran
--  untuk kategori dan periode yang sama.
-- ============================================================

DROP TABLE IF EXISTS tbl_anggaran;

CREATE TABLE tbl_anggaran (
    -- ── Primary Key ─────────────────────────────────────────
    anggaran_id        INT              NOT NULL AUTO_INCREMENT,

    -- ── Foreign Keys ────────────────────────────────────────
    pengguna_id        INT              NOT NULL
                           COMMENT 'Pemilik anggaran ini',
    kategori_id        INT              NOT NULL
                           COMMENT 'Kategori yang dianggarkan (harus tipe pengeluaran)',

    -- ── Data Anggaran ───────────────────────────────────────
    batas_maksimal     DECIMAL(15, 2)   NOT NULL
                           COMMENT 'Batas pengeluaran maksimal untuk kategori & periode ini',
    periodes_bulan     TINYINT UNSIGNED NOT NULL
                           COMMENT 'Bulan berlaku: 1 (Januari) s/d 12 (Desember)',
    periode_tahun      SMALLINT UNSIGNED NOT NULL
                           COMMENT 'Tahun berlaku, contoh: 2024',

    -- ── Tracking ────────────────────────────────────────────
    -- Kolom ini adalah denormalisasi yang disengaja untuk performa:
    -- nilainya diupdate setiap kali ada transaksi pengeluaran baru,
    -- sehingga tidak perlu query SUM() setiap kali ingin tahu sisa anggaran.
    total_terpakai     DECIMAL(15, 2)   NOT NULL DEFAULT 0.00
                           COMMENT 'Akumulasi pengeluaran bulan ini. Diupdate oleh backend.',
    status_notifikasi  TINYINT(1)       NOT NULL DEFAULT 0
                           COMMENT '0 = notif 80% belum terkirim; 1 = sudah terkirim (anti-spam)',

    -- ── Timestamp ───────────────────────────────────────────
    tanggal_dibuat     DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    diperbarui_pada    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,

    -- ── Constraint ──────────────────────────────────────────
    CONSTRAINT pk_anggaran PRIMARY KEY (anggaran_id),

    CONSTRAINT fk_anggaran_pengguna
        FOREIGN KEY (pengguna_id)
        REFERENCES  tbl_pengguna (pengguna_id)
        ON DELETE   CASCADE
        ON UPDATE   CASCADE,

    CONSTRAINT fk_anggaran_kategori
        FOREIGN KEY (kategori_id)
        REFERENCES  tbl_kategori (kategori_id)
        ON DELETE   RESTRICT
        ON UPDATE   CASCADE,

    -- Satu pengguna hanya boleh punya 1 anggaran per kategori per periode
    CONSTRAINT uq_anggaran_per_periode
        UNIQUE KEY (pengguna_id, kategori_id, periodes_bulan, periode_tahun),

    -- Validasi nilai
    CONSTRAINT chk_anggaran_batas_positif
        CHECK (batas_maksimal > 0),
    CONSTRAINT chk_anggaran_total_tidak_negatif
        CHECK (total_terpakai >= 0),
    CONSTRAINT chk_anggaran_bulan_valid
        CHECK (periodes_bulan BETWEEN 1 AND 12),
    CONSTRAINT chk_anggaran_tahun_valid
        CHECK (periode_tahun BETWEEN 2000 AND 2100)

) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Anggaran bulanan pengguna per kategori pengeluaran';

CREATE INDEX idx_anggaran_pengguna         ON tbl_anggaran (pengguna_id);
CREATE INDEX idx_anggaran_kategori         ON tbl_anggaran (kategori_id);
-- Indeks gabungan untuk query dashboard: "ambil semua anggaran user X bulan Y tahun Z"
CREATE INDEX idx_anggaran_pengguna_periode
    ON tbl_anggaran (pengguna_id, periodes_bulan, periode_tahun);


-- ============================================================
--  TABEL 5: tbl_notifikasi
--  Riwayat semua notifikasi yang dikirim ke pengguna.
--  Digunakan untuk badge "belum dibaca" dan riwayat notifikasi.
-- ============================================================

DROP TABLE IF EXISTS tbl_notifikasi;

CREATE TABLE tbl_notifikasi (
    -- ── Primary Key ─────────────────────────────────────────
    notifikasi_id      INT              NOT NULL AUTO_INCREMENT,

    -- ── Foreign Keys ────────────────────────────────────────
    pengguna_id        INT              NOT NULL
                           COMMENT 'Pengguna penerima notifikasi',
    anggaran_id        INT              NULL     DEFAULT NULL
                           COMMENT 'Anggaran terkait (NULL jika notifikasi bukan soal anggaran)',

    -- ── Konten ──────────────────────────────────────────────
    judul_pesan        VARCHAR(150)     NOT NULL
                           COMMENT 'Judul singkat notifikasi',
    isi_pesan          TEXT             NOT NULL
                           COMMENT 'Isi lengkap pesan notifikasi',
    tipe_notifikasi    ENUM(
                           'peringatan',
                           'info',
                           'sukses'
                       )                NOT NULL DEFAULT 'info'
                           COMMENT 'Jenis: peringatan (merah), info (biru), sukses (hijau)',

    -- ── Status ──────────────────────────────────────────────
    status_baca        TINYINT(1)       NOT NULL DEFAULT 0
                           COMMENT '0 = belum dibaca, 1 = sudah dibaca',

    -- ── Timestamp ───────────────────────────────────────────
    tanggal_kirim      DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                           COMMENT 'Waktu notifikasi dibuat dan dikirim',

    -- ── Constraint ──────────────────────────────────────────
    CONSTRAINT pk_notifikasi PRIMARY KEY (notifikasi_id),

    CONSTRAINT fk_notifikasi_pengguna
        FOREIGN KEY (pengguna_id)
        REFERENCES  tbl_pengguna (pengguna_id)
        ON DELETE   CASCADE
        ON UPDATE   CASCADE,

    CONSTRAINT fk_notifikasi_anggaran
        FOREIGN KEY (anggaran_id)
        REFERENCES  tbl_anggaran (anggaran_id)
        ON DELETE   SET NULL    -- Jika anggaran dihapus, notifikasi tetap ada tapi anggaran_id = NULL
        ON UPDATE   CASCADE

) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Riwayat notifikasi yang dikirim ke pengguna';

CREATE INDEX idx_notifikasi_pengguna      ON tbl_notifikasi (pengguna_id);
CREATE INDEX idx_notifikasi_anggaran      ON tbl_notifikasi (anggaran_id);
CREATE INDEX idx_notifikasi_status_baca   ON tbl_notifikasi (status_baca);
-- Indeks untuk query badge: "berapa notifikasi belum dibaca milik user X?"
CREATE INDEX idx_notifikasi_pengguna_baca
    ON tbl_notifikasi (pengguna_id, status_baca);
-- Indeks untuk mengurutkan notifikasi terbaru
CREATE INDEX idx_notifikasi_tgl_kirim     ON tbl_notifikasi (tanggal_kirim DESC);


-- ============================================================
--  TABEL 6: tbl_token_refresh  [OPSIONAL]
--  Untuk implementasi server-side token invalidation.
--  Jika pengguna logout, token refresh-nya masuk ke blacklist.
--  Berguna untuk mencegah penyalahgunaan token yang dicuri.
-- ============================================================

DROP TABLE IF EXISTS tbl_token_refresh;

CREATE TABLE tbl_token_refresh (
    token_id           INT              NOT NULL AUTO_INCREMENT,
    pengguna_id        INT              NOT NULL,

    -- Hash dari token refresh (bukan token mentah, untuk keamanan)
    token_hash         VARCHAR(255)     NOT NULL
                           COMMENT 'SHA-256 hash dari token refresh',
    perangkat_info     VARCHAR(255)     NULL     DEFAULT NULL
                           COMMENT 'Info perangkat: User-Agent, platform, dll.',

    -- Status token
    digunakan          TINYINT(1)       NOT NULL DEFAULT 0
                           COMMENT '0 = aktif, 1 = sudah digunakan/dicabut',

    -- Waktu
    tanggal_terbit     DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tanggal_kadaluarsa DATETIME         NOT NULL
                           COMMENT 'Waktu token tidak bisa digunakan lagi',
    tanggal_dicabut    DATETIME         NULL     DEFAULT NULL
                           COMMENT 'Waktu token dicabut (logout)',

    CONSTRAINT pk_token_refresh  PRIMARY KEY (token_id),
    CONSTRAINT uq_token_hash     UNIQUE KEY  (token_hash),

    CONSTRAINT fk_token_pengguna
        FOREIGN KEY (pengguna_id)
        REFERENCES  tbl_pengguna (pengguna_id)
        ON DELETE   CASCADE
        ON UPDATE   CASCADE

) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Blacklist token refresh untuk server-side logout (opsional)';

CREATE INDEX idx_token_pengguna    ON tbl_token_refresh (pengguna_id);
CREATE INDEX idx_token_digunakan   ON tbl_token_refresh (digunakan);
CREATE INDEX idx_token_kadaluarsa  ON tbl_token_refresh (tanggal_kadaluarsa);


-- ============================================================
--  TABEL 7: tbl_log_aktivitas  [OPSIONAL]
--  Audit trail — mencatat semua aksi penting pengguna.
--  Berguna untuk keamanan, debugging, dan analisis perilaku.
-- ============================================================

DROP TABLE IF EXISTS tbl_log_aktivitas;

CREATE TABLE tbl_log_aktivitas (
    log_id             BIGINT           NOT NULL AUTO_INCREMENT
                           COMMENT 'BIGINT karena volume data bisa sangat besar',
    pengguna_id        INT              NULL     DEFAULT NULL
                           COMMENT 'NULL jika aksi dilakukan sebelum login',

    -- Detail aktivitas
    jenis_aksi         VARCHAR(50)      NOT NULL
                           COMMENT 'Contoh: LOGIN, REGISTRASI, TAMBAH_TRANSAKSI, HAPUS_ANGGARAN',
    deskripsi          VARCHAR(255)     NULL     DEFAULT NULL
                           COMMENT 'Keterangan tambahan tentang aksi',
    tabel_terdampak    VARCHAR(50)      NULL     DEFAULT NULL
                           COMMENT 'Nama tabel yang terpengaruh, contoh: tbl_transaksi',
    id_data_terdampak  INT              NULL     DEFAULT NULL
                           COMMENT 'ID record yang terpengaruh',

    -- Informasi teknis
    alamat_ip          VARCHAR(45)      NULL     DEFAULT NULL
                           COMMENT 'IPv4 atau IPv6 (max 45 karakter untuk IPv6)',
    user_agent         VARCHAR(500)     NULL     DEFAULT NULL
                           COMMENT 'Browser atau aplikasi mobile yang digunakan',
    status_aksi        ENUM(
                           'sukses',
                           'gagal',
                           'ditolak'
                       )                NOT NULL DEFAULT 'sukses',

    -- Timestamp
    waktu_aksi         DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_log_aktivitas PRIMARY KEY (log_id),

    CONSTRAINT fk_log_pengguna
        FOREIGN KEY (pengguna_id)
        REFERENCES  tbl_pengguna (pengguna_id)
        ON DELETE   SET NULL    -- Log tetap ada meskipun pengguna dihapus
        ON UPDATE   CASCADE

) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Audit trail semua aktivitas penting dalam sistem';

CREATE INDEX idx_log_pengguna    ON tbl_log_aktivitas (pengguna_id);
CREATE INDEX idx_log_jenis_aksi  ON tbl_log_aktivitas (jenis_aksi);
CREATE INDEX idx_log_waktu       ON tbl_log_aktivitas (waktu_aksi);
CREATE INDEX idx_log_status      ON tbl_log_aktivitas (status_aksi);


-- ============================================================
--  LANGKAH AKHIR PEMBUATAN TABEL:
--  Aktifkan kembali foreign key check
-- ============================================================

SET FOREIGN_KEY_CHECKS = 1;


-- ============================================================
--  DATA AWAL (SEED DATA)
--  Kategori default sistem — tersedia untuk semua pengguna.
--  pengguna_id = NULL menandakan ini milik sistem/admin.
-- ============================================================

INSERT INTO tbl_kategori
    (nama_kategori, ikon_kategori, tipe_kategori, pengguna_id)
VALUES
    -- ── Kategori PEMASUKAN ──────────────────────────────────
    ('Gaji',                'icon-salary',      'pemasukan',   NULL),
    ('Bonus',               'icon-bonus',       'pemasukan',   NULL),
    ('Freelance',           'icon-freelance',   'pemasukan',   NULL),
    ('Investasi',           'icon-invest',      'pemasukan',   NULL),
    ('Bisnis',              'icon-business',    'pemasukan',   NULL),
    ('Hadiah',              'icon-gift',        'pemasukan',   NULL),
    ('Lainnya (Masuk)',     'icon-other-in',    'pemasukan',   NULL),

    -- ── Kategori PENGELUARAN ────────────────────────────────
    ('Makanan & Minuman',   'icon-food',        'pengeluaran', NULL),
    ('Transportasi',        'icon-transport',   'pengeluaran', NULL),
    ('Belanja',             'icon-shopping',    'pengeluaran', NULL),
    ('Tagihan & Utilitas',  'icon-bill',        'pengeluaran', NULL),
    ('Kesehatan',           'icon-health',      'pengeluaran', NULL),
    ('Pendidikan',          'icon-education',   'pengeluaran', NULL),
    ('Hiburan',             'icon-entertain',   'pengeluaran', NULL),
    ('Olahraga',            'icon-sport',       'pengeluaran', NULL),
    ('Perawatan Diri',      'icon-care',        'pengeluaran', NULL),
    ('Cicilan / Utang',     'icon-debt',        'pengeluaran', NULL),
    ('Tabungan',            'icon-saving',      'pengeluaran', NULL),
    ('Sosial & Donasi',     'icon-social',      'pengeluaran', NULL),
    ('Lainnya (Keluar)',    'icon-other-out',   'pengeluaran', NULL);


-- ============================================================
--  VIEW: v_ringkasan_transaksi_bulanan
--  View siap pakai untuk menghitung pemasukan dan pengeluaran
--  per pengguna per bulan — bisa langsung dipakai di query backend.
-- ============================================================

CREATE OR REPLACE VIEW v_ringkasan_transaksi_bulanan AS
SELECT
    t.pengguna_id,
    YEAR(t.tanggal_transaksi)                           AS tahun,
    MONTH(t.tanggal_transaksi)                          AS bulan,
    SUM(CASE WHEN t.tipe_transaksi = 'pemasukan'
             THEN t.jumlah_nominal ELSE 0 END)          AS total_pemasukan,
    SUM(CASE WHEN t.tipe_transaksi = 'pengeluaran'
             THEN t.jumlah_nominal ELSE 0 END)          AS total_pengeluaran,
    SUM(CASE WHEN t.tipe_transaksi = 'pemasukan'
             THEN t.jumlah_nominal
             ELSE -t.jumlah_nominal END)                AS saldo_bersih,
    COUNT(t.transaksi_id)                               AS jumlah_transaksi
FROM
    tbl_transaksi t
WHERE
    t.status_hapus = 0
GROUP BY
    t.pengguna_id,
    YEAR(t.tanggal_transaksi),
    MONTH(t.tanggal_transaksi);


-- ============================================================
--  VIEW: v_status_anggaran_aktif
--  View untuk menampilkan status semua anggaran aktif pengguna
--  beserta persentase pemakaian dan sisa anggaran.
-- ============================================================

CREATE OR REPLACE VIEW v_status_anggaran_aktif AS
SELECT
    a.anggaran_id,
    a.pengguna_id,
    k.nama_kategori,
    k.ikon_kategori,
    a.batas_maksimal,
    a.total_terpakai,
    ROUND(
        (a.total_terpakai / a.batas_maksimal) * 100, 2
    )                                                   AS persen_terpakai,
    GREATEST(0, a.batas_maksimal - a.total_terpakai)    AS sisa_anggaran,
    a.periodes_bulan,
    a.periode_tahun,
    a.status_notifikasi,
    CASE
        WHEN (a.total_terpakai / a.batas_maksimal) >= 1.00 THEN 'kritis'
        WHEN (a.total_terpakai / a.batas_maksimal) >= 0.80 THEN 'peringatan'
        ELSE                                                     'aman'
    END                                                 AS label_status
FROM
    tbl_anggaran  a
    JOIN tbl_kategori k ON k.kategori_id = a.kategori_id;


-- ============================================================
--  STORED PROCEDURE: sp_catat_transaksi
--  Prosedur tersimpan untuk mencatat transaksi sekaligus
--  memperbarui total_terpakai di tbl_anggaran secara atomik
--  dalam satu transaksi database (tidak bisa setengah-setengah).
-- ============================================================

DELIMITER //

CREATE PROCEDURE sp_catat_transaksi (
    IN  p_pengguna_id        INT,
    IN  p_kategori_id        INT,
    IN  p_jumlah_nominal     DECIMAL(15,2),
    IN  p_tipe_transaksi     ENUM('pemasukan','pengeluaran'),
    IN  p_tanggal_transaksi  DATE,
    IN  p_catatan_tambahan   TEXT,
    OUT p_transaksi_id_baru  INT,
    OUT p_persen_anggaran    DECIMAL(5,2),
    OUT p_perlu_notifikasi   TINYINT
)
sp_label: BEGIN

    -- Deklarasi variabel lokal
    DECLARE v_anggaran_id        INT     DEFAULT NULL;
    DECLARE v_batas_maksimal     DECIMAL(15,2) DEFAULT 0;
    DECLARE v_total_setelah      DECIMAL(15,2) DEFAULT 0;
    DECLARE v_status_notif       TINYINT DEFAULT 0;
    DECLARE v_persen             DECIMAL(5,2)  DEFAULT 0;
    DECLARE v_galat_terjadi      TINYINT DEFAULT 0;

    -- Handler untuk error: rollback dan tandai ada galat
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        SET v_galat_terjadi = 1;
        ROLLBACK;
    END;

    -- Inisialisasi nilai output
    SET p_transaksi_id_baru = NULL;
    SET p_persen_anggaran   = 0;
    SET p_perlu_notifikasi  = 0;

    START TRANSACTION;

    -- ── Langkah 1: Masukkan transaksi baru ────────────────────
    INSERT INTO tbl_transaksi (
        pengguna_id, kategori_id, jumlah_nominal,
        tipe_transaksi, tanggal_transaksi, catatan_tambahan
    ) VALUES (
        p_pengguna_id, p_kategori_id, p_jumlah_nominal,
        p_tipe_transaksi, p_tanggal_transaksi, p_catatan_tambahan
    );

    SET p_transaksi_id_baru = LAST_INSERT_ID();

    -- ── Langkah 2: Perbarui anggaran (HANYA untuk pengeluaran) ─
    IF p_tipe_transaksi = 'pengeluaran' THEN

        -- Cari anggaran yang relevan (pengguna + kategori + periode bulan ini)
        SELECT anggaran_id, batas_maksimal, total_terpakai, status_notifikasi
        INTO   v_anggaran_id, v_batas_maksimal, v_total_setelah, v_status_notif
        FROM   tbl_anggaran
        WHERE  pengguna_id   = p_pengguna_id
          AND  kategori_id   = p_kategori_id
          AND  periodes_bulan = MONTH(p_tanggal_transaksi)
          AND  periode_tahun  = YEAR(p_tanggal_transaksi)
        LIMIT 1
        FOR UPDATE; -- Kunci baris agar tidak ada race condition

        -- Jika anggaran ditemukan, perbarui total terpakai
        IF v_anggaran_id IS NOT NULL THEN

            SET v_total_setelah = v_total_setelah + p_jumlah_nominal;

            -- Hitung persentase baru
            SET v_persen = ROUND((v_total_setelah / v_batas_maksimal) * 100, 2);

            -- Perbarui total di database
            UPDATE tbl_anggaran
            SET    total_terpakai = v_total_setelah
            WHERE  anggaran_id    = v_anggaran_id;

            SET p_persen_anggaran = v_persen;

            -- Tandai perlu notifikasi jika >= 80% DAN belum pernah notif bulan ini
            IF v_persen >= 80.00 AND v_status_notif = 0 THEN
                SET p_perlu_notifikasi = 1;

                -- Tandai status notifikasi sudah terkirim (anti-spam)
                UPDATE tbl_anggaran
                SET    status_notifikasi = 1
                WHERE  anggaran_id = v_anggaran_id;

            END IF;

        END IF;
    END IF;

    -- ── Langkah 3: Commit jika tidak ada galat ─────────────────
    IF v_galat_terjadi = 0 THEN
        COMMIT;
    ELSE
        SET p_transaksi_id_baru = NULL; -- Beri tahu caller bahwa transaksi gagal
    END IF;

END //

DELIMITER ;


-- ============================================================
--  TRIGGER: trg_reset_notif_awal_bulan
--  Secara otomatis mereset status_notifikasi semua anggaran
--  ke 0 (nol) pada awal bulan baru, agar notifikasi 80% bisa
--  dikirim lagi di bulan berikutnya.
--
--  Trigger ini aktif setiap kali baris baru dimasukkan ke
--  tbl_transaksi — ia memeriksa apakah bulan sudah berganti
--  dibandingkan anggaran yang ada.
-- ============================================================

DELIMITER //

CREATE TRIGGER trg_reset_notif_awal_bulan
AFTER INSERT ON tbl_transaksi
FOR EACH ROW
BEGIN
    -- Reset status notifikasi untuk anggaran yang periodenya
    -- berbeda dengan bulan transaksi yang baru saja dicatat.
    -- Ini memastikan notifikasi bisa dikirim ulang di bulan baru.
    UPDATE tbl_anggaran
    SET    status_notifikasi = 0
    WHERE  pengguna_id       = NEW.pengguna_id
      AND  status_notifikasi  = 1
      AND  (periodes_bulan   != MONTH(NEW.tanggal_transaksi)
         OR periode_tahun    != YEAR(NEW.tanggal_transaksi));
END //

DELIMITER ;


-- ============================================================
--  VERIFIKASI AKHIR
--  Tampilkan semua tabel yang sudah dibuat beserta jumlah baris.
-- ============================================================

SELECT
    TABLE_NAME          AS 'Nama Tabel',
    TABLE_ROWS          AS 'Estimasi Baris',
    TABLE_COMMENT       AS 'Keterangan',
    CREATE_TIME         AS 'Waktu Dibuat'
FROM
    information_schema.TABLES
WHERE
    TABLE_SCHEMA = 'db_acakehan'
ORDER BY
    TABLE_NAME;


-- ============================================================
--  SELESAI
--  Database db_acakehan berhasil dibuat dengan:
--    ✓ 7 tabel (5 inti + 2 opsional)
--    ✓ Foreign Key lengkap dengan ON DELETE / ON UPDATE
--    ✓ 20+ indeks untuk performa optimal
--    ✓ CHECK constraint untuk validasi data
--    ✓ 2 VIEW siap pakai
--    ✓ 1 Stored Procedure atomik
--    ✓ 1 Trigger otomatis
--    ✓ 21 data kategori default
-- ============================================================
