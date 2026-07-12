/* ============================================================
   VeloRide CRM — Step 03: Build the clean layer
   Applies every resolution from audit_findings.md.
   Staging tables stay untouched (audit trail preserved).
   ============================================================ */
USE VeloRideCRM;
GO

/* ---------- dim_users ---------- */
IF OBJECT_ID('dim_users') IS NOT NULL DROP TABLE dim_users;

WITH dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY (SELECT NULL)) AS rn
    FROM stg_users
)
SELECT
    user_id,
    /* fix mixed formats: style 104 = DD.MM.YYYY, fallback ISO */
    COALESCE(
        TRY_CONVERT(date, signup_date, 104),
        TRY_CONVERT(date, signup_date, 23)
    )                                            AS signup_date,
    city,
    acquisition_channel,
    /* impossible birth years -> NULL */
    CASE WHEN TRY_CAST(birth_year AS INT) BETWEEN 1930 AND 2008
         THEN TRY_CAST(birth_year AS INT) END    AS birth_year,
    /* empty strings -> NULL */
    NULLIF(LTRIM(RTRIM(email)), '')              AS email
INTO dim_users
FROM dedup
WHERE rn = 1;                 -- resolution for finding #1
GO

/* ---------- fact_rides ---------- */
IF OBJECT_ID('fact_rides') IS NOT NULL DROP TABLE fact_rides;

WITH dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY ride_id ORDER BY (SELECT NULL)) AS rn
    FROM stg_rides
)
SELECT
    d.ride_id,
    d.user_id,
    TRY_CONVERT(date, d.ride_date, 23)                    AS ride_date,
    d.city,
    TRY_CAST(NULLIF(d.distance_km,'') AS DECIMAL(6,1))    AS distance_km,
    TRY_CAST(d.fare_amount AS DECIMAL(10,2))              AS fare_amount,
    d.payment_method,
    d.status,
    /* flags carry the audit into analysis without deleting data */
    CASE WHEN u.user_id IS NULL THEN 1 ELSE 0 END          AS is_orphan,      -- finding #6
    CASE WHEN d.status='completed'
          AND TRY_CAST(d.fare_amount AS DECIMAL(10,2)) < 0
         THEN 1 ELSE 0 END                                 AS is_refund,      -- finding #8
    CASE WHEN d.status='cancelled'
          AND TRY_CAST(d.fare_amount AS DECIMAL(10,2)) > 8.50
         THEN 1 ELSE 0 END                                 AS is_suspicious_cancel  -- finding #9
INTO fact_rides
FROM dedup d
LEFT JOIN dim_users u ON d.user_id = u.user_id
WHERE d.rn = 1;               -- resolution for finding #5 (ETL re-run)
GO

/* ---------- fact_payments ---------- */
IF OBJECT_ID('fact_payments') IS NOT NULL DROP TABLE fact_payments;

SELECT
    payment_id,
    ride_id,
    TRY_CAST(amount AS DECIMAL(10,2))       AS amount,
    TRY_CONVERT(date, payment_date, 23)     AS payment_date,
    /* flag second+ payment per ride (finding #11) */
    CASE WHEN ROW_NUMBER() OVER (PARTITION BY ride_id
                                 ORDER BY payment_id) > 1
         THEN 1 ELSE 0 END                  AS is_duplicate_charge
INTO fact_payments
FROM stg_payments;
GO

/* ---------- dim_campaigns ---------- */
IF OBJECT_ID('dim_campaigns') IS NOT NULL DROP TABLE dim_campaigns;

SELECT
    campaign_id,
    campaign_name,
    channel,
    TRY_CONVERT(date, start_date, 23)  AS start_date,
    TRY_CONVERT(date, end_date, 23)    AS end_date,
    TRY_CAST(budget_eur AS INT)        AS budget_eur,
    target_city
INTO dim_campaigns
FROM stg_campaigns;
GO

/* ---------- Post-build verification (expected) ----------
   dim_users      =  2,000
   fact_rides     = 30,060   (30,180 - 120 duplicate rows)
   fact_payments  = 27,389
   dim_campaigns  =     12
   date conversion failures  = 0 in every table              */

SELECT 'dim_users' AS tbl, COUNT(*) AS rows_ FROM dim_users
UNION ALL SELECT 'fact_rides', COUNT(*) FROM fact_rides
UNION ALL SELECT 'fact_payments', COUNT(*) FROM fact_payments
UNION ALL SELECT 'dim_campaigns', COUNT(*) FROM dim_campaigns;

SELECT COUNT(*) AS failed_signup_dates FROM dim_users  WHERE signup_date IS NULL;
SELECT COUNT(*) AS failed_ride_dates   FROM fact_rides WHERE ride_date   IS NULL;
GO
