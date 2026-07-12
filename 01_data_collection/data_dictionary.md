# Data Dictionary — Raw Files

Four raw CSV extracts, as delivered by the (simulated) source systems. Loaded as-is into staging tables; no cleaning applied before the audit.

## users_raw.csv (2,025 rows)
| Column | Description | Known issues (found in audit) |
|--------|-------------|-------------------------------|
| user_id | Customer identifier, format U##### | Duplicate rows present |
| signup_date | Registration date | **Mixed formats**: `YYYY-MM-DD` and `DD.MM.YYYY` |
| city | Home city (5 German cities) | — |
| acquisition_channel | First-touch marketing channel | — |
| birth_year | Year of birth | Impossible values (1900, 2019) |
| email | Contact email | Missing for ~3% of users |

## rides_raw.csv (30,180 rows)
| Column | Description | Known issues |
|--------|-------------|--------------|
| ride_id | Ride identifier, format R###### | Duplicates clustered on one date (ETL re-run) |
| user_id | FK → users | Orphan IDs that exist in no user record |
| ride_date | Date of ride | — |
| city | City of ride | — |
| distance_km | Trip distance | NULL/empty (~1.5%, GPS failures) |
| fare_amount | Fare in EUR | Negative values (refunds coded into fares); full fares on some *cancelled* rides |
| payment_method | card / paypal / apple_pay / cash | — |
| status | completed / cancelled | — |

## payments_raw.csv (27,389 rows)
| Column | Description | Known issues |
|--------|-------------|--------------|
| payment_id | Payment identifier | — |
| ride_id | FK → rides | Some completed rides have **no** payment; some have **two** |
| amount | Amount charged (EUR) | — |
| payment_date | Charge date | — |

## campaigns_raw.csv (12 rows)
| Column | Description |
|--------|-------------|
| campaign_id | C### |
| campaign_name | Campaign label |
| channel | Marketing channel |
| start_date / end_date | Campaign window |
| budget_eur | Budget in EUR |
| target_city | Target city or ALL |
