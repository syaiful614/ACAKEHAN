-- ============================================================
--  ACAKEHAN — Aplikasi Catatan Keuangan Harian
--  File    : acakehan_postgresql_ddl.sql
--  DBMS    : PostgreSQL 14+
--  Dibuat  : 2024
--  Deskripsi:
--    Skrip DDL lengkap versi PostgreSQL. Perbedaan utama
--    dari versi MySQL:
--      • SERIAL / GENERATED ALWAYS AS IDENTITY  → ganti AUTO_INCREMENT
--      • BOOLEAN                                 → ganti TINYINT(1)
--      • TEXT bebas panjang                      → ganti VARCHAR besar
--      • TIMESTAMPTZ (timezone-aware)            → ganti DATETIME
--      • ENUM dibuat sebagai TYPE terpisah
--      • Trigger ditulis sebagai FUNCTION + TRIGGER
--      • Stored Procedure ditulis sebagai FUNCTION (PL/pgSQL)
--
--  URUTAN EKSEKUSI:
--    1. Buat database & schema
--    2. Buat TYPE enum
--    3. Tabel (urutan sesuai dependensi FK)
--    4. Indeks
--    5. View
--    6. Function & Trigger
--    7. Seed data
-- ============================================================


-- ============================================================
--  LANGKAH 0: Buat Database & Schema
-- ============================================================

-- Jalankan perintah ini sebagai superuser PostgreSQL dari luar psql:
--   createdb -U postgres db_acakehan
-- Atau dari dalam psql:
--   CREATE DATABASE db_acakehan
--       WITH ENCODING='UTF8'
--            LC_COLLATE='id_ID.UTF-8'
--            LC_CTYPE='id_ID.UTF-8'
--            TEMPLATE=template0;

-- Setelah terhubung ke db_acakehan, jalankan sisa skrip ini:
-- \c db_acakehan

-- Buat schema khusus aplikasi (memisahkan dari public schema)
CREATE SCHEMA IF NOT EXISTS acakehan;

-- Jadikan schema acakehan sebagai default untuk sesi ini
SET search_path TO acakehan, public;

-- Ekstensi yang dibutuhkan
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  -- Untuk UUID jika diperlukan nanti
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- Untuk fungsi kriptografi tambahan


-- ============================================================
--  LANGKAH 1: Buat TYPE ENUM
--  Di PostgreSQL, ENUM dibuat sebagai tipe data tersendiri
--  dan bisa digunakan ulang di banyak tabel/kolom.
-- ============================================================

-- Hapus type lama jika ada (urutan DROP harus terbalik dari pembuatan)
DROP TYPE IF EXISTS tipe_kategori_enum    CASCADE;
DROP TYPE IF EXISTS peran_user_enum       CASCADE;
DROP TYPE IF EXISTS tipe_notifikasi_enum  CASCADE;
DROP TYPE IF EXISTS status_aksi_enum      CASCADE;

CREATE TYPE tipe_kategori_enum   AS ENUM ('pemasukan',  'pengeluaran');
CREATE TYPE peran_user_enum      AS ENUM ('pengguna',   'admin');
CREATE TYPE tipe_notifikasi_enum AS ENUM ('peringatan', 'info', 'sukses');
CREATE TYPE status_aksi_enum     AS ENUM ('sukses',     'gagal', 'ditolak');


-- ============================================================
--  TABEL 1: pengguna
-- ============================================================

DROP TABLE IF EXISTS acakehan.pengguna CASCADE;

