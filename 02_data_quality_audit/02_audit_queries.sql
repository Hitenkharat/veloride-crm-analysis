/* ============================================================
   VeloRide CRM — Step 02: Data Quality Audit
   Each check below corresponds to a finding documented in
   audit_findings.md. Run top to bottom.
   ============================================================ */
USE VeloRideCRM;
GO

/* ---------- CHECK 1: duplicate users -----------------------
   Finding: 25 user_ids appear twice (50 rows) — exact duplicate
   rows, consistent with a failed dedup in the CRM export.     */
SELECT user_id, COUNT(*) AS occurrences
FROM stg_users
GROUP BY user_id
HAVING COUNT(*) > 1
ORDER BY user_id;

/* ---------- CHECK 2: mixed date formats in signup_date ------
   Finding: 125 rows use German format DD.MM.YYYY instead of
   ISO YYYY-MM-DD. Would crash a naive CAST to DATE.           */
SELECT COUNT(*) AS german_format_dates
FROM stg_users
WHERE signup_date LIKE '%.%';

SELECT TOP 5 user_id, signup_date FROM stg_users WHERE signup_date LIKE '%.%';

/* ---------- CHECK 3: impossible birth years -----------------
   Finding: 4 rows with birth_year 1900 or 2019 (customer would
   be 126 or 7 years old). Likely form-default / typo values.  */
SELECT user_id, birth_year
FROM stg_users
WHERE TRY_CAST(birth_year AS INT) < 1930
   OR TRY_CAST(birth_year AS INT) > 2008;

/* ---------- CHECK 4: missing emails --------------------------
   Finding: 62 users with empty-string email (note: empty string,
   not NULL — the export writes '' for missing values).         */
SELECT COUNT(*) AS missing_emails
FROM stg_users
WHERE email IS NULL OR LTRIM(RTRIM(email)) = '';

/* ---------- CHECK 5: duplicate ride_ids ----------------------
   Finding: 120 ride_ids appear twice (240 rows). Crucial detail:
   ALL duplicates carry ride_date 2026-03-15 -> the ingestion job
   for that day ran twice (ETL re-run), it is not random noise.  */
SELECT ride_id, COUNT(*) AS occurrences
FROM stg_rides
GROUP BY ride_id
HAVING COUNT(*) > 1;

-- Root-cause evidence: the duplicates cluster on a single date
SELECT ride_date, COUNT(*) AS duplicate_rows
FROM stg_rides
WHERE ride_id IN (SELECT ride_id FROM stg_rides GROUP BY ride_id HAVING COUNT(*) > 1)
GROUP BY ride_date
ORDER BY duplicate_rows DESC;

-- Revenue impact of the duplicates (~ EUR 2,805 overstated)
SELECT SUM(TRY_CAST(fare_amount AS DECIMAL(10,2))) AS overstated_revenue
FROM (
    SELECT fare_amount,
           ROW_NUMBER() OVER (PARTITION BY ride_id ORDER BY (SELECT NULL)) AS rn
    FROM stg_rides
    WHERE status = 'completed'
) d
WHERE rn > 1;

/* ---------- CHECK 6: orphan rides (referential integrity) ----
   Finding: 60 rides reference user_ids that do not exist in the
   users table (IDs in the U09xxx range) — EUR 1,123 of revenue
   that cannot be attributed to any customer.                   */
SELECT COUNT(*) AS orphan_rides,
       SUM(TRY_CAST(r.fare_amount AS DECIMAL(10,2))) AS orphan_revenue
FROM stg_rides r
LEFT JOIN (SELECT DISTINCT user_id FROM stg_users) u
       ON r.user_id = u.user_id
WHERE u.user_id IS NULL;

/* ---------- CHECK 7: missing distances ------------------------
   Finding: 493 rides with empty distance_km (GPS signal failures
   per ops team). Kept as NULL in the clean layer; excluded from
   distance-based metrics only.                                  */
SELECT COUNT(*) AS missing_distance
FROM stg_rides
WHERE distance_km IS NULL OR LTRIM(RTRIM(distance_km)) = '';

/* ---------- CHECK 8: negative fares on completed rides --------
   Finding: 150 completed rides with negative fares (sum EUR
   -3,390). Refunds are being coded into the fare column instead
   of a separate refunds table. Business rule violation.         */
SELECT COUNT(*) AS negative_fare_rides,
       SUM(TRY_CAST(fare_amount AS DECIMAL(10,2))) AS total_negative
FROM stg_rides
WHERE status = 'completed'
  AND TRY_CAST(fare_amount AS DECIMAL(10,2)) < 0;

