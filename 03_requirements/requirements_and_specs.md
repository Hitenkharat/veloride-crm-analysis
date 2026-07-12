# Business Requirements → Technical Specification

This document translates stakeholder questions (gathered in kickoff sessions with Marketing, Finance and the COO) into precise, testable technical definitions — the working interface between business and IT.

## Stakeholders & their questions

| Stakeholder | Question (as asked, in business language) |
|---|---|
| COO | "Are we actually keeping customers, or just buying new ones?" |
| Marketing Lead | "Which channels bring customers who stay? Where should next quarter's budget go?" |
| Finance Controller | "Ride revenue and collected payments don't match. Why, and by how much?" |
| Ops Manager | "Are cancellations being charged correctly?" |

## Requirement → specification mapping

### R1 — Customer activity & churn (COO)
| | |
|---|---|
| Business requirement | Know how many customers are active vs. churned |
| Metric definition | **Active** = ≥1 completed, positive-fare ride in the 90 days up to the reporting date (2026-06-30). **Churned** = registered user with ≥1 lifetime ride but none in the last 90 days. |
| Data source | `fact_rides` (is_orphan=0, is_refund=0, status='completed', fare>0) joined to `dim_users` |
| Exclusions | Orphan rides; refund rows; cancelled rides |
| Acceptance criteria | Sum of active + churned = all users with ≥1 lifetime ride; single SQL query reproducible |

### R2 — Channel quality (Marketing)
| | |
|---|---|
| Business requirement | Rank acquisition channels by customer *retention*, not just volume |
| Metric definition | 90-day active rate (per R1) grouped by `acquisition_channel`; secondary: avg completed rides per user, revenue per user |
| Acceptance criteria | Every user counted in exactly one channel; channels ranked in the dashboard |

### R3 — Revenue reconciliation (Finance)
| | |
|---|---|
| Business requirement | Explain the gap between ride revenue and collected payments |
| Metric definition | Gap = SUM(fare of completed rides, raw) − SUM(payments). Must be decomposed into named causes until the remainder is €0. |
| Acceptance criteria | Decomposition table sums exactly to the payments total; each component individually queryable; ride-level lists available for recovery (unpaid) and refunds (double-charged) |

### R4 — Cancellation charging (Ops)
| | |
|---|---|
| Business requirement | Verify cancellations are charged per policy |
| Business rule | Cancellation fee ceiling = €8.50 |
| Metric definition | Count and sum of cancelled rides with fare > €8.50 |
| Acceptance criteria | Flagged rides listed with ride_id for case-by-case review |

## Out of scope (agreed with stakeholders)
- Driver-side data (not in the extract)
- Campaign-level attribution beyond first-touch channel
- Forecasting / predictive modelling (phase 2 candidate)

## Change log
| Date | Change | Requested by |
|---|---|---|
| 2026-06-12 | Added €8.50 cancellation ceiling as explicit business rule | Ops |
| 2026-06-20 | Reporting as-of date fixed to 2026-06-30 | Finance |
