-- =========================================================
-- 02  dim_customer: SCD Type 2 on country
--
-- 13 customers placed orders from more than one country over time
-- (31 changes). Each change starts a new version of the customer,
-- so every sale can be linked to the country that was true on the
-- day of the invoice.
--
-- Versions use half-open ranges:  valid_from <= date < valid_to
-- The current version has valid_to = 9999-12-31 and is_current = TRUE.
-- customer_segment (RFM) is a Type 1 attribute: the latest value,
-- repeated on every version.
-- Customers with cancellations or non-merchandise lines only have no RFM
-- segment and are labelled 'No merchandise sales'.
-- customer_key 0 is the "unknown" member for invoices with no customer ID.
-- =========================================================

DROP TABLE IF EXISTS dw.dim_customer CASCADE;

CREATE TABLE dw.dim_customer (
    customer_key      SERIAL    PRIMARY KEY,
    customer_id       BIGINT,
    country_name      TEXT      NOT NULL,
    customer_segment  TEXT,
    version           INT       NOT NULL,
    valid_from        TIMESTAMP NOT NULL,
    valid_to          TIMESTAMP NOT NULL,
    is_current        BOOLEAN   NOT NULL,
    UNIQUE (customer_id, version)
);

-- Unknown member
INSERT INTO dw.dim_customer
    (customer_key, customer_id, country_name, customer_segment, version, valid_from, valid_to, is_current)
VALUES
    (0, NULL, 'Unknown', 'No customer ID', 1, '1900-01-01', '9999-12-31', TRUE);

WITH invoices AS (
    -- one row per customer invoice (an invoice always has one country)
    SELECT DISTINCT customer_id, invoice_no, invoice_date, country
    FROM staging.transactions
    WHERE customer_id IS NOT NULL
),
flagged AS (
    SELECT *,
           LAG(country) OVER (PARTITION BY customer_id ORDER BY invoice_date, invoice_no) AS previous_country
    FROM invoices
),
version_starts AS (
    -- the first invoice, and every invoice where the country changed
    SELECT customer_id, country, invoice_date AS valid_from
    FROM flagged
    WHERE previous_country IS NULL OR previous_country <> country
),
versions AS (
    SELECT customer_id, country, valid_from,
           LEAD(valid_from) OVER (PARTITION BY customer_id ORDER BY valid_from) AS next_from,
           ROW_NUMBER()     OVER (PARTITION BY customer_id ORDER BY valid_from) AS version
    FROM version_starts
)
INSERT INTO dw.dim_customer
    (customer_id, country_name, customer_segment, version, valid_from, valid_to, is_current)
SELECT v.customer_id,
       v.country,
       COALESCE(cs.customer_segment, 'No merchandise sales'),
       v.version,
       v.valid_from,
       COALESCE(v.next_from, TIMESTAMP '9999-12-31'),
       v.next_from IS NULL
FROM versions v
LEFT JOIN staging.customer_segments cs USING (customer_id)
ORDER BY v.customer_id, v.version;

CREATE INDEX ix_dim_customer_lookup ON dw.dim_customer (customer_id, valid_from, valid_to);


-- ---------------------------------------------------------
-- Check
-- ---------------------------------------------------------
SELECT COUNT(*)                                         AS customer_rows,
       COUNT(DISTINCT customer_id)                      AS customers,
       COUNT(*) FILTER (WHERE version > 1)              AS history_versions,
       COUNT(DISTINCT customer_id) FILTER (WHERE version > 1) AS customers_with_history
FROM dw.dim_customer
WHERE customer_key <> 0;

-- Example: one customer's history
SELECT customer_key, customer_id, country_name, version, valid_from, valid_to, is_current
FROM dw.dim_customer
WHERE customer_id = 12431
ORDER BY version;
