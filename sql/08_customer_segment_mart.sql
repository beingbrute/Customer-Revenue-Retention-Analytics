-- =========================================================
-- Customer RFM segment analytics
-- =========================================================

USE ROLE SYSADMIN;
USE WAREHOUSE RETAIL_ANALYTICS_WH;
USE DATABASE CUSTOMER_REVENUE_RETENTION_DB;
USE SCHEMA ANALYTICS;


-- =========================================================
-- 1. Segment-level Tableau view
-- =========================================================

CREATE OR REPLACE VIEW MART_CUSTOMER_SEGMENTS AS
SELECT
    CUSTOMER_SEGMENT,

    COUNT(*)
        AS CUSTOMER_COUNT,

    ROUND(AVG(RECENCY_DAYS), 2)
        AS AVERAGE_RECENCY_DAYS,

    ROUND(AVG(FREQUENCY), 2)
        AS AVERAGE_FREQUENCY,

    ROUND(SUM(GROSS_MONETARY_VALUE), 2)
        AS GROSS_MONETARY_VALUE,

    ROUND(SUM(CANCELLATION_VALUE), 2)
        AS CANCELLATION_VALUE,

    ROUND(SUM(NET_MONETARY_VALUE), 2)
        AS NET_MONETARY_VALUE,

    ROUND(AVG(NET_MONETARY_VALUE), 2)
        AS AVERAGE_CUSTOMER_VALUE,

    ROUND(
        COUNT(*) * 100.0 /
        NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS CUSTOMER_SHARE_PCT,

    ROUND(
        SUM(NET_MONETARY_VALUE) * 100.0 /
        NULLIF(
            SUM(SUM(NET_MONETARY_VALUE)) OVER (),
            0
        ),
        2
    ) AS NET_REVENUE_SHARE_PCT,

    ROUND(
        SUM(CANCELLATION_VALUE) * 100.0 /
        NULLIF(SUM(GROSS_MONETARY_VALUE), 0),
        2
    ) AS CANCELLATION_RATE_PCT

FROM CUSTOMER_RFM_SEGMENTS

GROUP BY CUSTOMER_SEGMENT;


-- =========================================================
-- 2. Validate the uploaded RFM data and segment mart
-- =========================================================

SELECT
    (SELECT COUNT(*)
     FROM CUSTOMER_RFM_SEGMENTS)
        AS TOTAL_CUSTOMER_ROWS,

    (SELECT COUNT(DISTINCT CUSTOMER_ID)
     FROM CUSTOMER_RFM_SEGMENTS)
        AS DISTINCT_CUSTOMERS,

    COUNT(*)
        AS SEGMENT_COUNT,

    MAX(IFF(
        CUSTOMER_SEGMENT = 'Champions',
        CUSTOMER_COUNT,
        NULL
    )) AS CHAMPIONS_CUSTOMERS,

    MAX(IFF(
        CUSTOMER_SEGMENT = 'Champions',
        CUSTOMER_SHARE_PCT,
        NULL
    )) AS CHAMPIONS_CUSTOMER_SHARE_PCT,

    MAX(IFF(
        CUSTOMER_SEGMENT = 'Champions',
        NET_REVENUE_SHARE_PCT,
        NULL
    )) AS CHAMPIONS_NET_REVENUE_SHARE_PCT,

    ROUND(SUM(CUSTOMER_SHARE_PCT), 2)
        AS TOTAL_CUSTOMER_SHARE_PCT,

    ROUND(SUM(NET_REVENUE_SHARE_PCT), 2)
        AS TOTAL_NET_REVENUE_SHARE_PCT

FROM MART_CUSTOMER_SEGMENTS;