-- models/intermediate/int_funnel_steps.sql
-- Conversion funnel analysis: Track user journey through conversion stages
-- Stages: Landing → Engagement → Conversion

{{ config(
    materialized='ephemeral',
    schema='intermediate'
) }}

WITH session_base AS (
    SELECT
        session_id,
        visitor_id,
        session_date,
        session_start_timestamp,
        traffic_source,
        traffic_medium,
        campaign_name,
        device_category,
        country,
        
        -- Metrics
        hits,
        pageviews,
        time_on_site_seconds,
        is_bounced,
        is_converted,
        revenue_usd,
        transactions
        
    FROM {{ ref('stg_ga_sessions') }}
),

funnel_classification AS (
    SELECT
        *,
        
        -- Funnel Stage 1: Landing (all sessions)
        1 AS reached_landing,
        
        -- Funnel Stage 2: Engagement (did not bounce, viewed multiple pages)
        CASE 
            WHEN is_bounced = 0 AND pageviews > 1 THEN 1 
            ELSE 0 
        END AS reached_engagement,
        
        -- Funnel Stage 3: Deep Engagement (spent time + multiple pageviews)
        CASE 
            WHEN is_bounced = 0 
                AND pageviews >= 3 
                AND COALESCE(time_on_site_seconds, 0) > 60 
            THEN 1 
            ELSE 0 
        END AS reached_deep_engagement,
        
        -- Funnel Stage 4: Conversion
        CASE 
            WHEN is_converted = 1 THEN 1 
            ELSE 0 
        END AS reached_conversion,
        
        -- Calculate drop-off points
        CASE
            WHEN is_bounced = 1 THEN 'bounced_at_landing'
            WHEN pageviews <= 1 THEN 'dropped_after_landing'
            WHEN pageviews >= 2 AND pageviews < 3 THEN 'dropped_at_engagement'
            WHEN pageviews >= 3 AND is_converted = 0 THEN 'dropped_at_deep_engagement'
            WHEN is_converted = 1 THEN 'converted'
            ELSE 'other'
        END AS funnel_exit_stage,
        
        -- Engagement quality score (0-100)
        LEAST(100, 
            CAST(pageviews AS FLOAT64) * 10 + 
            CAST(COALESCE(time_on_site_seconds, 0) AS FLOAT64) / 10
        ) AS engagement_score
        
    FROM session_base
),

visitor_journey AS (
    -- Aggregate to visitor level for multi-session analysis
    SELECT
        visitor_id,
        COUNT(DISTINCT session_id) AS total_sessions,
        SUM(reached_landing) AS sessions_at_landing,
        SUM(reached_engagement) AS sessions_at_engagement,
        SUM(reached_deep_engagement) AS sessions_at_deep_engagement,
        SUM(reached_conversion) AS sessions_with_conversion,
        MAX(is_converted) AS ever_converted,
        SUM(revenue_usd) AS total_revenue,
        AVG(engagement_score) AS avg_engagement_score,
        MIN(session_date) AS first_session_date,
        MAX(session_date) AS last_session_date
    FROM funnel_classification
    GROUP BY visitor_id
)

SELECT
    f.*,
    v.total_sessions AS visitor_total_sessions,
    v.sessions_at_engagement AS visitor_sessions_at_engagement,
    v.sessions_with_conversion AS visitor_conversions,
    v.ever_converted AS visitor_ever_converted,
    v.total_revenue AS visitor_total_revenue,
    v.avg_engagement_score AS visitor_avg_engagement_score,
    DATE_DIFF(v.last_session_date, v.first_session_date, DAY) AS visitor_days_active
FROM funnel_classification f
LEFT JOIN visitor_journey v ON f.visitor_id = v.visitor_id
