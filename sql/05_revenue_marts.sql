-- =========================================================
-- Revenue analytics marts
-- =========================================================

USE ROLE SYSADMIN;
USE WAREHOUSE RETAIL_ANALYTICS_WH;
USE DATABASE CUSTOMER_REVENUE_RETENTION_DB;
USE SCHEMA ANALYTICS;


-- =========================================================
-- 1. Overall revenue KPI view
-- =========================================================

CREATE OR REPLACE VIEW MART_REVENUE_KPIS AS

WITH KPI_BASE AS (
    SELECT
        SUM(GROSS_SALES_VALUE)
            AS GROSS_MERCHANDISE_SALES,

        SUM(CANCELLATION_VALUE)
            AS CANCELLATION_VALUE,

        SUM(NET_REVENUE_VALUE)
            AS NET_REVENUE,

        COUNT(DISTINCT IFF(
            IS_MERCHANDISE_SALE,
            INVOICE_NO,
            NULL
        )) AS SALES_INVOICES,

        SUM(IFF(
            IS_MERCHANDISE_SALE,
            QUANTITY,
            0
        )) AS UNITS_SOLD,

        COUNT(DISTINCT IFF(
            IS_MERCHANDISE_SALE
            AND CUSTOMER_ID IS NOT NULL,
            CUSTOMER_ID,
            NULL
        )) AS KNOWN_CUSTOMERS

    FROM STAGING.VW_TRANSACTIONS_STANDARDIZED

    WHERE IS_VALID_MERCHANDISE = TRUE
      AND TRANSACTION_TYPE IN ('Sale', 'Cancellation')
)

SELECT
    ROUND(GROSS_MERCHANDISE_SALES, 2)
        AS GROSS_MERCHANDISE_SALES,

    ROUND(CANCELLATION_VALUE, 2)
        AS CANCELLATION_VALUE,

    ROUND(NET_REVENUE, 2)
        AS NET_REVENUE,

    SALES_INVOICES,
    UNITS_SOLD,
    KNOWN_CUSTOMERS,

    ROUND(
        GROSS_MERCHANDISE_SALES
        / NULLIF(SALES_INVOICES, 0),
        2
    ) AS AVERAGE_ORDER_VALUE,

    ROUND(
        CANCELLATION_VALUE * 100.0
        / NULLIF(GROSS_MERCHANDISE_SALES, 0),
        2
    ) AS CANCELLATION_RATE_PCT

FROM KPI_BASE;


-- =========================================================
-- 2. Monthly revenue view
-- =========================================================

CREATE OR REPLACE VIEW MART_MONTHLY_REVENUE AS

WITH MONTHLY_BASE AS (
    SELECT
        INVOICE_MONTH AS MONTH,

        ROUND(SUM(GROSS_SALES_VALUE), 2)
            AS GROSS_SALES,

        ROUND(SUM(CANCELLATION_VALUE), 2)
            AS CANCELLATION_VALUE,

        ROUND(SUM(NET_REVENUE_VALUE), 2)
            AS ESTIMATED_NET_REVENUE,

        COUNT(DISTINCT IFF(
            IS_MERCHANDISE_SALE,
            INVOICE_NO,
            NULL
        )) AS SALES_INVOICES,

        SUM(IFF(
            IS_MERCHANDISE_SALE,
            QUANTITY,
            0
        )) AS UNITS_SOLD

    FROM STAGING.VW_TRANSACTIONS_STANDARDIZED

    WHERE IS_VALID_MERCHANDISE = TRUE
      AND TRANSACTION_TYPE IN ('Sale', 'Cancellation')

    GROUP BY INVOICE_MONTH
)

SELECT
    MONTH,

    CASE
        WHEN MONTH = MAX(MONTH) OVER ()
            THEN 'Partial month'
        ELSE 'Complete month'
    END AS PERIOD_STATUS,

    GROSS_SALES,
    CANCELLATION_VALUE,
    ESTIMATED_NET_REVENUE,
    SALES_INVOICES,
    UNITS_SOLD,

    ROUND(
        CANCELLATION_VALUE * 100.0
        / NULLIF(GROSS_SALES, 0),
        2
    ) AS CANCELLATION_RATE_PCT

FROM MONTHLY_BASE;


-- =========================================================
-- 3. Validate revenue marts
-- =========================================================

SELECT *
FROM MART_REVENUE_KPIS;

SELECT *
FROM MART_MONTHLY_REVENUE
ORDER BY MONTH;