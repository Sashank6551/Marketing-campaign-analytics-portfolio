-- models/intermediate/int_campaign_metrics.sql
-- Campaign-level aggregations for performance analysis
-- Groups by traffic source, medium, and campaign

{{ config(
    materialized='ephemeral',
    schema='intermediate'
) }}

WITH session_metrics AS (
    SELECT
        traffic_source,
        traffic_medium,
        COALESCE(campaign_name, '(not set)') AS campaign_name,
        session_date,
        device_category,
        country,
        
        -- Session metrics
        COUNT(DISTINCT session_id) AS sessions,
        COUNT(DISTINCT visitor_id) AS unique_visitors,
        
        -- Engagement metrics
        SUM(hits) AS total_hits,
        SUM(COALESCE(pageviews, 0)) AS total_pageviews,
        SUM(COALESCE(time_on_site_seconds, 0)) AS total_time_on_site,
        SUM(is_bounced) AS bounces,
        
        -- Conversion metrics
        SUM(is_converted) AS conversions,
        SUM(COALESCE(transactions, 0)) AS total_transactions,
        SUM(revenue_usd) AS revenue,
        
        -- Calculated metrics
        AVG(COALESCE(pageviews, 0)) AS avg_pageviews_per_session,
        AVG(COALESCE(time_on_site_seconds, 0)) AS avg_time_on_site,
        SAFE_DIVIDE(SUM(is_bounced), COUNT(DISTINCT session_id)) AS bounce_rate,
        SAFE_DIVIDE(SUM(is_converted), COUNT(DISTINCT session_id)) AS conversion_rate,
        SAFE_DIVIDE(SUM(revenue_usd), COUNT(DISTINCT session_id)) AS revenue_per_session,
        SAFE_DIVIDE(SUM(revenue_usd), SUM(is_converted)) AS revenue_per_conversion
        
    FROM {{ ref('stg_ga_sessions') }}
    GROUP BY 
        traffic_source,
        traffic_medium,
        campaign_name,
        session_date,
        device_category,
        country
),

channel_classification AS (
    -- Classify channels for easier analysis
    SELECT
        *,
        CASE
            WHEN traffic_medium = 'organic' THEN 'Organic Search'
            WHEN traffic_medium = 'cpc' THEN 'Paid Search'
            WHEN traffic_medium = 'referral' THEN 'Referral'
            WHEN traffic_medium = '(none)' AND traffic_source = '(direct)' THEN 'Direct'
            WHEN traffic_medium = 'email' THEN 'Email'
            WHEN traffic_medium = 'social' THEN 'Social'
            WHEN traffic_source IN ('youtube.com', 'facebook.com', 'twitter.com') THEN 'Social'
            ELSE 'Other'
        END AS channel_grouping,
        
        -- Create campaign identifier
        CONCAT(
            traffic_source, 
            ' / ', 
            traffic_medium,
            CASE 
                WHEN campaign_name != '(not set)' 
                THEN CONCAT(' / ', campaign_name)
                ELSE ''
            END
        ) AS campaign_identifier
        
    FROM session_metrics
)

SELECT
    -- Dimensions
    traffic_source,
    traffic_medium,
    campaign_name,
    campaign_identifier,
    channel_grouping,
    session_date,
    device_category,
    country,
    
    -- Volume metrics
    sessions,
    unique_visitors,
    total_hits,
    total_pageviews,
    total_time_on_site,
    bounces,
    
    -- Conversion metrics
    conversions,
    total_transactions,
    revenue,
    
    -- Calculated rates and averages
    ROUND(avg_pageviews_per_session, 2) AS avg_pageviews_per_session,
    ROUND(avg_time_on_site, 2) AS avg_time_on_site,
    ROUND(bounce_rate * 100, 2) AS bounce_rate_pct,
    ROUND(conversion_rate * 100, 2) AS conversion_rate_pct,
    ROUND(revenue_per_session, 2) AS revenue_per_session,
    ROUND(revenue_per_conversion, 2) AS revenue_per_conversion,
    
    -- Additional calculated fields
    ROUND(SAFE_DIVIDE(sessions, unique_visitors), 2) AS sessions_per_visitor,
    ROUND(SAFE_DIVIDE(total_pageviews, sessions), 2) AS pages_per_session

FROM channel_classification
