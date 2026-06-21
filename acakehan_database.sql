-- ============================================================
-- ACAKEHAN - Aplikasi Catatan Keuangan Harian
-- File Database: acakehan_database.sql
-- Versi: 1.0
-- Dibuat: 2025
-- ============================================================

-- Buat dan gunakan database
CREATE DATABASE IF NOT EXISTS acakehan_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE acakehan_db;

-- ============================================================
-- TABEL 1: users
-- Menyimpan data akun pengguna
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id_user     INT(11)       NOT NULL AUTO_INCREMENT,
  nama        VARCHAR(100)  NOT NULL,
  email       VARCHAR(150)  NOT NULL,
  password    VARCHAR(255)  NOT NULL COMMENT 'Hash bcrypt',
  foto_profil VARCHAR(255)  DEFAULT NULL COMMENT 'Path/URL foto profil',
  saldo       DECIMAL(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Saldo bersih terkini',
  created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_user),
  UNIQUE KEY uq_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABEL 2: kategori
-- Master data kategori transaksi (pemasukan & pengeluaran)
-- ============================================================
CREATE TABLE IF NOT EXISTS kategori (
  id_kategori  INT(11)     NOT NULL AUTO_INCREMENT,
  nama_kategori VARCHAR(50) NOT NULL,
  jenis         ENUM('pemasukan','pengeluaran') NOT NULL,
  ikon          VARCHAR(100) DEFAULT NULL COMMENT 'Nama ikon / emoji',
  PRIMARY KEY (id_kategori)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABEL 3: transaksi
-- Menyimpan seluruh transaksi pengguna
-- ============================================================
CREATE TABLE IF NOT EXISTS transaksi (
  id_transaksi INT(11)       NOT NULL AUTO_INCREMENT,
  id_user      INT(11)       NOT NULL,
  id_kategori  INT(11)       NOT NULL,
  jenis        ENUM('pemasukan','pengeluaran') NOT NULL,
  jumlah       DECIMAL(15,2) NOT NULL COMMENT 'Nominal dalam Rupiah',
  tanggal      DATE          NOT NULL,
  catatan      TEXT          DEFAULT NULL,
  created_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_transaksi),
  KEY idx_id_user    (id_user),
  KEY idx_id_kategori(id_kategori),
  KEY idx_tanggal    (tanggal),
  CONSTRAINT fk_transaksi_user
    FOREIGN KEY (id_user) REFERENCES users(id_user)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_transaksi_kategori
    FOREIGN KEY (id_kategori) REFERENCES kategori(id_kategori)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABEL 4: budget
-- Batas anggaran per kategori per bulan
-- ============================================================
CREATE TABLE IF NOT EXISTS budget (
  id_budget      INT(11)       NOT NULL AUTO_INCREMENT,
  id_user        INT(11)       NOT NULL,
  id_kategori    INT(11)       NOT NULL,
  nominal_budget DECIMAL(15,2) NOT NULL COMMENT 'Batas anggaran bulanan',
  bulan          INT(2)        NOT NULL COMMENT '1=Januari ... 12=Desember',
  tahun          INT(4)        NOT NULL,
  PRIMARY KEY (id_budget),
  UNIQUE KEY uq_budget_user_kategori_periode (id_user, id_kategori, bulan, tahun),
  KEY idx_budget_user (id_user),
  CONSTRAINT fk_budget_user
    FOREIGN KEY (id_user) REFERENCES users(id_user)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_budget_kategori
    FOREIGN KEY (id_kategori) REFERENCES kategori(id_kategori)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DATA AWAL: Kategori Default
-- ============================================================

-- Kategori Pengeluaran
INSERT INTO kategori (nama_kategori, jenis, ikon) VALUES
  ('Makan & Minum',   'pengeluaran', '🍽️'),
  ('Transportasi',    'pengeluaran', '🚌'),
  ('Belanja',         'pengeluaran', '🛒'),
  ('Hiburan',         'pengeluaran', '🎮'),
  ('Kesehatan',       'pengeluaran', '💊'),
  ('Pendidikan',      'pengeluaran', '📚'),
  ('Tagihan',         'pengeluaran', '🧾'),
  ('Rumah Tangga',    'pengeluaran', '🏠'),
  ('Pakaian',         'pengeluaran', '👕'),
  ('Kecantikan',      'pengeluaran', '💄'),
  ('Olahraga',        'pengeluaran', '⚽'),
  ('Sosial',          'pengeluaran', '🤝'),
  ('Teknologi',       'pengeluaran', '💻'),
  ('Lain-lain',       'pengeluaran', '📦');

-- Kategori Pemasukan
INSERT INTO kategori (nama_kategori, jenis, ikon) VALUES
  ('Gaji',            'pemasukan',   '💼'),
  ('Freelance',       'pemasukan',   '🖥️'),
  ('Uang Saku',       'pemasukan',   '💰'),
  ('Investasi',       'pemasukan',   '📈'),
  ('Hadiah',          'pemasukan',   '🎁'),
  ('Bonus',           'pemasukan',   '🏆'),
  ('Penjualan',       'pemasukan',   '🏷️'),
  ('Lain-lain',       'pemasukan',   '💵');

-- ============================================================
-- DATA DEMO: Pengguna Contoh
-- Password: Demo1234! (hash bcrypt)
-- ============================================================
INSERT INTO users (nama, email, password, saldo) VALUES
  ('Acakehan Demo', 'demo@acakehan.id',
   '$2b$10$examplehashedpassword1234567890abcdefghijklmnop',
   1250000.00);

-- ============================================================
-- DATA DEMO: Transaksi Bulan Ini (id_user = 1)
-- ============================================================
SET @uid = 1;
SET @bln = DATE_FORMAT(CURDATE(), '%Y-%m');

INSERT INTO transaksi (id_user, id_kategori, jenis, jumlah, tanggal, catatan) VALUES
  (@uid, 15, 'pemasukan',   3500000, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 'Gaji bulanan'),
  (@uid, 17, 'pemasukan',    500000, DATE_FORMAT(CURDATE(), '%Y-%m-03'), 'Uang saku dari orang tua'),
  (@uid, 1,  'pengeluaran',   35000, DATE_FORMAT(CURDATE(), '%Y-%m-02'), 'Makan siang'),
  (@uid, 2,  'pengeluaran',   15000, DATE_FORMAT(CURDATE(), '%Y-%m-02'), 'Ojek online'),
  (@uid, 1,  'pengeluaran',   45000, DATE_FORMAT(CURDATE(), '%Y-%m-03'), 'Makan malam bersama teman'),
  (@uid, 5,  'pengeluaran',   80000, DATE_FORMAT(CURDATE(), '%Y-%m-04'), 'Beli obat'),
  (@uid, 3,  'pengeluaran',  250000, DATE_FORMAT(CURDATE(), '%Y-%m-05'), 'Belanja bulanan'),
  (@uid, 7,  'pengeluaran',  150000, DATE_FORMAT(CURDATE(), '%Y-%m-05'), 'Bayar listrik & air'),
  (@uid, 4,  'pengeluaran',   75000, DATE_FORMAT(CURDATE(), '%Y-%m-06'), 'Nonton bioskop'),
  (@uid, 6,  'pengeluaran',  120000, DATE_FORMAT(CURDATE(), '%Y-%m-07'), 'Beli buku kuliah');

-- ============================================================
-- DATA DEMO: Budget Bulan Ini (id_user = 1)
-- ============================================================
SET @bln_int  = MONTH(CURDATE());
SET @thn_int  = YEAR(CURDATE());

INSERT INTO budget (id_user, id_kategori, nominal_budget, bulan, tahun) VALUES
  (@uid, 1,  600000, @bln_int, @thn_int),  -- Makan & Minum
  (@uid, 2,  300000, @bln_int, @thn_int),  -- Transportasi
  (@uid, 3,  500000, @bln_int, @thn_int),  -- Belanja
  (@uid, 4,  200000, @bln_int, @thn_int),  -- Hiburan
  (@uid, 5,  200000, @bln_int, @thn_int),  -- Kesehatan
  (@uid, 7,  300000, @bln_int, @thn_int);  -- Tagihan

-- ============================================================
-- VIEW: Ringkasan Saldo Per Pengguna
-- ============================================================
CREATE OR REPLACE VIEW v_saldo_pengguna AS
SELECT
  u.id_user,
  u.nama,
  u.email,
  COALESCE(SUM(CASE WHEN t.jenis = 'pemasukan'   THEN t.jumlah ELSE 0 END), 0) AS total_pemasukan,
  COALESCE(SUM(CASE WHEN t.jenis = 'pengeluaran' THEN t.jumlah ELSE 0 END), 0) AS total_pengeluaran,
  COALESCE(SUM(CASE WHEN t.jenis = 'pemasukan'   THEN t.jumlah ELSE 0 END), 0)
  - COALESCE(SUM(CASE WHEN t.jenis = 'pengeluaran' THEN t.jumlah ELSE 0 END), 0) AS saldo_bersih
FROM users u
LEFT JOIN transaksi t ON u.id_user = t.id_user
GROUP BY u.id_user, u.nama, u.email;

-- ============================================================
-- VIEW: Ringkasan Transaksi Bulanan Per Kategori
-- ============================================================
CREATE OR REPLACE VIEW v_laporan_bulanan AS
SELECT
  t.id_user,
  k.nama_kategori,
  k.jenis,
  k.ikon,
  MONTH(t.tanggal)  AS bulan,
  YEAR(t.tanggal)   AS tahun,
  COUNT(*)          AS jumlah_transaksi,
  SUM(t.jumlah)     AS total_jumlah
FROM transaksi t
JOIN kategori k ON t.id_kategori = k.id_kategori
GROUP BY t.id_user, k.id_kategori, k.nama_kategori, k.jenis, k.ikon,
         MONTH(t.tanggal), YEAR(t.tanggal);

-- ============================================================
-- VIEW: Status Budget vs Realisasi Bulan Ini
-- ============================================================
CREATE OR REPLACE VIEW v_status_budget AS
SELECT
  b.id_user,
  k.nama_kategori,
  k.ikon,
  b.bulan,
  b.tahun,
  b.nominal_budget,
  COALESCE(SUM(t.jumlah), 0) AS total_pengeluaran,
  ROUND(
    COALESCE(SUM(t.jumlah), 0) / b.nominal_budget * 100, 2
  ) AS persen_penggunaan,
  CASE
    WHEN COALESCE(SUM(t.jumlah), 0) >= b.nominal_budget      THEN 'MELEBIHI'
    WHEN COALESCE(SUM(t.jumlah), 0) >= b.nominal_budget * 0.8 THEN 'MENDEKATI'
    ELSE 'AMAN'
  END AS status
FROM budget b
JOIN kategori k ON b.id_kategori = k.id_kategori
LEFT JOIN transaksi t
  ON  t.id_user      = b.id_user
  AND t.id_kategori  = b.id_kategori
  AND t.jenis        = 'pengeluaran'
  AND MONTH(t.tanggal) = b.bulan
  AND YEAR(t.tanggal)  = b.tahun
GROUP BY b.id_budget, b.id_user, k.nama_kategori, k.ikon,
         b.bulan, b.tahun, b.nominal_budget;

-- ============================================================
-- STORED PROCEDURE: Tambah Transaksi + Update Saldo
-- ============================================================
DELIMITER $$

CREATE PROCEDURE sp_tambah_transaksi (
  IN p_id_user     INT,
  IN p_id_kategori INT,
  IN p_jenis       ENUM('pemasukan','pengeluaran'),
  IN p_jumlah      DECIMAL(15,2),
  IN p_tanggal     DATE,
  IN p_catatan     TEXT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
    -- Simpan transaksi
    INSERT INTO transaksi (id_user, id_kategori, jenis, jumlah, tanggal, catatan)
    VALUES (p_id_user, p_id_kategori, p_jenis, p_jumlah, p_tanggal, p_catatan);

    -- Update saldo pengguna
    IF p_jenis = 'pemasukan' THEN
      UPDATE users SET saldo = saldo + p_jumlah WHERE id_user = p_id_user;
    ELSE
      UPDATE users SET saldo = saldo - p_jumlah WHERE id_user = p_id_user;
    END IF;
  COMMIT;
END$$

DELIMITER ;

-- ============================================================
-- STORED PROCEDURE: Hapus Transaksi + Rollback Saldo
-- ============================================================
DELIMITER $$

CREATE PROCEDURE sp_hapus_transaksi (
  IN p_id_transaksi INT,
  IN p_id_user      INT
)
BEGIN
  DECLARE v_jenis  ENUM('pemasukan','pengeluaran');
  DECLARE v_jumlah DECIMAL(15,2);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  -- Ambil detail transaksi sebelum dihapus
  SELECT jenis, jumlah INTO v_jenis, v_jumlah
  FROM transaksi
  WHERE id_transaksi = p_id_transaksi AND id_user = p_id_user;

  START TRANSACTION;
    DELETE FROM transaksi
    WHERE id_transaksi = p_id_transaksi AND id_user = p_id_user;

    -- Balikkan saldo
    IF v_jenis = 'pemasukan' THEN
      UPDATE users SET saldo = saldo - v_jumlah WHERE id_user = p_id_user;
    ELSE
      UPDATE users SET saldo = saldo + v_jumlah WHERE id_user = p_id_user;
    END IF;
  COMMIT;
END$$

DELIMITER ;

-- ============================================================
-- SELESAI
-- Cara import: mysql -u root -p < acakehan_database.sql
-- ============================================================