/* ---------- CHECK 9: cancelled rides with full fares -----------
   Finding: 271 cancelled rides carry fares above the EUR 8.50
   cancellation-fee ceiling (sum EUR 4,280). Either mislabelled
   status or incorrect charging on cancellations.                */
SELECT COUNT(*) AS cancelled_full_fare,
       SUM(TRY_CAST(fare_amount AS DECIMAL(10,2))) AS amount
FROM stg_rides
WHERE status = 'cancelled'
  AND TRY_CAST(fare_amount AS DECIMAL(10,2)) > 8.50;

/* ---------- CHECK 10: completed rides never charged ------------
   Finding: 346 completed, positive-fare rides have NO payment
   record — EUR 7,682 of revenue leakage. Biggest single finding. */
SELECT COUNT(*) AS unpaid_rides,
       SUM(TRY_CAST(r.fare_amount AS DECIMAL(10,2))) AS uncollected_revenue
FROM (SELECT DISTINCT ride_id, fare_amount, status FROM stg_rides) r
LEFT JOIN stg_payments p ON r.ride_id = p.ride_id
WHERE r.status = 'completed'
  AND TRY_CAST(r.fare_amount AS DECIMAL(10,2)) > 0
  AND p.ride_id IS NULL;

/* ---------- CHECK 11: double-charged rides ---------------------
   Finding: 279 rides have TWO payment records — customers charged
   twice, EUR 6,681 over-collected. Churn and chargeback risk.    */
SELECT COUNT(*) AS double_charged_rides,
       SUM(extra_amount) AS over_collected
FROM (
    SELECT ride_id,
           SUM(TRY_CAST(amount AS DECIMAL(10,2)))
             - MAX(TRY_CAST(amount AS DECIMAL(10,2))) AS extra_amount
    FROM stg_payments
    GROUP BY ride_id
    HAVING COUNT(*) > 1
) d;

/* ---------- FINALE: revenue reconciliation ---------------------
   Finance flagged: rides revenue vs payments do not match.
   This decomposition explains the ENTIRE gap to EUR 0.00.        */
DECLARE @rides_raw   DECIMAL(12,2) = (
    SELECT SUM(TRY_CAST(fare_amount AS DECIMAL(10,2)))
    FROM stg_rides WHERE status = 'completed');

DECLARE @payments    DECIMAL(12,2) = (
    SELECT SUM(TRY_CAST(amount AS DECIMAL(10,2))) FROM stg_payments);

DECLARE @dupes       DECIMAL(12,2) = (
    SELECT SUM(TRY_CAST(fare_amount AS DECIMAL(10,2))) FROM (
        SELECT fare_amount, status,
               ROW_NUMBER() OVER (PARTITION BY ride_id ORDER BY (SELECT NULL)) rn
        FROM stg_rides) x
    WHERE rn > 1 AND status = 'completed');

DECLARE @negatives   DECIMAL(12,2) = (
    SELECT SUM(TRY_CAST(fare_amount AS DECIMAL(10,2)))
    FROM stg_rides
    WHERE status='completed' AND TRY_CAST(fare_amount AS DECIMAL(10,2)) < 0);

DECLARE @unpaid      DECIMAL(12,2) = (
    SELECT SUM(TRY_CAST(r.fare_amount AS DECIMAL(10,2)))
    FROM (SELECT DISTINCT ride_id, fare_amount, status FROM stg_rides) r
    LEFT JOIN stg_payments p ON r.ride_id = p.ride_id
    WHERE r.status='completed'
      AND TRY_CAST(r.fare_amount AS DECIMAL(10,2)) > 0
      AND p.ride_id IS NULL);

DECLARE @double      DECIMAL(12,2) = (
    SELECT SUM(extra) FROM (
        SELECT SUM(TRY_CAST(amount AS DECIMAL(10,2)))
               - MAX(TRY_CAST(amount AS DECIMAL(10,2))) AS extra
        FROM stg_payments GROUP BY ride_id HAVING COUNT(*) > 1) d);

SELECT 'Raw completed-rides revenue'            AS line_item, @rides_raw  AS eur
UNION ALL SELECT '(-) duplicate rides (ETL re-run)',        -@dupes
UNION ALL SELECT '(-) refunds coded as negative fares',     -@negatives
UNION ALL SELECT '(-) completed rides never charged',       -@unpaid
UNION ALL SELECT '(+) double-charged payments',              @double
UNION ALL SELECT '= Reconciled rides-side total',
       @rides_raw - @dupes - @negatives - @unpaid + @double
UNION ALL SELECT 'Payments total (actual)',                  @payments
UNION ALL SELECT 'Remaining unexplained gap',
       (@rides_raw - @dupes - @negatives - @unpaid + @double) - @payments;
GO
