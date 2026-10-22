# Tableau Dashboards

This folder contains the packaged Tableau workbook for the Customer Revenue & Retention Analytics project.

The dashboards are also published on Tableau Public: [Revenue Overview](https://public.tableau.com/app/profile/aditya.ranjan7019/viz/Customer_Revenue_Retention_Analytics_Snowflake/RevenueOverview) · [Retention Overview](https://public.tableau.com/app/profile/aditya.ranjan7019/viz/Customer_Revenue_Retention_Analytics_Snowflake/RetentionOverview) · [Segment LOD Analysis & Reconciliation (FIXED, INCLUDE, EXCLUDE + Blend)](https://public.tableau.com/app/profile/aditya.ranjan7019/viz/Customer_Revenue_Retention_Analytics_Snowflake_17926845101980/LODAnalysis).

## Workbook

[Download the Tableau workbook](Customer_Revenue_Retention_Analytics_Snowflake.twbx)

```text
Customer_Revenue_Retention_Analytics_Snowflake.twbx
```

## How the Data Reaches Tableau

The dashboards were built against analytical views in the Snowflake `ANALYTICS` layer:

| Setting   | Value                           |
| --------- | ------------------------------- |
| Warehouse | `RETAIL_ANALYTICS_WH`           |
| Database  | `CUSTOMER_REVENUE_RETENTION_DB` |
| Schema    | `ANALYTICS`                     |

Tableau Public does not accept Snowflake connections, so each view was exported to CSV and packaged into the workbook as an extract. The workbook therefore opens without a Snowflake account, and its dashboard figures match the validated Snowflake results below. Percentages in the exported files are rounded to the precision the dashboards display.

## Tableau Data Sources

| Tableau data source    | Exported from Snowflake view |
| ---------------------- | ---------------------------- |
| `monthly_revenue`      | `MART_MONTHLY_REVENUE`       |
| `category_performance` | `MART_CATEGORY_PERFORMANCE`  |
| `customer_segments`    | `MART_CUSTOMER_SEGMENTS`     |
| `cohort_retention`     | `MART_COHORT_RETENTION`      |
| `revenue_kpi_cards`    | `MART_REVENUE_KPI_CARDS`     |
| `retention_kpi_cards`  | `MART_RETENTION_KPI_CARDS`   |
| `customer_rfm_segments` | `CUSTOMER_RFM_SEGMENTS`     |

`customer_rfm_segments` is the RFM output of `notebooks/04_customer_segmentation.ipynb` (`data/processed/analytics/customer_rfm_segments.csv`, 5,852 customers), the same table loaded into Snowflake as `ANALYTICS.CUSTOMER_RFM_SEGMENTS`. It feeds only the LOD dashboard, where it is also blended with `customer_segments` (see below).

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

### Customer Segments: FIXED, INCLUDE & EXCLUDE LOD + Data Blend

Added after the first two dashboards and published as a separate view: [Customer Segment Revenue Share (FIXED LOD)](https://public.tableau.com/app/profile/aditya.ranjan7019/viz/Customer_Revenue_Retention_Analytics_Snowflake_17926845101980/LODAnalysis).

It contains five sheets:

* **Segment Share (LOD):** each customer segment's share of total net revenue.
* **Vs Country Average (LOD):** the number of customers in each segment whose net revenue is above or at/below the average for their own primary country.
* **Segment Reconciliation (Blend):** the LOD segment share next to the share from the Snowflake segment mart, with the difference between them.
* **Avg Revenue per Country (INCLUDE):** each segment's average net revenue per country it sells in.
* **UK Share of Segment Revenue (EXCLUDE):** each segment's revenue split between the UK and outside the UK.

| Calculation | Formula |
| --- | --- |
| Segment Revenue (LOD) | `{ FIXED [customer_segment] : SUM([net_monetary_value]) }` |
| Segment Revenue Share (LOD) | `[Segment Revenue (LOD)] / { FIXED : SUM([net_monetary_value]) }` |
| Country Avg Revenue (LOD) | `{ FIXED [primary_country] : AVG([net_monetary_value]) }` |
| Vs Country Average | `IF [net_monetary_value] > [Country Avg Revenue (LOD)] THEN "Above country average" ELSE "At or below country average" END` |
| Country Revenue (INCLUDE) | `{ INCLUDE [primary_country] : SUM([net_monetary_value]) }`, shown as AVG at segment level |
| Country Group | `IF [primary_country] = "United Kingdom" THEN "UK" ELSE "Outside UK" END` |
| Share of Segment Revenue (EXCLUDE) | `SUM([net_monetary_value]) / MIN({ EXCLUDE [Country Group] : SUM([net_monetary_value]) })` |
| Difference (LOD vs Snowflake) | `SUM([Segment Revenue Share (LOD)]) - SUM([customer_segments].[Net Revenue Share Pct])` |

Results: Champions hold 74.04% of net revenue (matching the RFM analysis in notebook 04), and 994 of the 1,448 Champions are above their country's average.

#### INCLUDE and EXCLUDE

The INCLUDE view is at segment level; INCLUDE adds country underneath, and the sheet averages those country totals back to segment. The EXCLUDE view is segment × Country Group; EXCLUDE removes Country Group to give each segment's total, read with MIN because the value repeats on every row. Countries are grouped into UK and Outside UK instead of filtered, because INCLUDE and EXCLUDE respect dimension filters (FIXED does not): a UK-only filter would make every share 100%.

| Segment | Country values | Avg net revenue per country (INCLUDE) | UK share of segment revenue (EXCLUDE) |
| --- | ---: | ---: | ---: |
| Champions | 22 | £549,312 | 82.23% |
| Loyal Customers | 11 | £77,752 | 92.68% |
| At Risk | 25 | £62,673 | 87.97% |
| Potential Loyalists | 21 | £42,192 | 81.95% |
| Hibernating | 29 | £17,650 | 89.84% |
| Need Attention | 15 | £14,108 | 84.28% |
| High-Value Active | 6 | £7,804 | 45.70% |
| Promising Customers | 14 | £6,752 | 79.38% |
| New Customers | 11 | £3,713 | 86.23% |
| Regular Customers | 8 | £2,796 | 86.44% |

"Country values" counts the distinct `primary_country` values in each segment; a few segments include the dataset's `Unspecified` or `European Community` labels, which INCLUDE treats like any other value. Both results were checked against the same aggregation in Python on `customer_rfm_segments.csv`, and every value matched. High-Value Active is the only segment with most of its revenue (54.30%) outside the UK.

#### Data blend

| Setting | Value |
| --- | --- |
| Primary source | `customer_rfm_segments` (customer-level Python RFM output, 5,852 rows) |
| Secondary source | `customer_segments` (segment-level export of Snowflake `MART_CUSTOMER_SEGMENTS`, 10 rows) |
| Linking field | Customer Segment |

The two sources sit at different grains (one row per customer vs one row per segment), so they are blended rather than joined: Tableau aggregates the secondary source to the linking field and matches it to each segment in the view. `Difference (LOD vs Snowflake)` is created in the primary source and references the secondary field.

| Segment | LOD share (Python RFM table) | Snowflake mart share | Difference |
| --- | ---: | ---: | ---: |
| Champions | 74.04% | 74.00% | 0.04% |
| At Risk | 9.60% | 9.60% | 0.00% |
| Potential Loyalists | 5.43% | 5.40% | 0.03% |
| Loyal Customers | 5.24% | 5.20% | 0.04% |
| Hibernating | 3.14% | 3.10% | 0.04% |
| Need Attention | 1.30% | 1.30% | 0.00% |
| Promising Customers | 0.58% | 0.60% | -0.02% |
| High-Value Active | 0.29% | 0.30% | -0.01% |
| New Customers | 0.25% | 0.30% | -0.05% |
| Regular Customers | 0.14% | 0.10% | 0.04% |

Every difference is within ±0.05 percentage points. The Snowflake export stores these shares rounded to 3 decimals (for example 0.740 for Champions against 0.7404 computed in Tableau), so the gaps are rounding and the two sources agree. The LOD shares total 100.00% and the exported shares 99.90%.

![Segment Revenue Share and Country Benchmark](../screenshots/tableau_lod_analysis.png)

## Tableau Cloud Deployment (Practice)

The workbook was also published to a personal Tableau Cloud developer site to practise deployment and permissions. The site is a private sandbox, so there is no public link.

| Setting | Value |
| --- | --- |
| Project | Retail Analytics |
| Groups | Analysts (Site Administrator Creator, Publish template) and Viewers (Viewer site role, View template) |
| Workbook rule for Viewers | View template with Download Summary Data set to Denied |
| Asset permissions | Locked to the project, including nested projects |

Effective permissions for the viewer: view, filter, comment and download image/PDF; no summary or full data download, no underlying data, no web edit and no workbook download. This was checked by signing in as the viewer: the Download menu offered only Image, Vector Image, PDF and PowerPoint, and the toolbar had no Edit option.

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
3. Open `Customer_Revenue_Retention_Analytics_Snowflake.twbx`. No sign-in is needed, because the data is packaged inside the workbook.

## Tools

* Tableau Desktop
* Tableau Public
* Snowflake
* Snowflake SQL
* Python and Pandas
* Ollama and Qwen3:4B
