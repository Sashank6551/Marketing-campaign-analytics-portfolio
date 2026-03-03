-- models/marts/attribution/mart_attribution_analysis.sql
-- Attribution analysis comparing first-touch, last-touch, and linear models
-- Shows how revenue credit differs across attribution methods

{{ config(
    materialized='table',
    schema='attribution'
) }}

WITH attribution_base AS (
    SELECT
        traffic_source,
        traffic_medium,
        campaign_name,
        
        -- Count sessions by attribution type
        COUNT(DISTINCT session_id) AS total_sessions,
        COUNT(DISTINCT visitor_id) AS total_visitors,
        
        -- First-touch attribution
        COUNT(DISTINCT CASE WHEN is_first_touch = 1 THEN session_id END) AS first_touch_sessions,
        SUM(first_touch_revenue) AS first_touch_revenue,
        COUNT(DISTINCT CASE WHEN is_first_touch = 1 AND conversion_session_id IS NOT NULL THEN visitor_id END) AS first_touch_conversions,
        
        -- Last-touch attribution
        COUNT(DISTINCT CASE WHEN is_last_touch = 1 THEN session_id END) AS last_touch_sessions,
        SUM(last_touch_revenue) AS last_touch_revenue,
        COUNT(DISTINCT CASE WHEN is_last_touch = 1 AND conversion_session_id IS NOT NULL THEN visitor_id END) AS last_touch_conversions,
        
        -- Linear attribution
        SUM(linear_attribution_revenue) AS linear_attribution_revenue,
        COUNT(DISTINCT CASE WHEN conversion_session_id IS NOT NULL THEN visitor_id END) AS linear_conversions,
        
        -- Session behavior
        AVG(session_sequence) AS avg_session_position,
        AVG(total_sessions_per_visitor) AS avg_sessions_per_visitor
        
    FROM {{ ref('int_session_attribution') }}
    GROUP BY 
        traffic_source,
        traffic_medium,
        campaign_name
),

attribution_comparison AS (
    SELECT
        *,
        
        -- Revenue per session by attribution model
        ROUND(SAFE_DIVIDE(first_touch_revenue, first_touch_sessions), 2) AS first_touch_revenue_per_session,
        ROUND(SAFE_DIVIDE(last_touch_revenue, last_touch_sessions), 2) AS last_touch_revenue_per_session,
        ROUND(SAFE_DIVIDE(linear_attribution_revenue, total_sessions), 2) AS linear_revenue_per_session,
        
        -- Attribution differences
        ROUND(first_touch_revenue - last_touch_revenue, 2) AS first_vs_last_revenue_diff,
        ROUND(
            SAFE_DIVIDE(
                first_touch_revenue - last_touch_revenue,
                first_touch_revenue
            ) * 100,
        2) AS first_vs_last_pct_diff,
        
        -- Channel role classification
        CASE
            WHEN first_touch_revenue > last_touch_revenue * 1.5 THEN 'Initiator'
            WHEN last_touch_revenue > first_touch_revenue * 1.5 THEN 'Closer'
            WHEN ABS(first_touch_revenue - last_touch_revenue) / NULLIF(first_touch_revenue, 0) < 0.2 THEN 'Balanced'
            ELSE 'Mixed'
        END AS channel_role,
        
        -- Journey complexity indicator
        CASE
            WHEN avg_sessions_per_visitor <= 1.2 THEN 'Single-touch'
            WHEN avg_sessions_per_visitor <= 2.5 THEN 'Short journey'
            WHEN avg_sessions_per_visitor <= 4.0 THEN 'Medium journey'
            ELSE 'Long journey'
        END AS journey_complexity
        
    FROM attribution_base
),

channel_grouping AS (
    SELECT
        *,  -- MOVE * TO THE TOP
        
        -- Channel classification
        CASE
            WHEN traffic_medium = 'organic' THEN 'Organic Search'
            WHEN traffic_medium = 'cpc' THEN 'Paid Search'
            WHEN traffic_medium = 'referral' THEN 'Referral'
            WHEN traffic_medium = '(none)' AND traffic_source = '(direct)' THEN 'Direct'
            WHEN traffic_source IN ('youtube.com', 'facebook.com', 'twitter.com') THEN 'Social'
            ELSE 'Other'
        END AS channel_grouping,
        
        -- Create full identifier
        CONCAT(
            traffic_source, 
            ' / ', 
            traffic_medium,
            CASE 
                WHEN campaign_name IS NOT NULL AND campaign_name != '(not set)'
                THEN CONCAT(' / ', campaign_name)
                ELSE ''
            END
        ) AS campaign_identifier
        
    FROM attribution_comparison
)

SELECT
    -- Dimensions
    cg.traffic_source,
    cg.traffic_medium,
    cg.campaign_name,
    cg.campaign_identifier,
    cg.channel_grouping,
    cg.channel_role,
    cg.journey_complexity,
    
    -- Volume metrics
    cg.total_sessions,
    cg.total_visitors,
    ROUND(cg.avg_sessions_per_visitor, 2) AS avg_sessions_per_visitor,
    ROUND(cg.avg_session_position, 2) AS avg_session_position_in_journey,
    
    -- First-touch attribution
    cg.first_touch_sessions,
    cg.first_touch_conversions,
    ROUND(cg.first_touch_revenue, 2) AS first_touch_revenue,
    cg.first_touch_revenue_per_session,
    
    -- Last-touch attribution
    cg.last_touch_sessions,
    cg.last_touch_conversions,
    ROUND(cg.last_touch_revenue, 2) AS last_touch_revenue,
    cg.last_touch_revenue_per_session,
    
    -- Linear attribution
    cg.linear_conversions,
    ROUND(cg.linear_attribution_revenue, 2) AS linear_attribution_revenue,
    cg.linear_revenue_per_session,
    
    -- Attribution comparison
    cg.first_vs_last_revenue_diff,
    cg.first_vs_last_pct_diff,
    
    -- Metadata
    CURRENT_TIMESTAMP() AS last_updated

FROM channel_grouping cg
ORDER BY cg.linear_attribution_revenue DESC
