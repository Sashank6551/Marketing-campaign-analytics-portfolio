-- models/marts/campaign_performance/mart_campaign_performance.sql
-- Campaign performance metrics including ROAS and CAC
-- Final table for dashboard consumption

{{ config(
    materialized='table',
    schema='campaign_performance'
) }}

WITH campaign_data AS (
    SELECT
        traffic_source,
        traffic_medium,
        campaign_name,
        campaign_identifier,
        channel_grouping,
        device_category,
        
        -- Aggregate across dates
        SUM(sessions) AS total_sessions,
        SUM(unique_visitors) AS total_unique_visitors,
        SUM(total_pageviews) AS total_pageviews,
        SUM(bounces) AS total_bounces,
        SUM(conversions) AS total_conversions,
        SUM(revenue) AS total_revenue,
        
        -- Weighted averages
        SUM(sessions * bounce_rate_pct) / SUM(sessions) AS avg_bounce_rate_pct,
        SUM(sessions * conversion_rate_pct) / SUM(sessions) AS avg_conversion_rate_pct,
        SUM(sessions * avg_time_on_site) / SUM(sessions) AS avg_time_on_site_sec,
        SUM(sessions * avg_pageviews_per_session) / SUM(sessions) AS avg_pageviews_per_session
        
    FROM {{ ref('int_campaign_metrics') }}
    GROUP BY 
        traffic_source,
        traffic_medium,
        campaign_name,
        campaign_identifier,
        channel_grouping,
        device_category
),

calculated_metrics AS (
    SELECT
        *,
        
        -- Performance metrics
        ROUND(SAFE_DIVIDE(total_revenue, total_sessions), 2) AS revenue_per_session,
        ROUND(SAFE_DIVIDE(total_revenue, total_conversions), 2) AS revenue_per_conversion,
        ROUND(SAFE_DIVIDE(total_sessions, total_unique_visitors), 2) AS sessions_per_visitor,
        ROUND(SAFE_DIVIDE(total_conversions, total_sessions) * 100, 2) AS conversion_rate_pct,
        ROUND(SAFE_DIVIDE(total_bounces, total_sessions) * 100, 2) AS bounce_rate_pct,
        
        -- Engagement quality score (0-100)
        ROUND(
            (100 - SAFE_DIVIDE(total_bounces, total_sessions) * 100) * 0.4 +  -- 40% weight on non-bounce
            LEAST(100, avg_pageviews_per_session * 10) * 0.3 +                 -- 30% weight on pageviews
            LEAST(100, avg_time_on_site_sec / 6) * 0.3,                        -- 30% weight on time
        1) AS engagement_quality_score
        
    FROM campaign_data
),

-- Note: In real scenario, you'd join cost data here
-- For now, we'll create placeholder ROAS/CAC calculations
with_roas_cac AS (
    SELECT
        *,
        
        -- Placeholder: Assuming $1 cost per session for paid channels
        CASE 
            WHEN channel_grouping = 'Paid Search' THEN total_sessions * 1.0
            WHEN channel_grouping = 'Social' AND traffic_medium = 'cpc' THEN total_sessions * 0.5
            ELSE 0
        END AS estimated_cost,
        
        -- ROAS = Revenue / Cost (only for paid channels)
        CASE 
            WHEN channel_grouping IN ('Paid Search', 'Social') AND traffic_medium = 'cpc' THEN
                ROUND(SAFE_DIVIDE(
                    total_revenue,
                    CASE 
                        WHEN channel_grouping = 'Paid Search' THEN total_sessions * 1.0
                        ELSE total_sessions * 0.5
                    END
                ), 2)
            ELSE NULL
        END AS roas,
        
        -- CAC = Cost / Conversions
        CASE 
            WHEN channel_grouping IN ('Paid Search', 'Social') AND traffic_medium = 'cpc' THEN
                ROUND(SAFE_DIVIDE(
                    CASE 
                        WHEN channel_grouping = 'Paid Search' THEN total_sessions * 1.0
                        ELSE total_sessions * 0.5
                    END,
                    total_conversions
                ), 2)
            ELSE NULL
        END AS cac

    FROM calculated_metrics
)

SELECT
    -- Dimensions
    traffic_source,
    traffic_medium,
    campaign_name,
    campaign_identifier,
    channel_grouping,
    device_category,
    
    -- Volume metrics
    total_sessions,
    total_unique_visitors,
    total_pageviews,
    total_bounces,
    total_conversions,
    total_revenue,
    
    -- Performance metrics
    revenue_per_session,
    revenue_per_conversion,
    sessions_per_visitor,
    conversion_rate_pct,
    bounce_rate_pct,
    
    -- Engagement metrics
    ROUND(avg_time_on_site_sec, 2) AS avg_time_on_site_sec,
    ROUND(avg_pageviews_per_session, 2) AS avg_pageviews_per_session,
    engagement_quality_score,
    
    -- Cost & ROAS metrics (for paid channels)
    estimated_cost,
    roas,
    cac,
    
    -- Timestamp
    CURRENT_TIMESTAMP() AS last_updated

FROM with_roas_cac
ORDER BY total_revenue DESC
