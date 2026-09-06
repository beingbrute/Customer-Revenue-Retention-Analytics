-- =========================================================
-- Tableau presentation views
-- =========================================================

USE ROLE SYSADMIN;
USE WAREHOUSE RETAIL_ANALYTICS_WH;
USE DATABASE CUSTOMER_REVENUE_RETENTION_DB;
USE SCHEMA ANALYTICS;





-- =========================================================
-- 1. Revenue KPI card view for Tableau
-- =========================================================

CREATE OR REPLACE VIEW MART_REVENUE_KPI_CARDS AS

SELECT
    'gross_merchandise_sales' AS KPI,
    CAST(GROSS_MERCHANDISE_SALES AS NUMBER(38,2)) AS VALUE,
    'GBP' AS UNIT
FROM MART_REVENUE_KPIS

UNION ALL

SELECT
    'merchandise_cancellation_value',
    CAST(CANCELLATION_VALUE AS NUMBER(38,2)),
    'GBP'
FROM MART_REVENUE_KPIS

UNION ALL

SELECT
    'estimated_net_merchandise_revenue',
    CAST(NET_REVENUE AS NUMBER(38,2)),
    'GBP'
FROM MART_REVENUE_KPIS

UNION ALL

SELECT
    'sales_invoices',
    CAST(SALES_INVOICES AS NUMBER(38,2)),
    'Count'
FROM MART_REVENUE_KPIS

UNION ALL

SELECT
    'units_sold',
    CAST(UNITS_SOLD AS NUMBER(38,2)),
    'Count'
FROM MART_REVENUE_KPIS

UNION ALL

SELECT
    'known_customers',
    CAST(KNOWN_CUSTOMERS AS NUMBER(38,2)),
    'Count'
FROM MART_REVENUE_KPIS

UNION ALL

SELECT
    'average_merchandise_order_value',
    CAST(AVERAGE_ORDER_VALUE AS NUMBER(38,2)),
    'GBP'
FROM MART_REVENUE_KPIS

UNION ALL

SELECT
    'cancellation_rate_by_value',
    CAST(CANCELLATION_RATE_PCT AS NUMBER(38,2)),
    'Percentage'
FROM MART_REVENUE_KPIS;


-- =========================================================
-- 2. Retention KPI card view for Tableau
-- =========================================================

CREATE OR REPLACE VIEW MART_RETENTION_KPI_CARDS AS

WITH TARGET_PERIODS AS (
    SELECT COLUMN1::INTEGER AS PERIOD_NUMBER
    FROM VALUES (2), (3), (6), (12)
)

SELECT
    'Month ' || TARGET.PERIOD_NUMBER
        AS RETENTION_PERIOD,

    COUNT(*)
        AS ELIGIBLE_COHORTS,

    SUM(COHORT.COHORT_SIZE)
        AS ELIGIBLE_CUSTOMERS,

    SUM(COHORT.RETAINED_CUSTOMERS)
        AS RETAINED_CUSTOMERS,

    ROUND(
        SUM(COHORT.RETAINED_CUSTOMERS) * 100.0
        / NULLIF(SUM(COHORT.COHORT_SIZE), 0),
        2
    ) AS WEIGHTED_RETENTION_PCT

FROM TARGET_PERIODS AS TARGET

JOIN MART_COHORT_RETENTION AS COHORT
    ON COHORT.COHORT_PERIOD = TARGET.PERIOD_NUMBER

GROUP BY TARGET.PERIOD_NUMBER;



