-- ============================================================
-- Retail Sales Performance Dashboard — Star Schema
-- Author: Satyam Thakur
-- Description: OLAP-optimized star schema for retail sales
--              multi-dimensional analysis
-- ============================================================

DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_store;
DROP TABLE IF EXISTS dim_sales_rep;
DROP TABLE IF EXISTS dim_date;

-- ─── Dimension: Date ────────────────────────────────────────
CREATE TABLE dim_date (
    date_id         INT          PRIMARY KEY,
    full_date       DATE         NOT NULL UNIQUE,
    day_of_week     TINYINT,
    day_name        VARCHAR(10),
    week_number     TINYINT,
    month_number    TINYINT,
    month_name      VARCHAR(12),
    quarter         TINYINT,
    fiscal_year     SMALLINT,
    is_weekend      BOOLEAN,
    is_holiday      BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_date_year_month ON dim_date(fiscal_year, month_number);

-- ─── Dimension: Product ─────────────────────────────────────
CREATE TABLE dim_product (
    product_id      INT           PRIMARY KEY AUTO_INCREMENT,
    product_code    VARCHAR(20)   UNIQUE NOT NULL,
    product_name    VARCHAR(150)  NOT NULL,
    category        VARCHAR(80)   NOT NULL,
    subcategory     VARCHAR(80),
    brand           VARCHAR(80),
    unit_cost       DECIMAL(10,2) NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    is_active       BOOLEAN       DEFAULT TRUE
);

CREATE INDEX idx_product_category ON dim_product(category, subcategory);

-- ─── Dimension: Store ───────────────────────────────────────
CREATE TABLE dim_store (
    store_id        INT           PRIMARY KEY AUTO_INCREMENT,
    store_code      VARCHAR(20)   UNIQUE NOT NULL,
    store_name      VARCHAR(100)  NOT NULL,
    city            VARCHAR(80)   NOT NULL,
    province        VARCHAR(80)   NOT NULL,
    region          VARCHAR(50)   NOT NULL,
    store_type      ENUM('Flagship','Standard','Outlet','Online') NOT NULL,
    opened_date     DATE,
    is_active       BOOLEAN       DEFAULT TRUE
);

CREATE INDEX idx_store_region   ON dim_store(region);
CREATE INDEX idx_store_province ON dim_store(province);

-- ─── Dimension: Sales Representative ───────────────────────
CREATE TABLE dim_sales_rep (
    rep_id          INT           PRIMARY KEY AUTO_INCREMENT,
    rep_code        VARCHAR(20)   UNIQUE NOT NULL,
    rep_name        VARCHAR(100)  NOT NULL,
    store_id        INT           NOT NULL,
    hire_date       DATE,
    monthly_quota   DECIMAL(12,2) NOT NULL DEFAULT 0,
    is_active       BOOLEAN       DEFAULT TRUE,
    FOREIGN KEY (store_id) REFERENCES dim_store(store_id)
);

-- ─── Fact: Sales ─────────────────────────────────────────────
-- Central fact table — grain = one line item per transaction
CREATE TABLE fact_sales (
    sale_id         BIGINT        PRIMARY KEY AUTO_INCREMENT,
    date_id         INT           NOT NULL,
    product_id      INT           NOT NULL,
    store_id        INT           NOT NULL,
    rep_id          INT           NOT NULL,
    transaction_ref VARCHAR(50),
    quantity        INT           NOT NULL DEFAULT 1,
    unit_price      DECIMAL(10,2) NOT NULL,
    unit_cost       DECIMAL(10,2) NOT NULL,
    discount_pct    DECIMAL(5,2)  DEFAULT 0.00,
    gross_revenue   DECIMAL(14,2) GENERATED ALWAYS AS
                    (quantity * unit_price) STORED,
    net_revenue     DECIMAL(14,2) GENERATED ALWAYS AS
                    (quantity * unit_price * (1 - discount_pct / 100)) STORED,
    gross_profit    DECIMAL(14,2) GENERATED ALWAYS AS
                    (quantity * (unit_price - unit_cost)) STORED,
    created_at      DATETIME      DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (date_id)    REFERENCES dim_date(date_id),
    FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
    FOREIGN KEY (store_id)   REFERENCES dim_store(store_id),
    FOREIGN KEY (rep_id)     REFERENCES dim_sales_rep(rep_id)
);

-- Performance indexes — critical for dashboard query speed
CREATE INDEX idx_fs_date        ON fact_sales(date_id);
CREATE INDEX idx_fs_product     ON fact_sales(product_id);
CREATE INDEX idx_fs_store       ON fact_sales(store_id);
CREATE INDEX idx_fs_rep         ON fact_sales(rep_id);
CREATE INDEX idx_fs_date_store  ON fact_sales(date_id, store_id);
CREATE INDEX idx_fs_date_product ON fact_sales(date_id, product_id);

-- ─── Sample Seed Data ────────────────────────────────────────
INSERT INTO dim_store (store_code, store_name, city, province, region, store_type, opened_date) VALUES
    ('STR-001', 'Toronto Downtown',   'Toronto',   'Ontario',          'East',    'Flagship', '2019-03-15'),
    ('STR-002', 'Vancouver Flagship', 'Vancouver', 'British Columbia',  'West',    'Flagship', '2020-06-01'),
    ('STR-003', 'Calgary Centre',     'Calgary',   'Alberta',           'West',    'Standard', '2021-01-10'),
    ('STR-004', 'Montreal Hub',       'Montreal',  'Quebec',            'East',    'Standard', '2020-09-20'),
    ('STR-005', 'Saskatoon Outlet',   'Saskatoon', 'Saskatchewan',      'Central', 'Outlet',   '2022-04-05'),
    ('STR-006', 'Online Store',       'N/A',       'N/A',               'Online',  'Online',   '2019-01-01');

INSERT INTO dim_product (product_code, product_name, category, subcategory, brand, unit_cost, unit_price) VALUES
    ('PRD-001', 'Wireless Headphones Pro',  'Electronics',  'Audio',      'SoundMax',   45.00, 129.99),
    ('PRD-002', 'Office Chair Ergonomic',   'Furniture',    'Seating',    'ComfortPro', 85.00, 249.99),
    ('PRD-003', 'Laptop Stand Aluminum',    'Electronics',  'Accessories','TechDesk',   12.00,  49.99),
    ('PRD-004', 'Protein Powder Vanilla',   'Health',       'Nutrition',  'FitLife',    18.00,  54.99),
    ('PRD-005', 'Running Shoes Men',        'Footwear',     'Sports',     'SpeedRun',   35.00,  99.99),
    ('PRD-006', 'Coffee Maker Deluxe',      'Appliances',   'Kitchen',    'BrewMaster', 40.00, 119.99),
    ('PRD-007', 'Yoga Mat Premium',         'Health',       'Fitness',    'ZenFit',      8.00,  39.99),
    ('PRD-008', 'Bluetooth Speaker Mini',   'Electronics',  'Audio',      'SoundMax',   20.00,  69.99);
