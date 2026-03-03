-- models/marts/funnel/mart_conversion_funnel.sql
-- Conversion funnel analysis showing progression through stages
-- Identifies drop-off points and optimization opportunities
-- FIXED: Rates are now decimals (0-1) not percentages (0-100)
-- FIXED: Added NULLIF to prevent division by zero
-- FIXED: Added revenue_per_visitor_conversion column

{{ config(
    materialized='table',
    schema='funnel'
) }}

WITH funnel_aggregation AS (
    SELECT
        traffic_source,
        traffic_medium,
        COALESCE(campaign_name, '(not set)') AS campaign_name,
        device_category,
        country,
        
        -- Funnel stage counts
        COUNT(DISTINCT session_id) AS sessions_landing,
        COUNT(DISTINCT CASE WHEN reached_engagement = 1 THEN session_id END) AS sessions_engagement,
        COUNT(DISTINCT CASE WHEN reached_deep_engagement = 1 THEN session_id END) AS sessions_deep_engagement,
        COUNT(DISTINCT CASE WHEN reached_conversion = 1 THEN session_id END) AS sessions_conversion,
        
        -- Visitor-level funnel
        COUNT(DISTINCT visitor_id) AS visitors_landing,
        COUNT(DISTINCT CASE WHEN visitor_ever_converted = 1 THEN visitor_id END) AS visitors_converted,
        
        -- Exit stage distribution
        COUNT(DISTINCT CASE WHEN funnel_exit_stage = 'bounced_at_landing' THEN session_id END) AS exits_at_landing,
        COUNT(DISTINCT CASE WHEN funnel_exit_stage = 'dropped_after_landing' THEN session_id END) AS exits_after_landing,
        COUNT(DISTINCT CASE WHEN funnel_exit_stage = 'dropped_at_engagement' THEN session_id END) AS exits_at_engagement,
        COUNT(DISTINCT CASE WHEN funnel_exit_stage = 'dropped_at_deep_engagement' THEN session_id END) AS exits_at_deep_engagement,
        COUNT(DISTINCT CASE WHEN funnel_exit_stage = 'converted' THEN session_id END) AS exits_converted,
        
        -- Engagement metrics
        AVG(engagement_score) AS avg_engagement_score,
        AVG(visitor_avg_engagement_score) AS avg_visitor_engagement_score,
        AVG(visitor_days_active) AS avg_visitor_days_active,
        
        -- Revenue
        SUM(CASE WHEN reached_conversion = 1 THEN revenue_usd ELSE 0 END) AS total_revenue
        
    FROM {{ ref('int_funnel_steps') }}
    GROUP BY 
        traffic_source,
        traffic_medium,
        campaign_name,
        device_category,
        country
),

funnel_metrics AS (
    SELECT
        *,
        
        -- Conversion rates by stage (as decimals 0-1, NOT percentages 0-100)
        ROUND(SAFE_DIVIDE(sessions_engagement, NULLIF(sessions_landing, 0)), 4) AS landing_to_engagement_rate,
        ROUND(SAFE_DIVIDE(sessions_deep_engagement, NULLIF(sessions_engagement, 0)), 4) AS engagement_to_deep_rate,
        ROUND(SAFE_DIVIDE(sessions_conversion, NULLIF(sessions_deep_engagement, 0)), 4) AS deep_to_conversion_rate,
        ROUND(SAFE_DIVIDE(sessions_conversion, NULLIF(sessions_landing, 0)), 4) AS overall_conversion_rate,
        
        -- Drop-off rates (as decimals 0-1, NOT percentages)
        ROUND(SAFE_DIVIDE(sessions_landing - sessions_engagement, NULLIF(sessions_landing, 0)), 4) AS dropoff_after_landing_pct,
        ROUND(SAFE_DIVIDE(sessions_engagement - sessions_deep_engagement, NULLIF(sessions_engagement, 0)), 4) AS dropoff_after_engagement_pct,
        ROUND(SAFE_DIVIDE(sessions_deep_engagement - sessions_conversion, NULLIF(sessions_deep_engagement, 0)), 4) AS dropoff_after_deep_pct,
        
        -- Visitor-level metrics (as decimals 0-1, NOT percentages)
        ROUND(SAFE_DIVIDE(visitors_converted, NULLIF(visitors_landing, 0)), 4) AS visitor_conversion_rate,
        
        -- Revenue metrics
        ROUND(SAFE_DIVIDE(total_revenue, NULLIF(visitors_converted, 0)), 2) AS revenue_per_visitor_conversion,
        ROUND(SAFE_DIVIDE(total_revenue, NULLIF(sessions_conversion, 0)), 2) AS revenue_per_conversion,
        ROUND(SAFE_DIVIDE(total_revenue, NULLIF(sessions_landing, 0)), 2) AS revenue_per_landing
        
    FROM funnel_aggregation
),

