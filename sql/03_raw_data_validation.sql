-- =========================================================
-- Raw data validation
-- =========================================================

USE ROLE SYSADMIN;
USE WAREHOUSE RETAIL_ANALYTICS_WH;
USE DATABASE CUSTOMER_REVENUE_RETENTION_DB;
USE SCHEMA RAW;


-- =========================================================
-- 1. Overall table validation
-- =========================================================

SELECT
    COUNT(*) AS TOTAL_ROWS,
    COUNT(DISTINCT INVOICE_NO) AS DISTINCT_INVOICES,
    COUNT(DISTINCT STOCK_CODE) AS DISTINCT_PRODUCTS,
    COUNT(DISTINCT CUSTOMER_ID) AS DISTINCT_CUSTOMERS,
    MIN(INVOICE_DATE) AS FIRST_INVOICE_DATE,
    MAX(INVOICE_DATE) AS LAST_INVOICE_DATE,

    COUNT_IF(ANALYSIS_ELIGIBLE = TRUE)
        AS ANALYSIS_ELIGIBLE_ROWS,

    COUNT_IF(ANALYSIS_ELIGIBLE = FALSE)
        AS ANALYSIS_INELIGIBLE_ROWS,

    COUNT_IF(ANALYSIS_ELIGIBLE IS NULL)
        AS NULL_ELIGIBILITY_ROWS

FROM TRANSACTIONS_CLEAN_RAW;


-- =========================================================
-- 2. Important missing-value checks
-- =========================================================

SELECT
    COUNT_IF(INVOICE_NO IS NULL)
        AS NULL_INVOICE_NO,

    COUNT_IF(STOCK_CODE IS NULL)
        AS NULL_STOCK_CODE,

    COUNT_IF(DESCRIPTION IS NULL)
        AS NULL_DESCRIPTION,

    COUNT_IF(INVOICE_DATE IS NULL)
        AS NULL_INVOICE_DATE,

    COUNT_IF(UNIT_PRICE IS NULL)
        AS NULL_UNIT_PRICE,

    COUNT_IF(CUSTOMER_ID IS NULL)
        AS NULL_CUSTOMER_ID,

    COUNT_IF(COUNTRY IS NULL)
        AS NULL_COUNTRY,

    COUNT_IF(
        DESCRIPTION IS NULL
        AND ANALYSIS_ELIGIBLE = TRUE
    ) AS ELIGIBLE_ROWS_WITHOUT_DESCRIPTION

FROM TRANSACTIONS_CLEAN_RAW;


-- =========================================================
-- 3. Transaction-type distribution
-- =========================================================

SELECT
    TRANSACTION_TYPE,
    COUNT(*) AS ROW_COUNT,
    ROUND(SUM(LINE_VALUE), 2) AS TOTAL_LINE_VALUE

FROM TRANSACTIONS_CLEAN_RAW

GROUP BY TRANSACTION_TYPE

ORDER BY
    ROW_COUNT DESC,
    TRANSACTION_TYPE;


-- =========================================================
-- 4. Data-quality distribution
-- =========================================================

SELECT
    DATA_QUALITY_FLAG,
    COUNT(*) AS ROW_COUNT

FROM TRANSACTIONS_CLEAN_RAW

GROUP BY DATA_QUALITY_FLAG

ORDER BY
    ROW_COUNT DESC,
    DATA_QUALITY_FLAG;


-- =========================================================
-- 5. Line-category and transaction-type reconciliation
-- =========================================================

SELECT
    LINE_CATEGORY,
    TRANSACTION_TYPE,
    ANALYSIS_ELIGIBLE,
    COUNT(*) AS ROW_COUNT,
    ROUND(SUM(LINE_VALUE), 2) AS TOTAL_LINE_VALUE

FROM TRANSACTIONS_CLEAN_RAW

GROUP BY
    LINE_CATEGORY,
    TRANSACTION_TYPE,
    ANALYSIS_ELIGIBLE

ORDER BY
    TRANSACTION_TYPE,
    ROW_COUNT DESC,
    LINE_CATEGORY;


-- =========================================================
-- 6. Sample of excluded or suspicious records
-- =========================================================

SELECT *

FROM TRANSACTIONS_CLEAN_RAW

WHERE COALESCE(ANALYSIS_ELIGIBLE, FALSE) = FALSE
   OR COALESCE(DATA_QUALITY_FLAG, 'Missing') <> 'Standard'

ORDER BY
    INVOICE_DATE,
    INVOICE_NO,
    STOCK_CODE

LIMIT 100;