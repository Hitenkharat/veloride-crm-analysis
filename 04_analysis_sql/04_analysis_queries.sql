/* ============================================================
   VeloRide CRM — Step 04: Business Analysis
   Implements the metric definitions from
   03_requirements/requirements_and_specs.md on the clean layer.
   Reporting as-of date: 2026-06-30.
   ============================================================ */
USE VeloRideCRM;
GO

DECLARE @asof DATE = '2026-06-30';

/* ---------- A1: valid ride set (single definition, reused) ----
   completed, positive fare, attributable to a real customer.   */
WITH valid_rides AS (
    SELECT *
    FROM fact_rides
    WHERE status = 'completed'
      AND fare_amount > 0
      AND is_orphan = 0
      AND is_refund = 0
),

/* ---------- A2: per-user activity ---------- */
user_activity AS (
    SELECT
        u.user_id,
        u.acquisition_channel,
        u.city,
        COUNT(v.ride_id)                       AS lifetime_rides,
        SUM(v.fare_amount)                     AS lifetime_revenue,
        MAX(v.ride_date)                       AS last_ride_date,
        CASE WHEN DATEDIFF(day, MAX(v.ride_date), @asof) <= 90
             THEN 1 ELSE 0 END                 AS is_active_90d
    FROM dim_users u
    JOIN valid_rides v ON v.user_id = u.user_id
    GROUP BY u.user_id, u.acquisition_channel, u.city
)

/* ---------- R1: overall activity & churn ----------
   Expected: 2,000 riders; 763 active (38.1%); 1,237 churned    */
SELECT
    COUNT(*)                                    AS users_with_rides,
    SUM(is_active_90d)                          AS active_90d,
    COUNT(*) - SUM(is_active_90d)               AS churned,
    CAST(100.0 * SUM(is_active_90d) / COUNT(*) AS DECIMAL(5,1)) AS active_pct
FROM user_activity;
GO

/* ---------- R2: channel quality ranking ----------
   Expected result (key insight of the project):
     Referral    52.5% active | Google Ads 48.0% | Meta 40.6%
     Organic     33.6%        | TikTok Ads 15.7%  <- churn issue */
DECLARE @asof DATE = '2026-06-30';
WITH valid_rides AS (
    SELECT * FROM fact_rides
    WHERE status='completed' AND fare_amount>0 AND is_orphan=0 AND is_refund=0
),
user_activity AS (
    SELECT u.user_id, u.acquisition_channel,
           COUNT(v.ride_id)   AS lifetime_rides,
           SUM(v.fare_amount) AS lifetime_revenue,
           CASE WHEN DATEDIFF(day, MAX(v.ride_date), @asof) <= 90
                THEN 1 ELSE 0 END AS is_active_90d
    FROM dim_users u
    JOIN valid_rides v ON v.user_id = u.user_id
    GROUP BY u.user_id, u.acquisition_channel
)
SELECT
    acquisition_channel,
    COUNT(*)                                         AS users,
    CAST(100.0*SUM(is_active_90d)/COUNT(*) AS DECIMAL(5,1)) AS active_90d_pct,
    CAST(AVG(1.0*lifetime_rides)  AS DECIMAL(6,1))   AS avg_rides_per_user,
    CAST(AVG(lifetime_revenue)    AS DECIMAL(8,2))   AS avg_revenue_per_user
FROM user_activity
GROUP BY acquisition_channel
ORDER BY active_90d_pct DESC;
GO

/* ---------- Monthly revenue trend (dashboard feed) ---------- */
SELECT
    FORMAT(ride_date, 'yyyy-MM')  AS ride_month,
    COUNT(*)                       AS rides,
    SUM(fare_amount)               AS revenue_eur
FROM fact_rides
WHERE status='completed' AND fare_amount>0 AND is_orphan=0 AND is_refund=0
GROUP BY FORMAT(ride_date, 'yyyy-MM')
ORDER BY ride_month;
GO

/* ---------- Revenue by city (dashboard feed) ---------- */
SELECT
    city,
    COUNT(*)          AS rides,
    SUM(fare_amount)  AS revenue_eur,
    CAST(AVG(fare_amount) AS DECIMAL(6,2)) AS avg_fare
FROM fact_rides
WHERE status='completed' AND fare_amount>0 AND is_orphan=0 AND is_refund=0
GROUP BY city
ORDER BY revenue_eur DESC;
GO

/* ---------- Finance handoff lists (R3 follow-up) ---------- */
-- 346 completed rides never charged (recovery list)
SELECT r.ride_id, r.user_id, r.ride_date, r.fare_amount
FROM fact_rides r
LEFT JOIN fact_payments p ON r.ride_id = p.ride_id
WHERE r.status='completed' AND r.fare_amount>0 AND p.ride_id IS NULL
ORDER BY r.fare_amount DESC;

-- 279 double-charged rides (proactive refund list)
SELECT ride_id,
       COUNT(*)      AS times_charged,
       SUM(amount)   AS total_charged,
       MAX(amount)   AS correct_amount,
       SUM(amount) - MAX(amount) AS to_refund
FROM fact_payments
GROUP BY ride_id
HAVING COUNT(*) > 1
ORDER BY to_refund DESC;
GO
