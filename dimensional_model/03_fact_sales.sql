-- =========================================================
-- 03  fact_sales
-- Grain: one row per invoice line (same rows as the cleaned data).
-- Surrogate keys point to the dimensions; invoice_no is kept as a
-- degenerate dimension. The customer version is chosen by the
-- invoice date (point-in-time join to the SCD Type 2 dimension).
-- Measures follow the same rules as the Snowflake staging view.
-- =========================================================

DROP TABLE IF EXISTS dw.fact_sales;

CREATE TABLE dw.fact_sales (
    sales_line_id       BIGSERIAL     PRIMARY KEY,
    invoice_no          TEXT          NOT NULL,
    date_key            INT           NOT NULL REFERENCES dw.dim_date (date_key),
    customer_key        INT           NOT NULL REFERENCES dw.dim_customer (customer_key),
    product_key         INT           NOT NULL REFERENCES dw.dim_product (product_key),
    country_key         INT           NOT NULL REFERENCES dw.dim_country (country_key),
    line_type_key       INT           NOT NULL REFERENCES dw.dim_line_type (line_type_key),
    invoice_ts          TIMESTAMP     NOT NULL,
    quantity            INT           NOT NULL,
    unit_price          NUMERIC(18,4) NOT NULL,
    line_value          NUMERIC(20,4) NOT NULL,
    gross_sales_value   NUMERIC(20,4) NOT NULL,
    cancellation_value  NUMERIC(20,4) NOT NULL,   -- stored as a positive amount
    net_revenue_value   NUMERIC(20,4) NOT NULL    -- cancellations stay negative
);

INSERT INTO dw.fact_sales (
    invoice_no, date_key, customer_key, product_key, country_key, line_type_key,
    invoice_ts, quantity, unit_price, line_value,
    gross_sales_value, cancellation_value, net_revenue_value)
SELECT
    t.invoice_no,
    TO_CHAR(t.invoice_date, 'YYYYMMDD')::INT,
    COALESCE(c.customer_key, 0),
    p.product_key,
    co.country_key,
    lt.line_type_key,
    t.invoice_date,
    t.quantity,
    t.unit_price,
    t.line_value,
    CASE WHEN t.analysis_eligible AND t.line_category = 'Merchandise'
              AND t.transaction_type = 'Sale'
         THEN t.line_value ELSE 0 END,
    CASE WHEN t.analysis_eligible AND t.line_category = 'Merchandise'
              AND t.transaction_type = 'Cancellation'
         THEN ABS(t.line_value) ELSE 0 END,
    CASE WHEN t.analysis_eligible AND t.line_category = 'Merchandise'
              AND t.transaction_type IN ('Sale', 'Cancellation')
         THEN t.line_value ELSE 0 END
FROM staging.transactions t
JOIN dw.dim_product   p  ON p.stock_code    = t.stock_code
JOIN dw.dim_country   co ON co.country_name = t.country
JOIN dw.dim_line_type lt ON lt.transaction_type = t.transaction_type
                        AND lt.line_category    = t.line_category
LEFT JOIN dw.dim_customer c
       ON c.customer_id = t.customer_id
      AND t.invoice_date >= c.valid_from
      AND t.invoice_date <  c.valid_to;

CREATE INDEX ix_fact_sales_date     ON dw.fact_sales (date_key);
CREATE INDEX ix_fact_sales_customer ON dw.fact_sales (customer_key);
CREATE INDEX ix_fact_sales_product  ON dw.fact_sales (product_key);
ANALYZE dw.fact_sales;


-- ---------------------------------------------------------
-- Check
-- ---------------------------------------------------------
SELECT COUNT(*)                          AS fact_rows,
       ROUND(SUM(gross_sales_value), 2)  AS gross_sales,
       ROUND(SUM(cancellation_value), 2) AS cancellations,
       ROUND(SUM(net_revenue_value), 2)  AS net_revenue
FROM dw.fact_sales;
