-- =========================================================
-- 05  Example questions answered from the star schema
-- =========================================================

-- 1. Net revenue by product category and year
SELECT p.product_category,
       d.year,
       ROUND(SUM(f.net_revenue_value), 0) AS net_revenue
FROM dw.fact_sales f
JOIN dw.dim_product p USING (product_key)
JOIN dw.dim_date    d USING (date_key)
WHERE d.year IN (2010, 2011)
GROUP BY p.product_category, d.year
ORDER BY p.product_category, d.year;

-- 2. Weekday vs weekend sales by quarter
SELECT d.year, d.quarter,
       ROUND(SUM(f.gross_sales_value) FILTER (WHERE NOT d.is_weekend), 0) AS weekday_sales,
       ROUND(SUM(f.gross_sales_value) FILTER (WHERE d.is_weekend), 0)     AS weekend_sales
FROM dw.fact_sales f
JOIN dw.dim_date d USING (date_key)
GROUP BY d.year, d.quarter
ORDER BY d.year, d.quarter;

-- 3. Why SCD Type 2 matters: revenue for customers whose country changed,
--    by the country that was true on each invoice date vs their current country
SELECT c.customer_id,
       c.country_name                       AS country_at_invoice,
       cur.country_name                     AS current_country,
       ROUND(SUM(f.net_revenue_value), 2)   AS net_revenue
FROM dw.fact_sales f
JOIN dw.dim_customer c   USING (customer_key)
JOIN dw.dim_customer cur ON cur.customer_id = c.customer_id AND cur.is_current
WHERE c.customer_id IN (SELECT customer_id FROM dw.dim_customer WHERE version > 1)
GROUP BY c.customer_id, c.country_name, cur.country_name
ORDER BY c.customer_id, net_revenue DESC;

-- 4. Customers and net revenue by RFM segment, UK vs other invoice countries
SELECT c.customer_segment,
       co.is_uk,
       COUNT(DISTINCT c.customer_id)        AS customers,
       ROUND(SUM(f.net_revenue_value), 0)   AS net_revenue
FROM dw.fact_sales f
JOIN dw.dim_customer c  USING (customer_key)
JOIN dw.dim_country  co USING (country_key)
WHERE f.customer_key <> 0
GROUP BY c.customer_segment, co.is_uk
ORDER BY c.customer_segment, co.is_uk DESC;
