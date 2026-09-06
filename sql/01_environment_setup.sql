-- =========================================================
-- Customer Revenue & Retention Analytics
-- Snowflake environment setup
-- =========================================================

USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS RETAIL_ANALYTICS_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Compute warehouse for customer revenue and retention analytics';

USE WAREHOUSE RETAIL_ANALYTICS_WH;

CREATE DATABASE IF NOT EXISTS CUSTOMER_REVENUE_RETENTION_DB
    COMMENT = 'Cloud warehouse for customer revenue and retention analytics';

USE DATABASE CUSTOMER_REVENUE_RETENTION_DB;

CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Original data loaded into Snowflake';

CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'Cleaned and standardized transaction data';

CREATE SCHEMA IF NOT EXISTS ANALYTICS
    COMMENT = 'Business-ready dimensions, facts, and analytical marts';

SHOW SCHEMAS IN DATABASE CUSTOMER_REVENUE_RETENTION_DB;

-- File format for compressed CSV extracts

USE ROLE SYSADMIN;
USE DATABASE CUSTOMER_REVENUE_RETENTION_DB;
USE SCHEMA RAW;

CREATE OR REPLACE FILE FORMAT CSV_GZIP_FORMAT
    TYPE = CSV
    COMPRESSION = AUTO
    PARSE_HEADER = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'null', 'NaN')
    EMPTY_FIELD_AS_NULL = TRUE
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE
    ENCODING = 'UTF8';

SHOW FILE FORMATS IN SCHEMA RAW;