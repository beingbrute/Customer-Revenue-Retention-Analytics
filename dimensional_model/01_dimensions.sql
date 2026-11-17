-- =========================================================
-- 01  Dimensions: date, country, product, line type
-- Database: retail_dw   (staging tables loaded by load_staging.py)
-- =========================================================

DROP SCHEMA IF EXISTS dw CASCADE;
CREATE SCHEMA dw;


-- ---------------------------------------------------------
-- dim_date: one row per calendar day, Dec 2009 - Dec 2011
-- Key is the date as YYYYMMDD, so it is readable and sorts correctly
-- ---------------------------------------------------------
CREATE TABLE dw.dim_date AS
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT          AS date_key,
    d::DATE                              AS full_date,
    EXTRACT(YEAR    FROM d)::INT         AS year,
    EXTRACT(QUARTER FROM d)::INT         AS quarter,
    EXTRACT(MONTH   FROM d)::INT         AS month,
    TO_CHAR(d, 'Mon')                    AS month_name,
    TO_CHAR(d, 'YYYY-MM')                AS year_month,
    EXTRACT(ISODOW  FROM d)::INT         AS day_of_week,     -- 1 = Monday
    TO_CHAR(d, 'Dy')                     AS day_name,
    EXTRACT(ISODOW  FROM d) IN (6, 7)    AS is_weekend
FROM GENERATE_SERIES(DATE '2009-12-01', DATE '2011-12-31', INTERVAL '1 day') AS d;

ALTER TABLE dw.dim_date ADD PRIMARY KEY (date_key);


-- ---------------------------------------------------------
-- dim_country: one row per country on the invoices
-- ---------------------------------------------------------
CREATE TABLE dw.dim_country (
    country_key   SERIAL PRIMARY KEY,
    country_name  TEXT    NOT NULL UNIQUE,
    is_uk         BOOLEAN NOT NULL
);

INSERT INTO dw.dim_country (country_name, is_uk)
SELECT DISTINCT country, country = 'United Kingdom'
FROM staging.transactions
ORDER BY country;


-- ---------------------------------------------------------
-- dim_product: one row per stock code (SCD Type 1)
-- A stock code can appear with several descriptions; the most
-- frequent one is kept (ties: the most recently used).
-- Category and ABC class come from the GenAI classification.
-- ---------------------------------------------------------
CREATE TABLE dw.dim_product (
    product_key       SERIAL PRIMARY KEY,
    stock_code        TEXT NOT NULL UNIQUE,
    description       TEXT,
    product_category  TEXT NOT NULL,
    abc_class         TEXT
);

WITH description_counts AS (
    SELECT stock_code, description,
           COUNT(*)          AS uses,
           MAX(invoice_date) AS last_used
    FROM staging.transactions
    WHERE description IS NOT NULL
    GROUP BY stock_code, description
),
best_description AS (
    SELECT DISTINCT ON (stock_code) stock_code, description
    FROM description_counts
    ORDER BY stock_code, uses DESC, last_used DESC
),
stock_codes AS (
    SELECT DISTINCT stock_code FROM staging.transactions
)
INSERT INTO dw.dim_product (stock_code, description, product_category, abc_class)
SELECT s.stock_code,
       b.description,
       COALESCE(pc.product_category, 'Unclassified'),
       pc.abc_class
FROM stock_codes s
LEFT JOIN best_description b                USING (stock_code)
LEFT JOIN staging.product_classifications pc USING (stock_code)
ORDER BY s.stock_code;


-- ---------------------------------------------------------
-- dim_line_type: small junk dimension for the two line flags
-- ---------------------------------------------------------
CREATE TABLE dw.dim_line_type (
    line_type_key     SERIAL PRIMARY KEY,
    transaction_type  TEXT    NOT NULL,
    line_category     TEXT    NOT NULL,
    is_merchandise    BOOLEAN NOT NULL,
    UNIQUE (transaction_type, line_category)
);

INSERT INTO dw.dim_line_type (transaction_type, line_category, is_merchandise)
SELECT DISTINCT transaction_type, line_category, line_category = 'Merchandise'
FROM staging.transactions
ORDER BY transaction_type, line_category;


-- ---------------------------------------------------------
-- Check
-- ---------------------------------------------------------
SELECT 'dim_date'      AS table_name, COUNT(*) AS rows FROM dw.dim_date
UNION ALL SELECT 'dim_country',   COUNT(*) FROM dw.dim_country
UNION ALL SELECT 'dim_product',   COUNT(*) FROM dw.dim_product
UNION ALL SELECT 'dim_line_type', COUNT(*) FROM dw.dim_line_type;
