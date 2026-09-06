-- =========================================================
-- Standardized staging model
-- =========================================================

USE ROLE SYSADMIN;
USE WAREHOUSE RETAIL_ANALYTICS_WH;
USE DATABASE CUSTOMER_REVENUE_RETENTION_DB;
USE SCHEMA STAGING;


-- =========================================================
-- Create standardized transaction view
-- =========================================================

CREATE OR REPLACE VIEW VW_TRANSACTIONS_STANDARDIZED AS

SELECT
    -- Original transaction fields
    INVOICE_NO,
    STOCK_CODE,
    DESCRIPTION,
    QUANTITY,
    INVOICE_DATE,
    UNIT_PRICE,
    CUSTOMER_ID,
    COUNTRY,
    SOURCE_YEAR,
    TRANSACTION_TYPE,
    LINE_CATEGORY,
    LINE_VALUE,
    DATA_QUALITY_FLAG,
    ANALYSIS_ELIGIBLE,

    -- Calendar fields
    CAST(INVOICE_DATE AS DATE)
        AS INVOICE_DAY,

    CAST(DATE_TRUNC('MONTH', INVOICE_DATE) AS DATE)
        AS INVOICE_MONTH,

    YEAR(INVOICE_DATE)
        AS INVOICE_YEAR,

    -- Valid merchandise flag
    IFF(
        ANALYSIS_ELIGIBLE = TRUE
        AND LINE_CATEGORY = 'Merchandise',
        TRUE,
        FALSE
    ) AS IS_VALID_MERCHANDISE,

    -- Merchandise sale flag
    IFF(
        ANALYSIS_ELIGIBLE = TRUE
        AND LINE_CATEGORY = 'Merchandise'
        AND TRANSACTION_TYPE = 'Sale',
        TRUE,
        FALSE
    ) AS IS_MERCHANDISE_SALE,

    -- Merchandise cancellation flag
    IFF(
        ANALYSIS_ELIGIBLE = TRUE
        AND LINE_CATEGORY = 'Merchandise'
        AND TRANSACTION_TYPE = 'Cancellation',
        TRUE,
        FALSE
    ) AS IS_MERCHANDISE_CANCELLATION,

    -- Gross sales value
    IFF(
        ANALYSIS_ELIGIBLE = TRUE
        AND LINE_CATEGORY = 'Merchandise'
        AND TRANSACTION_TYPE = 'Sale',
        LINE_VALUE,
        0
    ) AS GROSS_SALES_VALUE,

    -- Cancellation value stored as a positive amount
    IFF(
        ANALYSIS_ELIGIBLE = TRUE
        AND LINE_CATEGORY = 'Merchandise'
        AND TRANSACTION_TYPE = 'Cancellation',
        ABS(LINE_VALUE),
        0
    ) AS CANCELLATION_VALUE,

    -- Net revenue keeps cancellations as negative values
    IFF(
        ANALYSIS_ELIGIBLE = TRUE
        AND LINE_CATEGORY = 'Merchandise'
        AND TRANSACTION_TYPE IN ('Sale', 'Cancellation'),
        LINE_VALUE,
        0
    ) AS NET_REVENUE_VALUE

FROM RAW.TRANSACTIONS_CLEAN_RAW;


-- =========================================================
-- Validate standardized staging model
-- =========================================================

SELECT
    COUNT(*) AS TOTAL_ROWS,

    COUNT_IF(IS_VALID_MERCHANDISE = TRUE)
        AS VALID_MERCHANDISE_ROWS,

    COUNT_IF(IS_MERCHANDISE_SALE = TRUE)
        AS MERCHANDISE_SALE_ROWS,

    COUNT_IF(IS_MERCHANDISE_CANCELLATION = TRUE)
        AS MERCHANDISE_CANCELLATION_ROWS,

    ROUND(SUM(GROSS_SALES_VALUE), 2)
        AS GROSS_MERCHANDISE_SALES,

    ROUND(SUM(CANCELLATION_VALUE), 2)
        AS CANCELLATION_VALUE,

    ROUND(SUM(NET_REVENUE_VALUE), 2)
        AS NET_REVENUE

FROM VW_TRANSACTIONS_STANDARDIZED;