channel_classification AS (
    SELECT
        *,
        
        -- Channel grouping
        CASE
            WHEN traffic_medium = 'organic' THEN 'Organic Search'
            WHEN traffic_medium = 'cpc' THEN 'Paid Search'
            WHEN traffic_medium = 'referral' THEN 'Referral'
            WHEN traffic_medium = '(none)' AND traffic_source = '(direct)' THEN 'Direct'
            WHEN traffic_source IN ('youtube.com', 'facebook.com', 'twitter.com') THEN 'Social'
            ELSE 'Other'
        END AS channel_grouping,
        
        -- Campaign identifier
        CONCAT(
            traffic_source, 
            ' / ', 
            traffic_medium,
            CASE 
                WHEN campaign_name != '(not set)' 
                THEN CONCAT(' / ', campaign_name)
                ELSE ''
            END
        ) AS campaign_identifier,
        
        -- Funnel health score (0-100)
        -- Uses rates (0-1) so multiply by 100 for score
        ROUND(
            (landing_to_engagement_rate * 100) * 0.3 +
            (engagement_to_deep_rate * 100) * 0.3 +
            (deep_to_conversion_rate * 100) * 0.4,
        1) AS funnel_health_score,
        
        -- Identify biggest drop-off stage
        CASE
            WHEN dropoff_after_landing_pct >= COALESCE(dropoff_after_engagement_pct, 0)
                AND dropoff_after_landing_pct >= COALESCE(dropoff_after_deep_pct, 0)
            THEN 'Landing'
            WHEN COALESCE(dropoff_after_engagement_pct, 0) >= COALESCE(dropoff_after_landing_pct, 0)
                AND COALESCE(dropoff_after_engagement_pct, 0) >= COALESCE(dropoff_after_deep_pct, 0)
            THEN 'Engagement'
            WHEN COALESCE(dropoff_after_deep_pct, 0) >= COALESCE(dropoff_after_landing_pct, 0)
                AND COALESCE(dropoff_after_deep_pct, 0) >= COALESCE(dropoff_after_engagement_pct, 0)
            THEN 'Deep Engagement'
            ELSE 'Multiple'
        END AS primary_dropoff_stage
        
    FROM funnel_metrics
)

SELECT
    -- Dimensions
    traffic_source,
    traffic_medium,
    campaign_name,
    campaign_identifier,
    channel_grouping,
    device_category,
    country,
    
    -- Funnel stage volumes
    sessions_landing,
    sessions_engagement,
    sessions_deep_engagement,
    sessions_conversion,
    
    -- Visitor metrics
    visitors_landing,
    visitors_converted,
    visitor_conversion_rate,
    
    -- Conversion rates (decimals 0-1)
    landing_to_engagement_rate,
    engagement_to_deep_rate,
    deep_to_conversion_rate,
    overall_conversion_rate,
    
    -- Drop-off analysis (decimals 0-1)
    dropoff_after_landing_pct,
    dropoff_after_engagement_pct,
    dropoff_after_deep_pct,
    primary_dropoff_stage,
    
    -- Exit distribution
    exits_at_landing,
    exits_after_landing,
    exits_at_engagement,
    exits_at_deep_engagement,
    exits_converted,
    
    -- Engagement metrics
    ROUND(avg_engagement_score, 2) AS avg_engagement_score,
    ROUND(avg_visitor_engagement_score, 2) AS avg_visitor_engagement_score,
    ROUND(avg_visitor_days_active, 2) AS avg_visitor_days_active,
    
    -- Revenue metrics
    ROUND(total_revenue, 2) AS total_revenue,
    revenue_per_visitor_conversion,
    revenue_per_conversion,
    revenue_per_landing,
    
    -- Health score (0-100)
    funnel_health_score,
    
    -- Metadata
    CURRENT_TIMESTAMP() AS last_updated

FROM channel_classification
ORDER BY sessions_landing DESC
