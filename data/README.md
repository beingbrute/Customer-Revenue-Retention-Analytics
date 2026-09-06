# Data Directory

This project uses the **Online Retail II** transactional dataset from the UCI Machine Learning Repository.

The original dataset is not stored in this repository because the Excel workbook and some intermediate outputs exceed GitHub’s recommended file-size limits.

## Directory Structure

```text
data/
│
├── README.md
│
├── raw/
│   └── online_retail_II.xlsx
│
└── processed/
    ├── analytics/
    └── cleaning_validation_summary.csv
```

## Raw Data

The `raw/` directory is used for the original source workbook:

```text
data/raw/online_retail_II.xlsx
```

Download the dataset from:

[UCI Online Retail II Dataset](https://archive.ics.uci.edu/dataset/502/online%2Bretail%2Bii)

The original workbook contains two worksheets covering transactions from December 2009 through December 2011.

The raw Excel file contains **1,067,371 transaction records**.

## Processed Data

The `processed/` directory is used for cleaned transaction data, validation outputs, and intermediate analytical files created by the Python notebooks.

The final cleaned transaction dataset contains **1,033,036 rows** after duplicate resolution and data-quality processing.

Examples of processed outputs include:

* Cleaned transaction-level data
* Cleaning-validation summaries
* Revenue KPI outputs
* Monthly revenue summaries
* Customer-level metrics
* RFM customer segments
* Customer cohort-retention results
* Product-performance results
* GenAI product classifications
* Product-category performance summaries

## Analytics Data

The `processed/analytics/` directory contains smaller business-ready outputs used for validation, Snowflake loading, and visualization.

Important analytical outputs include:

* Revenue KPIs
* Monthly revenue
* Customer summaries
* RFM customer segments
* Cohort-retention rates
* Product performance
* Final GenAI product classifications
* Product-category summaries

The final GenAI classification output contains:

* **4,725 classified product records**
* **4,725 unique stock codes**
* **12 product categories**
* **0 duplicate stock codes**
* **0 missing final categories**

## Snowflake Loading

The cleaned and analytical files are used to populate the following Snowflake objects:

| Data output                   | Snowflake destination                     |
| ----------------------------- | ----------------------------------------- |
| Cleaned transaction data      | `RAW.TRANSACTIONS_CLEAN_RAW`              |
| RFM customer-segment output   | `ANALYTICS.CUSTOMER_RFM_SEGMENTS`         |
| Final product classifications | `ANALYTICS.GENAI_PRODUCT_CLASSIFICATIONS` |

The remaining business-ready Snowflake views are created using the numbered scripts in the `sql/` directory.

## Files Included in GitHub

Smaller analytical and validation outputs may be included in the repository when they are useful for reviewing the project.

Examples include:

* Cleaning-validation summaries
* Aggregated revenue outputs
* Customer-segment summaries
* Cohort-retention summaries
* Product-category summaries
* Final classification outputs, if they remain within GitHub’s file-size limits

## Files Excluded from GitHub

The following files should remain excluded through `.gitignore`:

* Original raw Excel workbook
* Large cleaned transaction files
* Temporary classification checkpoints
* Intermediate recovery files
* Notebook checkpoint files
* Environment and credential files

The `.env` file must never be committed because it may contain private environment variables or credentials.

## Reproducing the Data Pipeline

1. Download the Online Retail II workbook.

2. Save it as:

   ```text
   data/raw/online_retail_II.xlsx
   ```

3. Install the required Python packages:

   ```bash
   pip install -r requirements.txt
   ```

4. Install Ollama and download the local model:

   ```bash
   ollama pull qwen3:4b
   ```

5. Run the notebooks sequentially from `01` through `06`.

6. Review the generated files in `data/processed/`.

7. Load the required cleaned and analytical outputs into Snowflake.

8. Run the SQL scripts in numerical order.
