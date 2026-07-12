/* ============================================================
   VeloRide CRM Analysis — Step 01: staging tables + import
   Environment: SQL Server Express (SSMS), database: VeloRideCRM
   Pattern: raw CSV -> staging (all VARCHAR) -> typed clean layer
   Why staging as VARCHAR? The raw data contains mixed date
   formats and empty strings. Importing as text means NOTHING is
   silently lost — every anomaly stays visible for the audit.
   ============================================================ */

USE VeloRideCRM;
GO

IF OBJECT_ID('stg_users') IS NOT NULL DROP TABLE stg_users;
CREATE TABLE stg_users (
    user_id             VARCHAR(20),
    signup_date         VARCHAR(20),
    city                VARCHAR(50),
    acquisition_channel VARCHAR(50),
    birth_year          VARCHAR(10),
    email               VARCHAR(100)
);

IF OBJECT_ID('stg_rides') IS NOT NULL DROP TABLE stg_rides;
CREATE TABLE stg_rides (
    ride_id        VARCHAR(20),
    user_id        VARCHAR(20),
    ride_date      VARCHAR(20),
    city           VARCHAR(50),
    distance_km    VARCHAR(20),
    fare_amount    VARCHAR(20),
    payment_method VARCHAR(20),
    status         VARCHAR(20)
);

IF OBJECT_ID('stg_payments') IS NOT NULL DROP TABLE stg_payments;
CREATE TABLE stg_payments (
    payment_id   VARCHAR(20),
    ride_id      VARCHAR(20),
    amount       VARCHAR(20),
    payment_date VARCHAR(20)
);

IF OBJECT_ID('stg_campaigns') IS NOT NULL DROP TABLE stg_campaigns;
CREATE TABLE stg_campaigns (
    campaign_id   VARCHAR(20),
    campaign_name VARCHAR(100),
    channel       VARCHAR(50),
    start_date    VARCHAR(20),
    end_date      VARCHAR(20),
    budget_eur    VARCHAR(20),
    target_city   VARCHAR(50)
);
GO

/* ---------- IMPORT: adjust folder path to your machine ------
   If BULK INSERT hits a permissions error on SQL Express, use
   right-click DB > Tasks > Import Flat File per CSV instead
   (make sure every column imports as NVARCHAR).               */

BULK INSERT stg_users
FROM 'D:\VeloRideCRM\data\users_raw.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a');

BULK INSERT stg_rides
FROM 'D:\VeloRideCRM\data\rides_raw.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a');

BULK INSERT stg_payments
FROM 'D:\VeloRideCRM\data\payments_raw.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a');

BULK INSERT stg_campaigns
FROM 'D:\VeloRideCRM\data\campaigns_raw.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a');
GO

/* ---------- ROW COUNT CHECK (expected) ----------
   stg_users      =  2,025
   stg_rides      = 30,180
   stg_payments   = 27,389
   stg_campaigns  =     12                          */

SELECT 'stg_users' AS tbl, COUNT(*) AS rows_loaded FROM stg_users
UNION ALL SELECT 'stg_rides', COUNT(*) FROM stg_rides
UNION ALL SELECT 'stg_payments', COUNT(*) FROM stg_payments
UNION ALL SELECT 'stg_campaigns', COUNT(*) FROM stg_campaigns;
GO
