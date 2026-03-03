-- models/intermediate/int_session_attribution.sql
-- Attribution model: Assigns credit to traffic sources for conversions
-- Methods: First-touch, Last-touch, Linear

{{ config(
    materialized='ephemeral',
    schema='intermediate'
) }}

WITH session_data AS (
    SELECT
        visitor_id,
        session_id,
        session_date,
        session_start_timestamp,
        traffic_source,
        traffic_medium,
        campaign_name,
        is_converted,
        revenue_usd,
        -- Session sequence per visitor
        ROW_NUMBER() OVER (
            PARTITION BY visitor_id 
            ORDER BY session_start_timestamp
        ) AS session_sequence,
        -- Total sessions per visitor
        COUNT(*) OVER (PARTITION BY visitor_id) AS total_sessions_per_visitor
    FROM {{ ref('stg_ga_sessions') }}
),

conversions AS (
    -- Get converting sessions only
    SELECT
        visitor_id,
        session_id,
        session_date,
        revenue_usd,
        session_start_timestamp
    FROM session_data
    WHERE is_converted = 1
),

attributed_sessions AS (
    SELECT
        s.visitor_id,
        s.session_id,
        s.session_date,
        s.session_start_timestamp,
        s.traffic_source,
        s.traffic_medium,
        s.campaign_name,
        s.is_converted,
        s.revenue_usd,
        s.session_sequence,
        s.total_sessions_per_visitor,
        
        -- Attribution logic
        CASE 
            WHEN s.session_sequence = 1 THEN 1 
            ELSE 0 
        END AS is_first_touch,
        
        CASE 
            WHEN s.session_sequence = s.total_sessions_per_visitor THEN 1 
            ELSE 0 
        END AS is_last_touch,
        
        -- Linear attribution: divide credit equally across all sessions
        1.0 / s.total_sessions_per_visitor AS linear_weight,
        
        -- Get conversion info for this visitor (if any)
        c.session_id AS conversion_session_id,
        c.revenue_usd AS conversion_revenue,
        c.session_date AS conversion_date
        
    FROM session_data s
    LEFT JOIN conversions c ON s.visitor_id = c.visitor_id
)

SELECT
    session_id,
    visitor_id,
    session_date,
    session_start_timestamp,
    traffic_source,
    traffic_medium,
    campaign_name,
    is_converted,
    revenue_usd,
    session_sequence,
    total_sessions_per_visitor,
    
    -- Attribution flags
    is_first_touch,
    is_last_touch,
    linear_weight,
    
    -- Conversion info
    conversion_session_id,
    conversion_revenue,
    conversion_date,
    
    -- Attribution revenue (only for visitors who converted)
    CASE 
        WHEN conversion_session_id IS NOT NULL THEN
            CASE
                WHEN is_first_touch = 1 THEN conversion_revenue
                ELSE 0
            END
        ELSE 0
    END AS first_touch_revenue,
    
    CASE 
        WHEN conversion_session_id IS NOT NULL THEN
            CASE
                WHEN is_last_touch = 1 THEN conversion_revenue
                ELSE 0
            END
        ELSE 0
    END AS last_touch_revenue,
    
    CASE 
        WHEN conversion_session_id IS NOT NULL THEN
            conversion_revenue * linear_weight
        ELSE 0
    END AS linear_attribution_revenue

FROM attributed_sessions
