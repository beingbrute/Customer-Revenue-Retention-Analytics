-- =========================================================
-- Cohort retention analytics marts
-- =========================================================

USE ROLE SYSADMIN;
USE WAREHOUSE RETAIL_ANALYTICS_WH;
USE DATABASE CUSTOMER_REVENUE_RETENTION_DB;
USE SCHEMA ANALYTICS;


-- =========================================================
-- 1. Assign customers to their first purchase month
-- =========================================================

CREATE OR REPLACE VIEW DIM_CUSTOMER_COHORT AS

SELECT
    CUSTOMER_ID,

    CAST(
        DATE_TRUNC('MONTH', FIRST_PURCHASE_DATE)
        AS DATE
    ) AS COHORT_MONTH

FROM DIM_CUSTOMER;


-- =========================================================
-- 2. Cohort retention view
-- =========================================================

CREATE OR REPLACE VIEW MART_COHORT_RETENTION AS

WITH CUSTOMER_ACTIVITY AS (
    SELECT DISTINCT
        CUSTOMER_ID,
        INVOICE_MONTH AS ACTIVITY_MONTH

    FROM STAGING.VW_TRANSACTIONS_STANDARDIZED

    WHERE IS_MERCHANDISE_SALE = TRUE
      AND CUSTOMER_ID IS NOT NULL
),

COHORT_SIZES AS (
    SELECT
        COHORT_MONTH,
        COUNT(*) AS COHORT_SIZE

    FROM DIM_CUSTOMER_COHORT

    GROUP BY COHORT_MONTH
),

CUSTOMER_COHORT_ACTIVITY AS (
    SELECT
        C.COHORT_MONTH,
        A.CUSTOMER_ID,
        A.ACTIVITY_MONTH,

        DATEDIFF(
            'MONTH',
            C.COHORT_MONTH,
            A.ACTIVITY_MONTH
        ) + 1 AS COHORT_PERIOD

    FROM DIM_CUSTOMER_COHORT AS C

    INNER JOIN CUSTOMER_ACTIVITY AS A
        ON C.CUSTOMER_ID = A.CUSTOMER_ID

    WHERE A.ACTIVITY_MONTH >= C.COHORT_MONTH
),

COHORT_ACTIVITY AS (
    SELECT
        COHORT_MONTH,
        COHORT_PERIOD,

        COUNT(DISTINCT CUSTOMER_ID)
            AS RETAINED_CUSTOMERS

    FROM CUSTOMER_COHORT_ACTIVITY

    GROUP BY
        COHORT_MONTH,
        COHORT_PERIOD
),

-- The source dataset covers 25 monthly periods
PERIOD_NUMBERS AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4())
            AS COHORT_PERIOD

    FROM TABLE(GENERATOR(ROWCOUNT => 25))
),

MAX_ACTIVITY AS (
    SELECT
        MAX(ACTIVITY_MONTH) AS MAX_ACTIVITY_MONTH

    FROM CUSTOMER_ACTIVITY
)

SELECT
    S.COHORT_MONTH,
    P.COHORT_PERIOD,
    S.COHORT_SIZE,

    COALESCE(A.RETAINED_CUSTOMERS, 0)
        AS RETAINED_CUSTOMERS,

    ROUND(
        COALESCE(A.RETAINED_CUSTOMERS, 0) * 100.0
        / NULLIF(S.COHORT_SIZE, 0),
        2
    ) AS RETENTION_RATE_PCT

FROM COHORT_SIZES AS S

CROSS JOIN PERIOD_NUMBERS AS P

CROSS JOIN MAX_ACTIVITY AS M

LEFT JOIN COHORT_ACTIVITY AS A
    ON S.COHORT_MONTH = A.COHORT_MONTH
   AND P.COHORT_PERIOD = A.COHORT_PERIOD

WHERE DATEADD(
    'MONTH',
    P.COHORT_PERIOD - 1,
    S.COHORT_MONTH
) <= M.MAX_ACTIVITY_MONTH;


-- =========================================================
-- 3. Weighted retention KPI view
-- =========================================================

CREATE OR REPLACE VIEW MART_RETENTION_KPIS AS

SELECT
    ROUND(
        SUM(IFF(
            COHORT_PERIOD = 2,
            RETAINED_CUSTOMERS,
            0
        )) * 100.0
        / NULLIF(
            SUM(IFF(
                COHORT_PERIOD = 2,
                COHORT_SIZE,
                0
            )),
            0
        ),
        2
    ) AS MONTH_2_RETENTION_PCT,

    ROUND(
        SUM(IFF(
            COHORT_PERIOD = 3,
            RETAINED_CUSTOMERS,
            0
        )) * 100.0
        / NULLIF(
            SUM(IFF(
                COHORT_PERIOD = 3,
                COHORT_SIZE,
                0
            )),
            0
        ),
        2
    ) AS MONTH_3_RETENTION_PCT,

    ROUND(
        SUM(IFF(
            COHORT_PERIOD = 6,
            RETAINED_CUSTOMERS,
            0
        )) * 100.0
        / NULLIF(
            SUM(IFF(
                COHORT_PERIOD = 6,
                COHORT_SIZE,
                0
            )),
            0
        ),
        2
    ) AS MONTH_6_RETENTION_PCT,

    ROUND(
        SUM(IFF(
            COHORT_PERIOD = 12,
            RETAINED_CUSTOMERS,
            0
        )) * 100.0
        / NULLIF(
            SUM(IFF(
                COHORT_PERIOD = 12,
                COHORT_SIZE,
                0
            )),
            0
        ),
        2
    ) AS MONTH_12_RETENTION_PCT

FROM MART_COHORT_RETENTION;


-- =========================================================
-- 4. Validate retention marts
-- =========================================================

SELECT
    COUNT(*) AS COHORT_PERIOD_ROWS,
    COUNT(DISTINCT COHORT_MONTH) AS TOTAL_COHORTS,
    MIN(COHORT_PERIOD) AS MIN_COHORT_PERIOD,
    MAX(COHORT_PERIOD) AS MAX_COHORT_PERIOD

FROM MART_COHORT_RETENTION;


SELECT *
FROM MART_RETENTION_KPIS;