# VeloRide — Ride-Hailing CRM Analytics (SQL + Tableau + Excel)

**End-to-end business \& data analysis: from raw, messy CSV extracts to a cleaned SQL database, a fully-explained revenue reconciliation, dashboards, and stakeholder recommendations.**

> \*\*Note on the data:\*\* VeloRide is a fictional ride-hailing company. This is a synthetic dataset modelled on the CRM structure of real ride-hailing services (FreeNow, Uber, Bolt): users, rides, payments, and campaigns. Realistic data quality problems — duplicates, mixed date formats, orphan records, payment mismatches — are present in the raw files exactly as they occur in production systems. All findings were discovered and resolved using SQL.

\---

## 1\. Business Problem

VeloRide's revenue is growing, but management suspects growth is driven by new-user acquisition while existing customers quietly churn. Finance has also flagged that **ride revenue and collected payments do not reconcile**.

Stakeholder questions this project answers:

1. How many of our customers are still active, and which segments are churning? *(COO)*
2. Which acquisition channels bring customers who actually stay? *(Marketing)*
3. Why don't ride revenue and payment totals match? *(Finance)*
4. Are cancellations being charged correctly? *(Ops)*

## 2\. Key Findings

* **Only 38.1% of customers who ever rode are still active** (≥1 ride in the last 90 days) — the churn suspicion is confirmed.
* **Channel quality varies 3.4×:** Referral customers stay active at **52.5%**, TikTok Ads customers at just **15.7%**. Budget is buying users who leave.
* **€7,682 of completed rides were never charged** (346 rides — payment capture failures) and **€6,681 was double-charged** (279 rides). Both lists handed to Finance.
* **The revenue gap Finance flagged is fully explained** — a five-line decomposition (ETL-duplicated rides, refunds coded as negative fares, unpaid rides, double charges) closes the gap to **€0.00**.
* Root cause of the duplicate rides: **the ingestion job for 2026-03-15 ran twice** — all 240 duplicate rows carry that single date.

## 3\. Approach (End-to-End)

|Step|What was done|Where|
|-|-|-|
|Data collection|4 raw CSVs → SQL Server staging tables (all VARCHAR — nothing silently lost)|[`01\_data\_collection/`](01_data_collection/)|
|Data quality audit|11 anomaly types found, quantified, resolved with SQL|[`02\_data\_quality\_audit/`](02_data_quality_audit/)|
|Requirements|Stakeholder questions → testable metric definitions \& specs|[`03\_requirements/`](03_requirements/)|
|Analysis|Retention, channel quality, revenue reconciliation (commented T-SQL)|[`04\_analysis\_sql/`](04_analysis_sql/)|
|Deliverables|Excel executive summary + dashboard|[`05\_deliverables/`](05_deliverables/)|
|Validation (UAT)|12 test cases + defect log, all passing|[`06\_validation\_uat/`](06_validation_uat/)|
|Recommendations|One-page action plan per stakeholder|[`07\_recommendations/`](07_recommendations/)|

**Tools:** SQL Server Express (T-SQL) · Tableau / Power BI · Excel

## 4\. Data Quality Audit — highlights

Full findings \& resolution log: [`02\_data\_quality\_audit/audit\_findings.md`](02_data_quality_audit/audit_findings.md)

|#|Anomaly|Impact|Resolution|
|-|-|-|-|
|5|240 duplicate ride rows, **all dated 2026-03-15**|Revenue overstated €2,805|Root cause: ETL re-run; deduplicated on ride\_id|
|10|Completed rides with no payment record|**€7,682 uncollected**|Recovery list to Finance|
|11|Rides charged twice|**€6,681 over-collected**|Proactive refund list to Finance|
|2|Mixed date formats (ISO + DD.MM.YYYY)|Dates unparseable|`TRY\_CONVERT` style 104 during typing|
|…|*7 more findings*||*see full log*|

## 5\. Dashboard

\*Dashboard in progress — build spec in \[`05\_deliverables/dashboard\_spec.md`](05\_deliverables/dashboard\_spec.md). 

\\Screenshot coming in the next commit.\*6. Repository Structure

```
├── 01\_data\_collection/     raw CSVs, import script, data dictionary
├── 02\_data\_quality\_audit/  audit queries, findings log, cleaning script
├── 03\_requirements/        business requirements -> technical specs
├── 04\_analysis\_sql/        commented analysis queries
├── 05\_deliverables/        Excel summary, dashboard spec, screenshots
├── 06\_validation\_uat/      12 UAT test cases + defect log
└── 07\_recommendations/     stakeholder action plan
```

## 7\. How to Reproduce

1. Create a database named `VeloRideCRM` in SQL Server.
2. Run `01\_data\_collection/01\_create\_and\_import.sql` (adjust the CSV folder path). Expect 2,025 / 30,180 / 27,389 / 12 rows.
3. Run `02\_data\_quality\_audit/02\_audit\_queries.sql` — every finding is a numbered check.
4. Run `02\_data\_quality\_audit/03\_build\_clean\_layer.sql`. Expect 2,000 / 30,060 / 27,389 / 12.
5. Run `04\_analysis\_sql/04\_analysis\_queries.sql`.
6. Open the Excel summary in `05\_deliverables/`; connect Tableau/Power BI to the clean tables per the dashboard spec.

\---

*Author: Hiten Kharat — MSc Data Analytics, Berlin School of Business and Innovation ·* [*LinkedIn*](https://www.linkedin.com/in/hiten-kharat067862109)

