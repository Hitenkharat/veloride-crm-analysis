# Validation & UAT — Test Cases and Results

Purpose: verify the clean layer and analysis outputs against the acceptance criteria defined in `03_requirements/requirements_and_specs.md` before stakeholder sign-off. Every test is a runnable SQL check; expected values were locked before the cleaning scripts were finalised.

**Environment:** SQL Server Express · database `VeloRideCRM` · as-of date 2026-06-30
**Result: 12 / 12 passed.**

| ID | Test case | Steps | Expected | Actual | Status |
|----|-----------|-------|----------|--------|--------|
| T01 | Staging row counts match source files | `COUNT(*)` per stg_ table | 2,025 / 30,180 / 27,389 / 12 | 2,025 / 30,180 / 27,389 / 12 | ✅ |
| T02 | dim_users has no duplicate user_id | `GROUP BY user_id HAVING COUNT(*)>1` | 0 rows | 0 rows | ✅ |
| T03 | dim_users row count = distinct source users | 2,025 staged − 25 duplicates | 2,000 | 2,000 | ✅ |
| T04 | All signup dates parsed (incl. 125 German-format) | `WHERE signup_date IS NULL` | 0 | 0 | ✅ |
| T05 | fact_rides has no duplicate ride_id | dup check on ride_id | 0 rows | 0 rows | ✅ |
| T06 | fact_rides row count | 30,180 − 120 ETL duplicates | 30,060 | 30,060 | ✅ |
| T07 | Orphan flags match audit finding #6 | `SUM(is_orphan)` | 60 | 60 | ✅ |
| T08 | Refund flags match audit finding #8 | `SUM(is_refund)` | 150 | 150 | ✅ |
| T09 | Suspicious-cancel flags match finding #9 | `SUM(is_suspicious_cancel)` | 271 | 271 | ✅ |
| T10 | Reconciliation closes | decomposition query, final line | €0.00 | €0.00 | ✅ |
| T11 | Active + churned = all riders (R1 acceptance) | 763 + 1,237 | 2,000 | 2,000 | ✅ |
| T12 | Every user in exactly one channel (R2 acceptance) | users across channel rows | 2,000 | 2,000 | ✅ |

## Defect log

| ID | Defect found during testing | Severity | Resolution |
|----|------------------------------|----------|-----------|
| D01 | First version of the cleaning script used `CAST` instead of `TRY_CONVERT` with style 104 — 125 German-format dates failed conversion | High | Rewrote date handling with `COALESCE(TRY_CONVERT(…,104), TRY_CONVERT(…,23))`; T04 re-run, passed |
| D02 | Initial reconciliation left a residual gap — negative fares had been subtracted with the wrong sign | Medium | Corrected sign convention; T10 re-run, closes to €0.00 |

## Sign-off criteria
- All 12 test cases pass on a fresh end-to-end run (import → clean → analysis)
- Reconciliation closes to €0.00
- Finance receives the two handoff lists (unpaid rides, double charges) with row counts matching T-findings #10 and #11
