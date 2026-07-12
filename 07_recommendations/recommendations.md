# Recommendations — Stakeholder Summary

**To:** COO, Marketing Lead, Finance Controller, Ops Manager
**Re:** Customer retention & revenue reconciliation analysis (data through 2026-06-30)

## The headline

Growth is being rented, not owned. Only **38% of customers who ever rode with us were active in the last 90 days**, and channel quality varies enormously: a Referral customer is **more than 3× as likely to still be active as a TikTok Ads customer** (52.5% vs 15.7%). Meanwhile, the audit found **€14.4k of payment-process errors** — €7.7k never collected and €6.7k collected twice.

## Recommendations

### 1. Marketing — reallocate budget from TikTok to Referral (impact: retention)
TikTok Ads brings users who churn almost immediately (15.7% still active). Referral brings the stickiest customers (52.5%).
**Action:** shift the Black-Week-scale TikTok budget (~€9k/campaign) toward the referral program next quarter; set a channel-level retention KPI (90-day active rate) alongside CPA in every campaign review.

### 2. Finance — recover €7,682 and refund €6,681 (impact: immediate cash + trust)
346 completed rides were never charged; 279 rides were charged twice.
**Action:** run the recovery list (`04_analysis_sql`, Finance handoff query) through payment retry this month. Refund the double charges *proactively* — a refund we initiate costs goodwill nothing; a chargeback the customer initiates costs fees and trust.

### 3. Engineering — make the pipeline safe against the two failure modes we found (impact: prevents recurrence)
The 2026-03-15 ETL re-run silently duplicated a full day of rides (€2.8k overstated revenue); payment retries lack an idempotency check (the double charges).
**Action:** unique constraint on `ride_id` at ingestion; idempotency key on payment capture; refunds moved out of the fare column into a dedicated table.

### 4. Ops — review the 271 cancelled rides charged above the €8.50 cap
Either the status label or the charge is wrong on each of these.
**Action:** case review of the flagged list; if pattern confirms a charging bug, quantify customer remediation.

## What we'd measure next quarter (success criteria)
- 90-day active rate: from 38.1% → target 45%
- Uncollected completed rides: from 1.2% → < 0.1%
- Double-charge incidents: from 279 → 0 after idempotency fix
- Channel mix: share of new users from Referral +10 p.p.

## Phase 2 candidates (out of current scope)
Cohort retention curves by signup month · campaign-level ROI once spend data is connected · churn early-warning based on ride-frequency decay
