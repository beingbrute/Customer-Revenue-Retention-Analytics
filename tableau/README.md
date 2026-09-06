# Tableau Dashboards

This folder contains the final packaged Tableau workbook for the Customer Revenue & Retention Analytics project.

The workbook uses analytical views created in Snowflake. The original CSV data sources were removed after the Snowflake migration and dashboard results were validated.

## Workbook

[Download the Tableau workbook](Customer_Revenue_Retention_Analytics_Snowflake.twbx)

```text
Customer_Revenue_Retention_Analytics_Snowflake.twbx
```

## Snowflake Connection

The Tableau workbook connects to:

| Setting         | Value                           |
| --------------- | ------------------------------- |
| Warehouse       | `RETAIL_ANALYTICS_WH`           |
| Database        | `CUSTOMER_REVENUE_RETENTION_DB` |
| Schema          | `ANALYTICS`                     |
| Connection mode | Extract                         |

Snowflake login credentials are not stored in the repository.

## Tableau Data Sources

The workbook uses six Snowflake data sources:

| Tableau data source       | Snowflake analytical view   |
| ------------------------- | --------------------------- |
| `SF_Monthly_Revenue`      | `MART_MONTHLY_REVENUE`      |
| `SF_Category_Performance` | `MART_CATEGORY_PERFORMANCE` |
| `SF_Customer_Segments`    | `MART_CUSTOMER_SEGMENTS`    |
| `SF_Cohort_Retention`     | `MART_COHORT_RETENTION`     |
| `SF_Revenue_KPI_Cards`    | `MART_REVENUE_KPI_CARDS`    |
| `SF_Retention_KPI_Cards`  | `MART_RETENTION_KPI_CARDS`  |

The six previous CSV-based data sources were closed after the Snowflake replacements were validated.

## Dashboards

### Revenue Overview

The Revenue Overview dashboard presents the project’s primary commercial performance indicators.

It includes:

* Gross merchandise sales
* Estimated net revenue
* Sales invoice count
* Known customer count
* Cancellation rate
* Complete-month estimated net revenue trend
* Estimated net revenue by product category

The monthly trend excludes the final partial month to prevent an incomplete reporting period from being compared directly with complete months.

![Revenue Overview](../screenshots/tableau_revenue_overview.png)

### Retention Overview

The Retention Overview dashboard presents customer-segment performance and post-acquisition retention.

It includes:

* Month 2 weighted retention
* Month 3 weighted retention
* Month 6 weighted retention
* Month 12 weighted retention
* Net-revenue share by customer segment
* Customer cohort-retention heatmap
* Retention-percentage colour legend

The cohort heatmap includes only periods each cohort was old enough to reach.

![Retention Overview](../screenshots/tableau_retention_overview.png)

## Validated Dashboard KPIs

### Revenue KPIs

| KPI                     |         Result |
| ----------------------- | -------------: |
| Gross merchandise sales | £19,604,891.64 |
| Estimated net revenue   | £18,888,429.07 |
| Sales invoices          |         39,515 |
| Known customers         |          5,852 |
| Cancellation rate       |          3.65% |

### Retention KPIs

| Retention period | Weighted retention |
| ---------------- | -----------------: |
| Month 2          |             23.04% |
| Month 3          |             23.29% |
| Month 6          |             21.75% |
| Month 12         |             21.65% |

## Opening the Workbook

1. Install Tableau Desktop or Tableau Public.
2. Download the packaged workbook from this folder.
3. Open `Customer_Revenue_Retention_Analytics_Snowflake.twbx`.
4. Sign in to Snowflake if Tableau requests authentication.
5. Select `RETAIL_ANALYTICS_WH` if a warehouse selection is required.
6. Refresh the extracts if access to the Snowflake database is available.

The packaged extracts allow the dashboard results to remain visible even when the viewer does not have access to the original Snowflake account.

## Tools

* Tableau Desktop
* Tableau Public
* Snowflake
* Snowflake SQL
* Python and Pandas
* Ollama and Qwen3:4B
