# Dashboard Spec — VeloRide CRM Overview

One dashboard, four tiles, built on the clean layer (`fact_rides`, `dim_users`, `fact_payments`). Works identically in Tableau or Power BI. Filter every tile to: status = 'completed', fare_amount > 0, is_orphan = 0, is_refund = 0.

## Connection
- Tableau: Connect → Microsoft SQL Server → server `localhost\SQLEXPRESS`, database `VeloRideCRM`.
- Power BI: Get Data → SQL Server → same server/database, Import mode.
- Relate `fact_rides.user_id` → `dim_users.user_id` (many-to-one).

## KPI band (top)
Four big numbers: **2,000** customers · **38.1%** 90-day active rate · **€632.1k** net revenue · **€0.00** reconciliation gap after audit.
(Active rate: calculated field — user is active if MAX(ride_date) ≥ 2026-04-01.)

## Tile 1 — Monthly revenue trend (line chart)
- X: ride_date by month · Y: SUM(fare_amount)
- Annotate 2026-03: "ETL re-run removed (−€2.8k)" to show the audit's effect.

## Tile 2 — 90-day active rate by acquisition channel (bar chart, the hero tile)
- X: acquisition_channel, sorted descending · Y: active rate
- Expected bars: Referral 52.5% · Google Ads 48.0% · Meta Ads 40.6% · Organic 33.6% · TikTok Ads 15.7%
- Color TikTok bar red/orange; add reference line at overall 38.1%.

## Tile 3 — Revenue by city (bar or filled map)
- Five German cities, SUM(fare_amount). Values are close (€125–130k each) — that itself is a finding: no city concentration risk.

## Tile 4 — Payment integrity (two-number tile or small bar pair)
- Uncollected: €7,682 (346 rides) · Double-charged: €6,681 (279 rides)
- Subtitle: "identified in the data quality audit — lists handed to Finance"

## Export for the repo
Save a full-dashboard screenshot as `dashboard_screenshots/dashboard_overview.png` (the README links to exactly this filename). Also export the Tableau workbook (.twbx) or Power BI file (.pbix) into `05_deliverables/`.
