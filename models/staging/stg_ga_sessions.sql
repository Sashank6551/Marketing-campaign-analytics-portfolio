-- models/staging/stg_ga_sessions.sql
-- Staging model for Google Analytics sessions data
-- Built: Feb 24, 2025
-- Intentional errors included for debugging practice tomorrow morning

{{ config(
    materialized='view',
    schema='staging'
) }}

WITH source AS (
    -- ERROR 1: Missing date filter - will cause full table scan
    SELECT *
    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
    WHERE _TABLE_SUFFIX BETWEEN '20170701' AND '20170731'
),

renamed AS (
    SELECT
        -- Session identifiers
       CONCAT(fullVisitorId, '-', CAST(visitId AS STRING), '-', date) AS session_id,
        fullVisitorId AS visitor_id,
        visitId AS visit_id,
        
        -- Timestamps
        PARSE_DATE('%Y%m%d', date) AS session_date,
        -- ERROR 2: Wrong function for timestamp conversion
        TIMESTAMP_SECONDS(visitStartTime) AS session_start_timestamp,
        -- Should be: TIMESTAMP_SECONDS(visitStartTime)
        
        -- Traffic source (attribution)
        trafficSource.source AS traffic_source,
        trafficSource.medium AS traffic_medium,
        trafficSource.campaign AS campaign_name,
        trafficSource.keyword AS keyword,
        trafficSource.adContent AS ad_content,
        
        -- Behavior metrics
        totals.visits AS visits,
        totals.hits AS hits,
        totals.pageviews AS pageviews,
        totals.timeOnSite AS time_on_site_seconds,
        totals.bounces AS bounces,
        totals.transactions AS transactions,
        totals.transactionRevenue AS transaction_revenue_micros,
        
        -- Device info
        device.browser AS browser,
        device.deviceCategory AS device_category,
        device.operatingSystem AS operating_system,
        
        -- Geography
        geoNetwork.country AS country,
        geoNetwork.city AS city,
        
        -- Calculated fields
        CASE WHEN totals.bounces = 1 THEN 1 ELSE 0 END AS is_bounced,
        CASE WHEN totals.transactions >= 1 THEN 1 ELSE 0 END AS is_converted,
        
        -- ERROR 3: Division by zero - transactionRevenue can be NULL
        COALESCE(totals.transactionRevenue,0) / 1000000.0 AS revenue_usd
        -- Should be: COALESCE(totals.transactionRevenue, 0) / 1000000.0

    FROM source
    -- ERROR 4: Missing WHERE clause for NULL handling
)

SELECT * FROM renamed

-- DEBUGGING CHECKLIST FOR TOMORROW:
-- [ ] Fix date filter (uncomment WHERE clause in source CTE)
-- [ ] Fix timestamp conversion (use TIMESTAMP_SECONDS)
-- [ ] Add NULL handling for revenue (use COALESCE)
-- [ ] Verify results are reasonable (check row counts, revenue totals)
-- [ ] Test with: dbt run --select stg_ga_sessions
