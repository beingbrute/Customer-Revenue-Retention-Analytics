# Project Methodology

## 1. Data Ingestion

The project uses the **Online Retail II** dataset from the UCI Machine Learning Repository. The original Excel workbook contains transaction data across two worksheets covering December 2009 through December 2011.

Both worksheets were loaded with Python and combined into one transaction-level dataset. A source-year field was retained to support reconciliation, auditing, and duplicate detection across worksheets.

The original workbook contained **1,067,371 rows**. After cleaning and cross-source duplicate resolution, **1,033,036 rows** were loaded into the Snowflake RAW layer.

## 2. Data Cleaning

The Python cleaning process included:

* Standardizing column names
* Assigning appropriate data types
* Normalizing invoice numbers, stock codes, and descriptions
* Identifying exact duplicate business records
* Reconciling overlapping records across source worksheets
* Classifying transaction types
* Separating merchandise and non-merchandise records
* Creating line-level revenue values
* Creating data-quality and analysis-eligibility flags
* Validating missing values and suspicious records

Duplicate detection used the business columns:

* Invoice number
* Stock code
* Product description
* Quantity
* Invoice date
* Unit price
* Customer ID
* Country

Records failing the final analytical quality rules were marked as ineligible using the `ANALYSIS_ELIGIBLE` field. This approach preserved transparency while preventing suspicious records from affecting business metrics.

### Missing-customer treatment

Transactions with missing customer IDs were retained for:

* Overall revenue analysis
* Product analysis
* Product-category analysis

They were excluded from:

* Customer-level analysis
* RFM segmentation
* Repeat-customer analysis
* Cohort-retention analysis

Customer-level analyses require a known customer identifier to track activity accurately.

### Missing-description treatment

Records with missing product descriptions were excluded from the generative AI classification workflow because a meaningful product category could not be assigned without descriptive text.

### Cancellation treatment

Cancellation values were analyzed separately from gross merchandise sales.

Cancellation value represents the absolute transaction value associated with cancellation records. It should not automatically be interpreted as a confirmed refund or realized financial loss because the dataset does not provide payment-settlement information.

## 3. Revenue Analysis

Revenue measures were created at the transaction-line level and aggregated into business KPIs.

### Gross merchandise sales

Gross merchandise sales include valid merchandise sale transactions:

```text
Gross Merchandise Sales = Sum of merchandise sale line values
```

### Cancellation value

Cancellation value uses the absolute value of valid merchandise cancellation transactions:

```text
Cancellation Value = Sum of absolute cancellation line values
```

### Estimated net revenue

Estimated net revenue uses the signed value of sales and cancellation transactions:

```text
Estimated Net Revenue =
Gross Merchandise Sales - Cancellation Value
```

### Sales invoices

Sales invoices represent the distinct invoice numbers associated with valid merchandise sales.

### Units sold

Units sold represent the total positive quantity from valid merchandise sale transactions.

### Average order value

```text
Average Order Value =
Gross Merchandise Sales / Distinct Sales Invoices
```

### Cancellation rate

```text
Cancellation Rate =
Cancellation Value / Gross Merchandise Sales × 100
```

The latest month in the dataset was marked as a `Partial month`. The Tableau monthly-revenue trend filters to `Complete month` to prevent an incomplete reporting period from being compared directly with complete months.

## 4. Customer Analysis

Customer-level metrics were calculated only for identified customers with at least one valid merchandise sale.

For each customer, the analysis calculated:

* First purchase date
* Last purchase date
* Number of distinct sales invoices
* Units purchased
* Gross sales
* Cancellation value
* Estimated net revenue

Customers were divided into:

* **Repeat Customer:** More than one distinct sales invoice
* **One-Time Customer:** Exactly one distinct sales invoice

The final customer population contained **5,852 identified customers**:

* Repeat customers: **4,234**
* One-time customers: **1,618**

## 5. RFM Customer Segmentation

RFM analysis was used to group customers according to purchasing behaviour.

The model considered:

* **Recency:** Number of days since the customer’s most recent purchase
* **Frequency:** Number of distinct purchase invoices
* **Monetary value:** Customer-level revenue contribution

RFM scores were combined to assign customers to actionable business segments, including:

* Champions
* Loyal Customers
* Potential Loyalists
* New Customers
* Promising Customers
* Need Attention
* At Risk
* Hibernating
* Regular Customers
* High-Value Active

The segment-level Snowflake mart calculates:

* Customer count
* Average recency
* Average frequency
* Gross monetary value
* Cancellation value
* Net monetary value
* Average customer value
* Customer share
* Net-revenue share
* Cancellation rate

The final Champions segment contained **1,448 customers** and generated **74.04%** of identified-customer net revenue.

## 6. Cohort Retention Analysis

Each identified customer was assigned to a cohort based on the month of their first valid merchandise purchase.

Monthly customer activity was then compared with the original cohort size.

* **Cohort Period 1:** First-purchase month
* **Cohort Period 2:** Month following the first-purchase month
* **Cohort Period 3:** Second month after the first-purchase month
* Subsequent periods follow the same structure

Only cohorts old enough to reach a particular retention period were included in that period’s calculation.

### Individual cohort retention

```text
Cohort Retention Rate =
Retained Customers / Original Cohort Size × 100
```

### Weighted retention KPI

The KPI cards use weighted retention rather than a simple average of cohort percentages:

```text
Weighted Retention =
Total Retained Customers Across Eligible Cohorts
/
Total Customers Across Eligible Cohorts
× 100
```

This prevents small cohorts from receiving the same influence as large cohorts.