CREATE TABLE acakehan.pengguna (
    -- ── Primary Key ─────────────────────────────────────────
    pengguna_id        INTEGER          GENERATED ALWAYS AS IDENTITY
                                        (START WITH 1 INCREMENT BY 1),

    -- ── Data Identitas ──────────────────────────────────────
    nama_lengkap       VARCHAR(100)     NOT NULL,
    email              VARCHAR(150)     NOT NULL,
    password_hash      VARCHAR(255)     NOT NULL,
    nomor_telepon      VARCHAR(20)      NULL,
    foto_profil        VARCHAR(255)     NULL,

    -- ── Status & Peran ──────────────────────────────────────
    status_aktif       BOOLEAN          NOT NULL DEFAULT TRUE,
    peran_user         peran_user_enum  NOT NULL DEFAULT 'pengguna',

    -- ── Timestamp (TIMESTAMPTZ = menyimpan timezone) ─────────
    tanggal_daftar     TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    terakhir_login     TIMESTAMPTZ      NULL,
    diperbarui_pada    TIMESTAMPTZ      NOT NULL DEFAULT NOW(),

    -- ── Constraint ──────────────────────────────────────────
    CONSTRAINT pk_pengguna        PRIMARY KEY (pengguna_id),
    CONSTRAINT uq_pengguna_email  UNIQUE      (email),
    CONSTRAINT chk_email_format
        CHECK (email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$')
);

COMMENT ON TABLE  acakehan.pengguna               IS 'Akun pengguna aplikasi Acakehan';
COMMENT ON COLUMN acakehan.pengguna.pengguna_id   IS 'Primary key — ID unik pengguna';
COMMENT ON COLUMN acakehan.pengguna.email         IS 'Email unik sebagai username login';
COMMENT ON COLUMN acakehan.pengguna.password_hash IS 'Hash bcrypt — JANGAN simpan password polos';
COMMENT ON COLUMN acakehan.pengguna.status_aktif  IS 'TRUE = aktif, FALSE = dinonaktifkan';
COMMENT ON COLUMN acakehan.pengguna.peran_user    IS 'Peran: pengguna biasa atau admin sistem';

-- Indeks
CREATE INDEX idx_pengguna_email       ON acakehan.pengguna (email);
CREATE INDEX idx_pengguna_status      ON acakehan.pengguna (status_aktif);
CREATE INDEX idx_pengguna_peran       ON acakehan.pengguna (peran_user);
CREATE INDEX idx_pengguna_tgl_daftar  ON acakehan.pengguna (tanggal_daftar DESC);


-- ============================================================
--  TABEL 2: kategori
-- ============================================================

DROP TABLE IF EXISTS acakehan.kategori CASCADE;

CREATE TABLE acakehan.kategori (
    kategori_id        INTEGER               GENERATED ALWAYS AS IDENTITY
                                             (START WITH 1 INCREMENT BY 1),
    nama_kategori      VARCHAR(80)           NOT NULL,
    ikon_kategori      VARCHAR(100)          NULL,
    tipe_kategori      tipe_kategori_enum    NOT NULL,

    -- NULL = kategori global (milik sistem/admin)
    pengguna_id        INTEGER               NULL,
    tanggal_dibuat     TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
    diperbarui_pada    TIMESTAMPTZ           NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_kategori PRIMARY KEY (kategori_id),

    CONSTRAINT fk_kategori_pengguna
        FOREIGN KEY (pengguna_id)
        REFERENCES  acakehan.pengguna (pengguna_id)
        ON DELETE   CASCADE
        ON UPDATE   CASCADE
);

COMMENT ON TABLE  acakehan.kategori             IS 'Kategori transaksi: global (sistem) dan custom (pengguna)';
COMMENT ON COLUMN acakehan.kategori.pengguna_id IS 'NULL = kategori global; isi = kategori custom pengguna';

CREATE INDEX idx_kategori_pengguna      ON acakehan.kategori (pengguna_id);
CREATE INDEX idx_kategori_tipe          ON acakehan.kategori (tipe_kategori);
CREATE INDEX idx_kategori_pengguna_tipe ON acakehan.kategori (pengguna_id, tipe_kategori);


-- ============================================================
--  TABEL 3: transaksi
-- ============================================================

DROP TABLE IF EXISTS acakehan.transaksi CASCADE;

CREATE TABLE acakehan.transaksi (
    transaksi_id       INTEGER              GENERATED ALWAYS AS IDENTITY
                                            (START WITH 1 INCREMENT BY 1),
    pengguna_id        INTEGER              NOT NULL,
    kategori_id        INTEGER              NOT NULL,

    jumlah_nominal     NUMERIC(15, 2)       NOT NULL,
    tipe_transaksi     tipe_kategori_enum   NOT NULL,
    tanggal_transaksi  DATE                 NOT NULL,
    catatan_tambahan   TEXT                 NULL,
    bukti_struk        VARCHAR(255)         NULL,

    tanggal_dicatat    TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
    diperbarui_pada    TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
    status_hapus       BOOLEAN              NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_transaksi PRIMARY KEY (transaksi_id),

    CONSTRAINT fk_transaksi_pengguna
        FOREIGN KEY (pengguna_id)
        REFERENCES  acakehan.pengguna (pengguna_id)
        ON DELETE   CASCADE
        ON UPDATE   CASCADE,

    CONSTRAINT fk_transaksi_kategori
        FOREIGN KEY (kategori_id)
        REFERENCES  acakehan.kategori (kategori_id)
        ON DELETE   RESTRICT
        ON UPDATE   CASCADE,

    CONSTRAINT chk_transaksi_nominal_positif
        CHECK (jumlah_nominal > 0),

    CONSTRAINT chk_transaksi_tanggal_tidak_masa_depan
        CHECK (tanggal_transaksi <= CURRENT_DATE + INTERVAL '1 day')
);

COMMENT ON TABLE  acakehan.transaksi                  IS 'Catatan transaksi keuangan harian pengguna';
COMMENT ON COLUMN acakehan.transaksi.tanggal_transaksi IS 'Tanggal kejadian (bisa berbeda dengan tanggal_dicatat)';
COMMENT ON COLUMN acakehan.transaksi.status_hapus      IS 'Soft delete: FALSE=aktif, TRUE=terhapus';

CREATE INDEX idx_transaksi_pengguna          ON acakehan.transaksi (pengguna_id);
CREATE INDEX idx_transaksi_kategori          ON acakehan.transaksi (kategori_id);
CREATE INDEX idx_transaksi_tanggal           ON acakehan.transaksi (tanggal_transaksi DESC);
CREATE INDEX idx_transaksi_tipe              ON acakehan.transaksi (tipe_transaksi);
CREATE INDEX idx_transaksi_status_hapus      ON acakehan.transaksi (status_hapus);
-- Indeks gabungan untuk query paling umum
CREATE INDEX idx_transaksi_pengguna_tanggal
    ON acakehan.transaksi (pengguna_id, tanggal_transaksi DESC, status_hapus);
CREATE INDEX idx_transaksi_pengguna_tipe
    ON acakehan.transaksi (pengguna_id, tipe_transaksi, status_hapus);
-- Partial index — hanya transaksi aktif (tidak terhapus) yang sering di-query
CREATE INDEX idx_transaksi_aktif
    ON acakehan.transaksi (pengguna_id, tanggal_transaksi DESC)
    WHERE status_hapus = FALSE;


-- ============================================================
--  TABEL 4: anggaran
-- ============================================================

DROP TABLE IF EXISTS acakehan.anggaran CASCADE;

CREATE TABLE acakehan.anggaran (
    anggaran_id        INTEGER              GENERATED ALWAYS AS IDENTITY
                                            (START WITH 1 INCREMENT BY 1),
    pengguna_id        INTEGER              NOT NULL,
    kategori_id        INTEGER              NOT NULL,

    batas_maksimal     NUMERIC(15, 2)       NOT NULL,
    periodes_bulan     SMALLINT             NOT NULL,
    periode_tahun      SMALLINT             NOT NULL,

    -- Denormalisasi terkalkulasi untuk performa
    total_terpakai     NUMERIC(15, 2)       NOT NULL DEFAULT 0.00,
    status_notifikasi  BOOLEAN              NOT NULL DEFAULT FALSE,

    tanggal_dibuat     TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
    diperbarui_pada    TIMESTAMPTZ          NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_anggaran PRIMARY KEY (anggaran_id),

    CONSTRAINT fk_anggaran_pengguna
        FOREIGN KEY (pengguna_id)
        REFERENCES  acakehan.pengguna (pengguna_id)
        ON DELETE   CASCADE
        ON UPDATE   CASCADE,

    CONSTRAINT fk_anggaran_kategori
        FOREIGN KEY (kategori_id)
        REFERENCES  acakehan.kategori (kategori_id)
        ON DELETE   RESTRICT
        ON UPDATE   CASCADE,

    CONSTRAINT uq_anggaran_per_periode
        UNIQUE (pengguna_id, kategori_id, periodes_bulan, periode_tahun),

    CONSTRAINT chk_anggaran_batas_positif
        CHECK (batas_maksimal > 0),
    CONSTRAINT chk_anggaran_total_tidak_negatif
        CHECK (total_terpakai >= 0),
    CONSTRAINT chk_anggaran_bulan_valid
        CHECK (periodes_bulan BETWEEN 1 AND 12),
    CONSTRAINT chk_anggaran_tahun_valid
        CHECK (periode_tahun  BETWEEN 2000 AND 2100)
);

COMMENT ON TABLE  acakehan.anggaran                   IS 'Anggaran bulanan pengguna per kategori pengeluaran';
COMMENT ON COLUMN acakehan.anggaran.total_terpakai    IS 'Diperbarui oleh backend setiap ada transaksi pengeluaran';
COMMENT ON COLUMN acakehan.anggaran.status_notifikasi IS 'FALSE = notif 80% belum terkirim; TRUE = sudah (anti-spam)';

CREATE INDEX idx_anggaran_pengguna ON acakehan.anggaran (pengguna_id);
CREATE INDEX idx_anggaran_kategori ON acakehan.anggaran (kategori_id);
CREATE INDEX idx_anggaran_pengguna_periode
    ON acakehan.anggaran (pengguna_id, periodes_bulan, periode_tahun);


-- ============================================================
--  TABEL 5: notifikasi
-- ============================================================

DROP TABLE IF EXISTS acakehan.notifikasi CASCADE;

CREATE TABLE acakehan.notifikasi (
    notifikasi_id      INTEGER               GENERATED ALWAYS AS IDENTITY
                                             (START WITH 1 INCREMENT BY 1),
    pengguna_id        INTEGER               NOT NULL,
    anggaran_id        INTEGER               NULL,

    judul_pesan        VARCHAR(150)          NOT NULL,
    isi_pesan          TEXT                  NOT NULL,
    tipe_notifikasi    tipe_notifikasi_enum  NOT NULL DEFAULT 'info',
    status_baca        BOOLEAN               NOT NULL DEFAULT FALSE,
    tanggal_kirim      TIMESTAMPTZ           NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_notifikasi PRIMARY KEY (notifikasi_id),

    CONSTRAINT fk_notifikasi_pengguna
        FOREIGN KEY (pengguna_id)
        REFERENCES  acakehan.pengguna (pengguna_id)
        ON DELETE   CASCADE
        ON UPDATE   CASCADE,

    CONSTRAINT fk_notifikasi_anggaran
        FOREIGN KEY (anggaran_id)
        REFERENCES  acakehan.anggaran (anggaran_id)
        ON DELETE   SET NULL
        ON UPDATE   CASCADE
);

COMMENT ON TABLE acakehan.notifikasi IS 'Riwayat notifikasi yang dikirim ke pengguna';

CREATE INDEX idx_notifikasi_pengguna      ON acakehan.notifikasi (pengguna_id);
CREATE INDEX idx_notifikasi_anggaran      ON acakehan.notifikasi (anggaran_id);
CREATE INDEX idx_notifikasi_tgl_kirim     ON acakehan.notifikasi (tanggal_kirim DESC);
-- Partial index — hanya notif yang belum dibaca (paling sering di-query untuk badge)
CREATE INDEX idx_notifikasi_belum_dibaca
    ON acakehan.notifikasi (pengguna_id, tanggal_kirim DESC)
    WHERE status_baca = FALSE;


-- ============================================================
--  TABEL 6: token_refresh  [OPSIONAL]
-- ============================================================

DROP TABLE IF EXISTS acakehan.token_refresh CASCADE;

CREATE TABLE acakehan.token_refresh (
    token_id           INTEGER       GENERATED ALWAYS AS IDENTITY
                                     (START WITH 1 INCREMENT BY 1),
    pengguna_id        INTEGER       NOT NULL,
    token_hash         VARCHAR(255)  NOT NULL,
    perangkat_info     VARCHAR(255)  NULL,
    digunakan          BOOLEAN       NOT NULL DEFAULT FALSE,
    tanggal_terbit     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    tanggal_kadaluarsa TIMESTAMPTZ   NOT NULL,
    tanggal_dicabut    TIMESTAMPTZ   NULL,

    CONSTRAINT pk_token_refresh  PRIMARY KEY (token_id),
    CONSTRAINT uq_token_hash     UNIQUE      (token_hash),

    CONSTRAINT fk_token_pengguna
        FOREIGN KEY (pengguna_id)
        REFERENCES  acakehan.pengguna (pengguna_id)
        ON DELETE   CASCADE
        ON UPDATE   CASCADE
);

CREATE INDEX idx_token_pengguna   ON acakehan.token_refresh (pengguna_id);
CREATE INDEX idx_token_digunakan  ON acakehan.token_refresh (digunakan);
CREATE INDEX idx_token_kadaluarsa ON acakehan.token_refresh (tanggal_kadaluarsa);


-- ============================================================
--  TABEL 7: log_aktivitas  [OPSIONAL]
-- ============================================================

DROP TABLE IF EXISTS acakehan.log_aktivitas CASCADE;

CREATE TABLE acakehan.log_aktivitas (
    log_id             BIGINT            GENERATED ALWAYS AS IDENTITY
                                         (START WITH 1 INCREMENT BY 1),
    pengguna_id        INTEGER           NULL,
    jenis_aksi         VARCHAR(50)       NOT NULL,
    deskripsi          VARCHAR(255)      NULL,
    tabel_terdampak    VARCHAR(50)       NULL,
    id_data_terdampak  INTEGER           NULL,
    alamat_ip          INET              NULL,
    user_agent         VARCHAR(500)      NULL,
    status_aksi        status_aksi_enum  NOT NULL DEFAULT 'sukses',
    waktu_aksi         TIMESTAMPTZ       NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_log_aktivitas PRIMARY KEY (log_id),

    CONSTRAINT fk_log_pengguna
        FOREIGN KEY (pengguna_id)
        REFERENCES  acakehan.pengguna (pengguna_id)
        ON DELETE   SET NULL
        ON UPDATE   CASCADE
);

COMMENT ON COLUMN acakehan.log_aktivitas.alamat_ip IS 'Tipe INET PostgreSQL mendukung IPv4 dan IPv6 sekaligus';

CREATE INDEX idx_log_pengguna   ON acakehan.log_aktivitas (pengguna_id);
CREATE INDEX idx_log_jenis_aksi ON acakehan.log_aktivitas (jenis_aksi);
CREATE INDEX idx_log_waktu      ON acakehan.log_aktivitas (waktu_aksi DESC);
CREATE INDEX idx_log_status     ON acakehan.log_aktivitas (status_aksi);


-- ============================================================
--  TRIGGER FUNCTION: perbarui_kolom_diperbarui_pada()
--  Di PostgreSQL, trigger harus berupa fungsi yang mengembalikan TRIGGER.
--  Satu fungsi ini dipakai oleh SEMUA tabel yang punya kolom diperbarui_pada.
-- ============================================================

CREATE OR REPLACE FUNCTION acakehan.perbarui_kolom_diperbarui_pada()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Setiap kali baris di-UPDATE, perbarui kolom diperbarui_pada ke waktu sekarang
    NEW.diperbarui_pada = NOW();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION acakehan.perbarui_kolom_diperbarui_pada()
    IS 'Trigger function: otomatis perbarui kolom diperbarui_pada saat UPDATE';

-- Pasang trigger ke setiap tabel yang relevan
CREATE TRIGGER trg_pengguna_diperbarui
    BEFORE UPDATE ON acakehan.pengguna
    FOR EACH ROW EXECUTE FUNCTION acakehan.perbarui_kolom_diperbarui_pada();

CREATE TRIGGER trg_kategori_diperbarui
    BEFORE UPDATE ON acakehan.kategori
    FOR EACH ROW EXECUTE FUNCTION acakehan.perbarui_kolom_diperbarui_pada();

CREATE TRIGGER trg_transaksi_diperbarui
    BEFORE UPDATE ON acakehan.transaksi
    FOR EACH ROW EXECUTE FUNCTION acakehan.perbarui_kolom_diperbarui_pada();

CREATE TRIGGER trg_anggaran_diperbarui
    BEFORE UPDATE ON acakehan.anggaran
    FOR EACH ROW EXECUTE FUNCTION acakehan.perbarui_kolom_diperbarui_pada();


-- ============================================================
--  TRIGGER FUNCTION: reset_notif_awal_bulan()
--  Mereset status_notifikasi anggaran ke FALSE saat periode
--  berubah, agar notifikasi 80% bisa dikirim ulang bulan depan.
-- ============================================================

CREATE OR REPLACE FUNCTION acakehan.reset_notif_awal_bulan()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE acakehan.anggaran
    SET    status_notifikasi = FALSE
    WHERE  pengguna_id       = NEW.pengguna_id
      AND  status_notifikasi  = TRUE
      AND  (periodes_bulan   != EXTRACT(MONTH FROM NEW.tanggal_transaksi)::SMALLINT
         OR periode_tahun    != EXTRACT(YEAR  FROM NEW.tanggal_transaksi)::SMALLINT);

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_reset_notif_awal_bulan
    AFTER INSERT ON acakehan.transaksi
    FOR EACH ROW EXECUTE FUNCTION acakehan.reset_notif_awal_bulan();


-- ============================================================
--  FUNCTION: fn_catat_transaksi()
--  Versi PostgreSQL dari stored procedure pencatatan transaksi.
--  Mengembalikan TABLE dengan hasil operasi.
-- ============================================================

CREATE OR REPLACE FUNCTION acakehan.fn_catat_transaksi(
    p_pengguna_id        INTEGER,
    p_kategori_id        INTEGER,
    p_jumlah_nominal     NUMERIC(15,2),
    p_tipe_transaksi     tipe_kategori_enum,
    p_tanggal_transaksi  DATE,
    p_catatan_tambahan   TEXT DEFAULT NULL
)
RETURNS TABLE (
    transaksi_id_baru   INTEGER,
    persen_anggaran     NUMERIC(5,2),
    perlu_notifikasi    BOOLEAN,
    pesan_hasil         TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_transaksi_id      INTEGER;
    v_anggaran_id       INTEGER;
    v_batas_maksimal    NUMERIC(15,2);
    v_total_setelah     NUMERIC(15,2);
    v_status_notif      BOOLEAN;
    v_persen            NUMERIC(5,2) := 0;
    v_perlu_notif       BOOLEAN      := FALSE;
BEGIN
    -- ── Langkah 1: Masukkan transaksi baru ────────────────────
    INSERT INTO acakehan.transaksi (
        pengguna_id, kategori_id, jumlah_nominal,
        tipe_transaksi, tanggal_transaksi, catatan_tambahan
    ) VALUES (
        p_pengguna_id, p_kategori_id, p_jumlah_nominal,
        p_tipe_transaksi, p_tanggal_transaksi, p_catatan_tambahan
    )
    RETURNING transaksi.transaksi_id INTO v_transaksi_id;

    -- ── Langkah 2: Perbarui anggaran jika pengeluaran ─────────
    IF p_tipe_transaksi = 'pengeluaran' THEN

        SELECT anggaran_id, batas_maksimal, total_terpakai, status_notifikasi
        INTO   v_anggaran_id, v_batas_maksimal, v_total_setelah, v_status_notif
        FROM   acakehan.anggaran
        WHERE  pengguna_id    = p_pengguna_id
          AND  kategori_id    = p_kategori_id
          AND  periodes_bulan = EXTRACT(MONTH FROM p_tanggal_transaksi)::SMALLINT
          AND  periode_tahun  = EXTRACT(YEAR  FROM p_tanggal_transaksi)::SMALLINT
        FOR UPDATE;

        IF FOUND THEN
            v_total_setelah := v_total_setelah + p_jumlah_nominal;
            v_persen        := ROUND((v_total_setelah / v_batas_maksimal) * 100, 2);

            UPDATE acakehan.anggaran
            SET    total_terpakai = v_total_setelah
            WHERE  anggaran_id    = v_anggaran_id;

            IF v_persen >= 80.00 AND NOT v_status_notif THEN
                v_perlu_notif := TRUE;
                UPDATE acakehan.anggaran
                SET    status_notifikasi = TRUE
                WHERE  anggaran_id = v_anggaran_id;
            END IF;
        END IF;
    END IF;

    -- Kembalikan hasil
    RETURN QUERY SELECT
        v_transaksi_id,
        v_persen,
        v_perlu_notif,
        CASE
            WHEN v_perlu_notif THEN
                format('Peringatan: anggaran telah terpakai %.2f%%', v_persen)
            ELSE
                'Transaksi berhasil dicatat.'
        END;

EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Gagal mencatat transaksi: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION acakehan.fn_catat_transaksi
    IS 'Catat transaksi + perbarui anggaran + deteksi perlu notifikasi secara atomik';


-- ============================================================
--  VIEW: v_ringkasan_transaksi_bulanan
-- ============================================================

CREATE OR REPLACE VIEW acakehan.v_ringkasan_transaksi_bulanan AS
SELECT
    t.pengguna_id,
    EXTRACT(YEAR  FROM t.tanggal_transaksi)::INTEGER     AS tahun,
    EXTRACT(MONTH FROM t.tanggal_transaksi)::INTEGER     AS bulan,
    COALESCE(SUM(t.jumlah_nominal)
        FILTER (WHERE t.tipe_transaksi = 'pemasukan'),   0) AS total_pemasukan,
    COALESCE(SUM(t.jumlah_nominal)
        FILTER (WHERE t.tipe_transaksi = 'pengeluaran'), 0) AS total_pengeluaran,
    COALESCE(SUM(CASE
        WHEN t.tipe_transaksi = 'pemasukan'   THEN  t.jumlah_nominal
        WHEN t.tipe_transaksi = 'pengeluaran' THEN -t.jumlah_nominal
    END), 0)                                               AS saldo_bersih,
    COUNT(t.transaksi_id)                                  AS jumlah_transaksi
FROM
    acakehan.transaksi t
WHERE
    t.status_hapus = FALSE
GROUP BY
    t.pengguna_id,
    EXTRACT(YEAR  FROM t.tanggal_transaksi),
    EXTRACT(MONTH FROM t.tanggal_transaksi);

COMMENT ON VIEW acakehan.v_ringkasan_transaksi_bulanan
    IS 'Ringkasan pemasukan, pengeluaran, saldo per pengguna per bulan';


-- ============================================================
--  VIEW: v_status_anggaran_aktif
-- ============================================================

CREATE OR REPLACE VIEW acakehan.v_status_anggaran_aktif AS
SELECT
    a.anggaran_id,
    a.pengguna_id,
    k.nama_kategori,
    k.ikon_kategori,
    a.batas_maksimal,
    a.total_terpakai,
    ROUND((a.total_terpakai / NULLIF(a.batas_maksimal, 0)) * 100, 2)
                                                           AS persen_terpakai,
    GREATEST(0, a.batas_maksimal - a.total_terpakai)       AS sisa_anggaran,
    a.periodes_bulan,
    a.periode_tahun,
    a.status_notifikasi,
    CASE
        WHEN (a.total_terpakai / NULLIF(a.batas_maksimal, 0)) >= 1.00 THEN 'kritis'
        WHEN (a.total_terpakai / NULLIF(a.batas_maksimal, 0)) >= 0.80 THEN 'peringatan'
        ELSE                                                                'aman'
    END                                                    AS label_status
FROM
    acakehan.anggaran  a
    JOIN acakehan.kategori k ON k.kategori_id = a.kategori_id;

COMMENT ON VIEW acakehan.v_status_anggaran_aktif
    IS 'Status semua anggaran lengkap dengan persentase dan label kondisi';


-- ============================================================
--  SEED DATA: Kategori Default Sistem
-- ============================================================

INSERT INTO acakehan.kategori (nama_kategori, ikon_kategori, tipe_kategori, pengguna_id)
VALUES
    -- Pemasukan
    ('Gaji',              'icon-salary',    'pemasukan',   NULL),
    ('Bonus',             'icon-bonus',     'pemasukan',   NULL),
    ('Freelance',         'icon-freelance', 'pemasukan',   NULL),
    ('Investasi',         'icon-invest',    'pemasukan',   NULL),
    ('Bisnis',            'icon-business',  'pemasukan',   NULL),
    ('Hadiah',            'icon-gift',      'pemasukan',   NULL),
    ('Lainnya (Masuk)',   'icon-other-in',  'pemasukan',   NULL),
    -- Pengeluaran
    ('Makanan & Minuman', 'icon-food',      'pengeluaran', NULL),
    ('Transportasi',      'icon-transport', 'pengeluaran', NULL),
    ('Belanja',           'icon-shopping',  'pengeluaran', NULL),
    ('Tagihan & Utilitas','icon-bill',      'pengeluaran', NULL),
    ('Kesehatan',         'icon-health',    'pengeluaran', NULL),
    ('Pendidikan',        'icon-education', 'pengeluaran', NULL),
    ('Hiburan',           'icon-entertain', 'pengeluaran', NULL),
    ('Olahraga',          'icon-sport',     'pengeluaran', NULL),
    ('Perawatan Diri',    'icon-care',      'pengeluaran', NULL),
    ('Cicilan / Utang',   'icon-debt',      'pengeluaran', NULL),
    ('Tabungan',          'icon-saving',    'pengeluaran', NULL),
    ('Sosial & Donasi',   'icon-social',    'pengeluaran', NULL),
    ('Lainnya (Keluar)',  'icon-other-out', 'pengeluaran', NULL);


-- ============================================================
--  VERIFIKASI AKHIR
-- ============================================================

SELECT
    schemaname   AS "Schema",
    tablename    AS "Nama Tabel",
    tableowner   AS "Pemilik"
FROM
    pg_tables
WHERE
    schemaname = 'acakehan'
ORDER BY
    tablename;
