# Data Quality Audit — Findings & Resolution Log

**Scope:** 4 raw source files loaded into staging (59,606 total rows).
**Method:** systematic SQL checks in `02_audit_queries.sql` — duplicates → referential integrity → format validity → business rules → financial reconciliation.
**Result:** 11 anomaly types found; the revenue gap flagged by Finance is fully explained (to €0.00).

## Findings

| # | Anomaly | Table | Count | Financial impact | Root cause (assessed) | Resolution |
|---|---------|-------|-------|-----------------|----------------------|------------|
| 1 | Exact duplicate user rows | users | 25 ids / 50 rows | — | Failed dedup in CRM export | Deduplicated on user_id |
| 2 | Mixed date formats (`DD.MM.YYYY` + ISO) | users | 125 rows | — | Two upstream forms, DE locale | Normalised with `TRY_CONVERT(date, …, 104)` |
| 3 | Impossible birth years (1900, 2019) | users | 4 rows | — | Form default / typo | Set to NULL, flagged |
| 4 | Missing emails (empty string, not NULL) | users | 62 rows | — | Optional field at signup | Converted `''` → NULL |
| 5 | Duplicate ride_ids — **all 240 rows dated 2026-03-15** | rides | 120 ids / 240 rows | Revenue overstated **€2,805** | Ingestion job for 2026-03-15 ran twice (ETL re-run) | Kept first occurrence per ride_id |
| 6 | Orphan rides (user_id not in users) | rides | 60 rows | €1,123 unattributable | Deleted/test accounts in U09xxx range | Excluded from customer analysis; escalate to engineering |
| 7 | Missing distance_km | rides | 493 rows | — | GPS signal failures | Kept as NULL; excluded from distance metrics only |
| 8 | Negative fares on *completed* rides | rides | 150 rows | −€3,390 | Refunds coded into fare column | Reclassified as refunds; excluded from gross revenue |
| 9 | Cancelled rides charged above the €8.50 cancellation-fee cap | rides | 271 rows | €4,280 | Mislabelled status or wrong charge logic | Flagged for ops review; excluded from completed revenue |
| 10 | **Completed rides with no payment record** | payments | 346 rides | **€7,682 uncollected** | Payment capture failures | Quantified & escalated to Finance — recoverable |
| 11 | Double-charged rides (two payments, same ride) | payments | 279 rides | **€6,681 over-collected** | Payment retry without idempotency check | Quantified & escalated — refund + chargeback risk |

## The reconciliation (Finance's question, answered)

Finance flagged that ride revenue and collected payments don't match. The decomposition below explains the gap **completely**:

| Line item | EUR |
|---|---:|
| Raw completed-rides revenue | 632,590.36 |
| (−) duplicate rides from ETL re-run | −2,804.91 |
| (−) refunds coded as negative fares | +3,389.99 * |
| (−) completed rides never charged | −7,682.17 |
| (+) double-charged payments | +6,680.54 |
| **= Reconciled rides-side total** | **632,173.81** |
| **Payments total (actual)** | **632,173.81** |
| **Remaining unexplained gap** | **0.00** |

\* negative fares subtract a negative, i.e. add back €3,389.99.

## Priority actions handed to stakeholders

1. **Finance:** recover the €7,682 in uncollected fares (346 rides, list provided); refund €6,681 of double charges proactively before chargebacks arrive.
2. **Engineering:** add an idempotency key to the payment retry logic; add a unique constraint on ride_id at ingestion to make ETL re-runs safe.
3. **Data team:** move refunds out of the fare column into a proper refunds table; enforce ISO dates at the form level.