The validated weighted-retention results were:

| Retention period | Weighted retention |
| ---------------- | -----------------: |
| Month 2          |             23.04% |
| Month 3          |             23.29% |
| Month 6          |             21.75% |
| Month 12         |             21.65% |

## 7. Generative AI Product Classification

Product descriptions were classified using the local **Qwen3:4B** model through Ollama.

Running the model locally provided:

* No paid API requirement
* Local processing of product descriptions
* Greater control over the classification workflow
* Reproducible model and prompt settings

The classification process included:

1. Normalizing product descriptions
2. Creating unique description IDs
3. Defining a fixed 12-category business taxonomy
4. Requesting structured classification output
5. Processing descriptions in batches
6. Saving classification checkpoints
7. Validating the number of returned records
8. Applying conservative keyword-validation rules
9. Comparing rule and model classifications
10. Applying high-confidence rule overrides
11. Performing targeted manual quality assurance
12. Mapping the final classifications back to stock codes

The final classification output contained:

* **4,685 unique product descriptions**
* **4,725 classified product records**
* **4,725 unique stock codes**
* **12 product categories**
* **0 duplicate stock codes**
* **0 missing final categories**

A transparent `Unclassified` bucket was retained in the category-performance mart for unmatched technical or non-sale stock codes that were not part of the finalized classification input.

## 8. Snowflake Warehouse Implementation

The analytical data was loaded into Snowflake using three schemas.

### RAW layer

The RAW layer stores the cleaned transaction-level dataset in:

```text
RAW.TRANSACTIONS_CLEAN_RAW
```

This table preserves the prepared fields, transaction classifications, quality flags, and analysis-eligibility status created during Python processing.

### STAGING layer

The STAGING layer contains:

```text
STAGING.VW_TRANSACTIONS_STANDARDIZED
```

This view creates:

* Calendar fields
* Invoice month and year
* Valid-merchandise flags
* Merchandise-sale flags
* Merchandise-cancellation flags
* Gross-sales values
* Cancellation values
* Signed net-revenue values

### ANALYTICS layer

The ANALYTICS layer contains business-ready objects for:

* Revenue KPIs
* Monthly revenue
* Customer metrics
* Customer-type summaries
* Customer cohorts
* Cohort retention
* Retention KPIs
* RFM customer segments
* GenAI product classifications
* Product-category performance
* Tableau KPI cards

The Python-generated customer-segment and product-classification outputs were loaded into Snowflake before their dependent analytical views were created.

## 9. Tableau Implementation

The dashboards were built with Tableau connected directly to the finalized Snowflake analytical views.

Six Snowflake data sources were used:

* `SF_Category_Performance`
* `SF_Cohort_Retention`
* `SF_Customer_Segments`
* `SF_Monthly_Revenue`
* `SF_Retention_KPI_Cards`
* `SF_Revenue_KPI_Cards`

For publishing, each view was exported to CSV and packaged into the workbook as an extract, because Tableau Public does not accept Snowflake connections. The workbook in this repository is that packaged version, so it opens without a Snowflake account. The [Tableau documentation](../tableau/README.md) maps each packaged source to its Snowflake view.

Two final dashboards were created:

### Revenue Overview

The Revenue Overview dashboard contains:

* Overall revenue KPI cards
* Complete-month estimated net revenue trend
* Estimated net revenue by product category

### Retention Overview

The Retention Overview dashboard contains:

* Weighted retention KPI cards
* Net-revenue share by customer segment
* Customer cohort-retention heatmap

## 10. Quality Assurance

Validation was performed across Python, Snowflake, and Tableau.

The final checks confirmed:

* RAW rows: **1,033,036**
* STAGING rows: **1,033,036**
* Gross merchandise sales: **£19,604,891.64**
* Cancellation value: **£716,462.57**
* Estimated net revenue: **£18,888,429.07**
* RFM customers: **5,852**
* Champions customers: **1,448**
* GenAI classification rows: **4,725**
* Unique classified stock codes: **4,725**
* Duplicate classified stock codes: **0**
* Final GenAI categories: **12**
* Missing classification categories: **0**
* Product-category revenue share: **100%**
* Required core Snowflake analytical views: **10**

The enriched merchandise row count matched the valid merchandise row count at **1,027,236**, confirming that the classification join neither removed nor duplicated transaction rows.

## 11. Reproducibility

### Python workflow

Run the notebooks in numerical order:

1. `01_data_inspection.ipynb`
2. `02_data_cleaning.ipynb`
3. `03_revenue_analysis.ipynb`
4. `04_customer_segmentation.ipynb`
5. `05_retention_cohort_analysis.ipynb`
6. `06_genai_product_classification.ipynb`

### Snowflake workflow

Run the SQL files in numerical order:

1. `01_environment_setup.sql`
2. `02_raw_table_setup.sql`
3. `03_raw_data_validation.sql`
4. `04_staging_model.sql`
5. `05_revenue_marts.sql`
6. `06_customer_marts.sql`
7. `07_retention_marts.sql`
8. `08_customer_segment_mart.sql`
9. `09_product_category_mart.sql`
10. `10_final_snowflake_validation.sql`
11. `11_tableau_presentation_views.sql`

The cleaned transaction data and Python-generated analytical outputs must be loaded into their corresponding Snowflake tables before running SQL views that depend on them.

The Tableau workbook does not depend on these steps: it packages CSV extracts of the presentation views, so it opens without a Snowflake sign-in. The same dashboards are published on [Tableau Public](../README.md#tableau-dashboards).
