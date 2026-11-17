-- =========================================================
-- 04  Validation: the star schema must reproduce the cleaned
-- data and the Python notebook's results exactly.
-- Every row should say OK.
-- =========================================================

WITH totals AS (
    SELECT COUNT(*)                          AS fact_rows,
           ROUND(SUM(gross_sales_value), 2)  AS gross_sales,
           ROUND(SUM(cancellation_value), 2) AS cancellations,
           ROUND(SUM(net_revenue_value), 2)  AS net_revenue
    FROM dw.fact_sales
),
star_monthly AS (
    SELECT DATE_TRUNC('month', d.full_date)::DATE AS month,
           SUM(fs.net_revenue_value)              AS net_revenue
    FROM dw.fact_sales fs
    JOIN dw.dim_date d USING (date_key)
    GROUP BY 1
),
version_gaps AS (
    SELECT valid_to,
           LEAD(valid_from) OVER (PARTITION BY customer_id ORDER BY version) AS next_from
    FROM dw.dim_customer
    WHERE customer_key <> 0
),
checks (check_no, check_name, expected, actual) AS (
    -- Totals against the cleaned data and the notebook
    SELECT 1, 'Fact rows = cleaned rows', 1033036::NUMERIC,
           (SELECT fact_rows FROM totals)
    UNION ALL
    SELECT 2, 'Gross merchandise sales (GBP)', 19604891.64,
           (SELECT gross_sales FROM totals)
    UNION ALL
    SELECT 3, 'Cancellations (GBP)', 716462.57,
           (SELECT cancellations FROM totals)
    UNION ALL
    SELECT 4, 'Estimated net revenue (GBP)', 18888429.07,
           (SELECT net_revenue FROM totals)
    UNION ALL
    SELECT 5, 'Months matching notebook net revenue (of 25)', 25,
           (SELECT COUNT(*) FROM star_monthly s
            JOIN staging.monthly_revenue_python m USING (month)
            WHERE ABS(s.net_revenue - m.net_revenue) < 0.01)
    UNION ALL
    SELECT 6, 'Customers with merchandise sales', 5852,
           (SELECT COUNT(DISTINCT c.customer_id)
            FROM dw.fact_sales fs
            JOIN dw.dim_customer c USING (customer_key)
            WHERE fs.gross_sales_value > 0 AND c.customer_key <> 0)

    -- Every line found the right customer row
    UNION ALL
    SELECT 7, 'Lines with a customer ID matched to a customer version',
           (SELECT COUNT(*) FROM staging.transactions WHERE customer_id IS NOT NULL),
           (SELECT COUNT(*) FROM dw.fact_sales WHERE customer_key <> 0)
    UNION ALL
    SELECT 8, 'Lines without a customer ID on the unknown member',
           (SELECT COUNT(*) FROM staging.transactions WHERE customer_id IS NULL),
           (SELECT COUNT(*) FROM dw.fact_sales WHERE customer_key = 0)

    -- SCD Type 2 rules
    UNION ALL
    SELECT 9, 'Customers without exactly one current row', 0,
           (SELECT COUNT(*) FROM (
                SELECT customer_id FROM dw.dim_customer
                WHERE customer_key <> 0
                GROUP BY customer_id
                HAVING COUNT(*) FILTER (WHERE is_current) <> 1) x)
    UNION ALL
    SELECT 10, 'Overlapping or gapped version ranges', 0,
           (SELECT COUNT(*) FROM version_gaps
            WHERE next_from IS NOT NULL AND next_from <> valid_to)
    UNION ALL
    SELECT 11, 'Country changes tracked as new versions', 31,
           (SELECT COUNT(*) FROM dw.dim_customer WHERE version > 1)
    UNION ALL
    SELECT 12, 'Lines where customer version country <> invoice country', 0,
           (SELECT COUNT(*)
            FROM dw.fact_sales fs
            JOIN dw.dim_customer c  USING (customer_key)
            JOIN dw.dim_country  co USING (country_key)
            WHERE fs.customer_key <> 0 AND c.country_name <> co.country_name)
)
SELECT check_no, check_name, expected, actual,
       CASE WHEN expected = actual THEN 'OK' ELSE 'MISMATCH' END AS status
FROM checks
ORDER BY check_no;
