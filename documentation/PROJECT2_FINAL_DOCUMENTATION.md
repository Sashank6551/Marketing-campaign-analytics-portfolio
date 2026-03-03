# Project 2: Marketing Campaign Performance Analytics - Final Documentation

**Project Completion Date:** March 1, 2026  
**Status:** ✅ 100% Complete - Production Ready  
**Dashboard:** [Live Looker Studio Link - Add Your Link Here]

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Project Overview](#project-overview)
3. [Technical Architecture](#technical-architecture)
4. [Data Pipeline - dbt Models](#data-pipeline)
5. [Dashboard - Looker Studio](#dashboard)
6. [Key Insights & Findings](#key-insights)
7. [Challenges & Solutions](#challenges-solutions)
8. [Skills Demonstrated](#skills-demonstrated)
9. [Future Enhancements](#future-enhancements)

---

## Executive Summary

Built end-to-end marketing analytics pipeline analyzing 71,812 sessions from Google Analytics sample dataset (July 2017). Created 7 dbt models with 60+ data quality tests, producing 3 mart tables optimized for different analytical purposes. Developed interactive 3-page Looker Studio dashboard revealing key insights about campaign performance, attribution, and conversion funnel optimization opportunities.

**Key Finding:** 97.3% of users drop off at Deep Engagement stage - while bounce rate is low (users engage), conversion optimization at deep engagement is the primary opportunity.

**Tech Stack:** dbt (transformation) + BigQuery (warehouse) + Looker Studio (visualization)

---

## Project Overview

### Business Problem
Marketing teams need to:
1. Understand which campaigns drive revenue (ROAS/CAC)
2. Attribute credit across multi-touch customer journeys
3. Identify funnel drop-off points to optimize conversions

### Dataset
- **Source:** `bigquery-public-data.google_analytics_sample.ga_sessions_*`
- **Time Period:** July 2017 (31 days)
- **Volume:** 71,812 sessions, ~50K unique visitors, 1,031 conversions
- **Revenue:** $124,499 total

### Goals Achieved
✅ Multi-model attribution analysis (first-touch, last-touch, linear)  
✅ ROAS and CAC calculations by campaign  
✅ 4-stage conversion funnel with drop-off analysis  
✅ Channel role classification (Initiator/Closer/Balanced/Mixed)  
✅ Interactive dashboard for stakeholder exploration  

---

## Technical Architecture

### Data Flow
```
Google Analytics Sample Data (BigQuery Public Dataset)
    ↓
[dbt Staging Layer] - Clean, rename, type conversion
    ↓
[dbt Intermediate Layer] - Business logic (ephemeral)
    ├── Attribution logic (first/last/linear touch)
    ├── Funnel stage classification  
    └── Campaign aggregations
    ↓
[dbt Marts Layer] - Final analytics tables
    ├── mart_campaign_performance (170 rows)
    ├── mart_attribution_analysis (105 rows)
    └── mart_conversion_funnel (1,987 rows)
    ↓
[Looker Studio Dashboard] - 3 interactive pages
```

### BigQuery Schema Structure
```
portfolio-ecommerce-486905 (GCP Project)
├── marketing_analytics_staging
│   └── stg_ga_sessions (VIEW - 71K rows)
├── marketing_analytics_campaign_performance
│   └── mart_campaign_performance (TABLE - 170 rows)
├── marketing_analytics_attribution
│   └── mart_attribution_analysis (TABLE - 105 rows)
└── marketing_analytics_funnel
    └── mart_conversion_funnel (TABLE - 1,987 rows)
```

**Design Decision:** Separate schemas by analytics domain for organization and access control.

---

## Data Pipeline - dbt Models

### Model Architecture

#### 1. Staging Layer
**Model:** `stg_ga_sessions.sql`  
**Materialization:** View  
**Purpose:** Clean raw GA data, standardize naming  

**Key Transformations:**
- Timestamp conversion: `TIMESTAMP_SECONDS(visitStartTime)`
- Revenue unit conversion: Micros → USD
- Binary flags: `is_bounced`, `is_converted`
- Session ID creation: `CONCAT(fullVisitorId, '-', visitId, '-', date)`

**Data Quality:** 23 tests passing
- Uniqueness, not null, accepted values, accepted ranges
- Fixed session ID uniqueness bug by adding date

**Code Snippet:**
```sql
SELECT
    CONCAT(fullVisitorId, '-', CAST(visitId AS STRING), '-', date) AS session_id,
    TIMESTAMP_SECONDS(visitStartTime) AS session_start_timestamp,
    COALESCE(totals.transactionRevenue, 0) / 1000000.0 AS revenue_usd,
    CASE WHEN totals.bounces = 1 THEN 1 ELSE 0 END AS is_bounced,
    CASE WHEN totals.transactions >= 1 THEN 1 ELSE 0 END AS is_converted
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE _TABLE_SUFFIX BETWEEN '20170701' AND '20170731'
```

---

#### 2. Intermediate Layer (Ephemeral)

**Model:** `int_session_attribution.sql`  
**Purpose:** Calculate attribution for each session

**Attribution Logic:**
```sql
-- First-touch: Credit to first session in visitor journey
is_first_touch = (session_sequence = 1)

-- Last-touch: Credit to last session before conversion
is_last_touch = (session_sequence = total_sessions_per_visitor AND is_converted = 1)

-- Linear: Equal credit across all sessions
linear_weight = 1 / total_sessions_per_visitor
linear_attribution_revenue = revenue_usd * linear_weight
```

**Model:** `int_funnel_steps.sql`  
**Purpose:** Classify sessions into funnel stages

**Funnel Stages:**
1. **Landing:** All sessions (entry point)
2. **Engagement:** Non-bounce + 2+ pageviews
3. **Deep Engagement:** 3+ pageviews + 60+ seconds on site
4. **Conversion:** Completed transaction

**Model:** `int_campaign_metrics.sql`  
**Purpose:** Pre-aggregate metrics by campaign/device/date

**Why Ephemeral?**
- Code reusability without storage cost
- Compiled as CTEs in downstream marts
- Keeps intermediate logic organized

---

#### 3. Marts Layer

**Model:** `mart_campaign_performance.sql`  
**Granularity:** Campaign + Device  
**Rows:** 170  
**Purpose:** ROAS/CAC analysis dashboard

**Key Metrics:**
- Total sessions, conversions, revenue
- Bounce rate, conversion rate (as decimals 0-1)
- ROAS = Revenue / Estimated Cost
- CAC = Cost / Conversions
- Engagement quality score (0-100)

**Business Logic:**
```sql
-- Estimated cost (placeholder: $1 per session for paid traffic)
estimated_cost = CASE 
    WHEN traffic_medium = 'cpc' THEN total_sessions * 1.0
    ELSE 0 
END

-- ROAS calculation
roas = SAFE_DIVIDE(total_revenue, NULLIF(estimated_cost, 0))

-- Engagement score (composite metric)
engagement_quality_score = 
    (1 - bounce_rate) * 40 +  -- Non-bounce weight
    (avg_pageviews_per_session / 10) * 30 +  -- Pageview depth
    (avg_time_on_site / 300) * 30  -- Time on site
```

---

**Model:** `mart_attribution_analysis.sql`  
**Granularity:** Campaign  
**Rows:** 105  
**Purpose:** Compare attribution models

**Attribution Comparison:**
- First-touch revenue vs Last-touch revenue
- Channel role classification based on attribution difference
- Journey complexity based on avg sessions per visitor

**Channel Role Logic:**
```sql
CASE
    WHEN first_touch_revenue > last_touch_revenue * 1.5 THEN 'Initiator'
    WHEN last_touch_revenue > first_touch_revenue * 1.5 THEN 'Closer'
    WHEN ABS(first_touch_revenue - last_touch_revenue) / NULLIF(first_touch_revenue, 0) < 0.2 THEN 'Balanced'
    ELSE 'Mixed'
END AS channel_role
```

**Insight Example:**
- **Direct traffic:** Balanced ($94K first-touch, $92K last-touch) - consistent throughout journey
- **Organic Search:** Mixed ($21K first-touch, $26K last-touch) - more closer than initiator

---

**Model:** `mart_conversion_funnel.sql`  
**Granularity:** Campaign + Device + Country  
**Rows:** 1,987  
**Purpose:** Funnel optimization analysis

**CRITICAL FIX APPLIED:**
Changed rates from percentages (0-100) to decimals (0-1) for Looker Studio compatibility.

**Before (Wrong):**
```sql
ROUND(SAFE_DIVIDE(sessions_conversion, sessions_landing) * 100, 2) AS overall_conversion_rate
-- Returns 1.44 (interpreted as 1.44, not %)
```

**After (Correct):**
```sql
ROUND(SAFE_DIVIDE(sessions_conversion, NULLIF(sessions_landing, 0)), 4) AS overall_conversion_rate
-- Returns 0.0144 (Looker formats as 1.44%)
```

**Funnel Metrics:**
- Stage counts (landing → engagement → deep → conversion)
- Progression rates (landing→engagement, engagement→deep, deep→conversion)
- Drop-off rates by stage
- Primary drop-off stage identification
- Funnel health score (0-100)

**Drop-off Stage Logic:**
```sql
CASE
    WHEN (sessions_landing - sessions_engagement) >= (sessions_engagement - sessions_deep_engagement)
        AND (sessions_landing - sessions_engagement) >= (sessions_deep_engagement - sessions_conversion)
    THEN 'Landing'
    WHEN (sessions_engagement - sessions_deep_engagement) >= (sessions_landing - sessions_engagement)
        AND (sessions_engagement - sessions_deep_engagement) >= (sessions_deep_engagement - sessions_conversion)
    THEN 'Engagement'
    ELSE 'Deep Engagement'
END AS primary_dropoff_stage
```

---

### Data Quality Testing

**Total Tests:** 60+ across all models  
**Test Coverage:**
- Staging: 23 tests (uniqueness, not null, value ranges)
- Marts: 37 tests (business logic validation)

**Test Examples:**
```yaml
# Uniqueness
- unique:
    column_name: session_id

# Range validation  
- dbt_utils.accepted_range:
    column_name: bounce_rate_pct
    min_value: 0
    max_value: 100

# Business logic
- dbt_utils.expression_is_true:
    expression: "total_conversions <= total_sessions"
```

**Key Debugging:**
1. **Session ID uniqueness:** Added date to ensure uniqueness across time
2. **Type mismatches in tests:** Used `quote: false` for integer comparisons
3. **Column ambiguity:** Used table aliases in complex CTEs
4. **NULL handling:** Added `NULLIF()` and `COALESCE()` throughout

---

## Dashboard - Looker Studio

### Dashboard Architecture

**3-Page Structure:**
1. **Campaign Performance** - Executive KPIs, ROAS/CAC
2. **Attribution Analysis** - Multi-model comparison
3. **Conversion Funnel** - Drop-off optimization

**Data Sources:** 3 separate BigQuery tables (one per page)  
**Filter Behavior:** Filters work within each page independently (Looker Studio limitation - no semantic model like Power BI)

---

### Page 1: Campaign Performance Dashboard

**Purpose:** Executive overview of campaign effectiveness

**Components:**

1. **KPI Scorecards (Top Row)**
   - Total Revenue: $124,499
   - Total Sessions: 71,812
   - Avg Conversion Rate: 0.59%
   - Avg ROAS: 0.80

2. **ROAS by Channel (Bar Chart)**
   - Shows which channels have best return on ad spend
   - Paid Search leads with 0.88 ROAS
   - Only paid channels show ROAS (organic/direct show null)

3. **Conversion Rate by Device (Pie Chart)**
   - Desktop: 80.3% (dominant)
   - Mobile: 12.2%
   - Tablet: 7.4%
   - **Insight:** Desktop converts significantly better

4. **Campaign Performance Table**
   - 8 columns: Channel, Source, Sessions, Conversions, Conv Rate, Revenue, ROAS, Quality Score
   - Heatmap on ROAS column (green = high, red = low)
   - Sortable by any metric
   - **Top Performer:** Paid Search / Google (51.86 quality score)

**Filters:** Channel, Device, Country

---

### Page 2: Attribution Model Comparison

**Purpose:** Understand how different attribution models credit channels differently

**Components:**

1. **Attribution Revenue Scorecards (Top Row)**
   - First-Touch Revenue: $124,499
   - Last-Touch Revenue: $124,499
   - Linear Attribution Revenue: $124,499
   - **Note:** Totals are same (total revenue doesn't change), but distribution by channel differs

2. **Revenue by Channel - Attribution Comparison (Grouped Bar Chart)**
   - Shows all 3 models side-by-side for each channel
   - **Direct:** $94K first-touch, $15K last-touch, $93K linear → Initiator role
   - **Organic:** $21K first-touch, $31K last-touch, $24K linear → Closer role
   - Color-coded: Blue (First), Green (Last), Orange (Linear)

3. **Channel Role Distribution (Pie Chart)**
   - Mixed: 33.3% (complex multi-touch journeys)
   - Closer: 25.0% (converts at end of journey)
   - Balanced: 25.0% (consistent throughout)
   - Initiator: 16.7% (drives awareness)

4. **Attribution Analysis Table**
   - Columns: Source, Channel, Role, Sessions, First-Touch $, Last-Touch $, Linear $, Avg Sessions/Visitor
   - Shows granular attribution differences
   - Sorted by linear attribution revenue

**Key Insight Visible:**
- Direct is "Balanced" - similar credit in first and last touch ($94K vs $92K)
- Organic is "Mixed" - doesn't fit cleanly into one role
- Some Paid Search is "Initiator" - higher first-touch than last-touch

**Filters:** Channel Grouping, Channel Role

---

### Page 3: Conversion Funnel Analysis

**Purpose:** Identify where users drop off and optimize conversion path

**Components:**

1. **Funnel Stage Scorecards (Left Side - Visual Funnel)**
   - Landing: 71,812 (widest box - blue)
   - Engagement: 35,219 (narrower - blue)
   - Deep Engagement: 19,066 (narrower - light blue)
   - Conversion: 1,031 (narrowest - green)
   - **Visual:** Descending width creates funnel shape

2. **Overall Conversion Rate Scorecard**
   - 1.44% (1,031 / 71,812)
   - **Fix Applied:** Used calculated field `SUM(sessions_conversion) / SUM(sessions_landing)` instead of AVG

3. **Drop-Off Distribution (Pie Chart)**
   - Deep Engagement: 97.3% (yellow - dominant)
   - Engagement: 1.5% (small red sliver)
   - Landing: 1.2% (small blue sliver)
   - **Critical Insight:** 97% drop-off at Deep Engagement stage

4. **Drop-off Analysis Table**
   - Granular by Channel + Device + Country
   - Columns: Channel, Device, Biggest Drop-off, Landing Count, Engagement Count, Deep Engagement Count, Conversion Count, Stage Rates, Overall Conv %, Health Score
   - Heatmap on Health Score (red/yellow/green)
   - **Top Funnel:** Paid Search + Desktop (100.0 health score)

5. **Funnel Health by Channel (Horizontal Bar Chart)**
   - Paid Search: 51.81 (green - best)
   - Other: 38.99 (orange)
   - Referral: 38.88 (orange)
   - Direct: 35.70 (orange/red)
   - Organic Search: 32.31 (red - needs optimization)

**Filters:** Date Range (placeholder), Channel, Device

**Key Insight Visible:**
Most users make it through landing and engagement (low bounce) but fail to convert at deep engagement. Optimization should focus on:
- Improving CTAs at deep engagement stage
- Simplifying checkout/conversion process
- Testing different offers/incentives

---

### Dashboard Technical Details

**Looker Studio Limitations Handled:**

1. **No Funnel Chart Native:** Created visual funnel using scorecards with descending width
2. **Decimal vs Percentage Confusion:** Stored rates as decimals (0-1), formatted as percent in Looker
3. **Cross-Page Filtering:** Accepted limitation - filters work within page only (no semantic model)
4. **Calculated Fields:** Used for Overall Conversion Rate to ensure correct aggregation

**Performance:**
- Fast load times (pre-aggregated marts, 170-1,987 rows each)
- No sampling needed
- Responsive on mobile

---

## Key Insights & Findings

### 1. Campaign Performance Insights

**Revenue Concentration:**
- Direct traffic: $93,331 (75% of total revenue)
- Organic Search: $24,742 (20%)
- Paid Search: $3,414 (3%)
- Other sources: $2,012 (2%)

**ROAS Analysis:**
- Paid Search ROAS: 0.88 (only channel with measurable ROAS)
- At $1 estimated cost per session, Paid Search is near break-even
- Organic and Direct have no cost, so infinite ROAS (shown as null)

**Device Performance:**
- Desktop: 80.3% of conversions, highest conversion rate
- Mobile: 12.2% of conversions (optimization opportunity)
- Tablet: 7.4% of conversions

**Engagement Quality:**
- Paid Search: 51.86 quality score (highest)
- Direct: 40.63 (good engagement, high revenue)
- Organic: 35.77 (lower engagement despite high sessions)

---

### 2. Attribution Insights

**Channel Roles Discovered:**
- **Balanced Channels (25%):** Direct, some Referral
  - Similar credit in first and last touch
  - Consistent throughout customer journey
  
- **Closer Channels (25%):** Some Other sources
  - Higher last-touch than first-touch
  - Drive final conversions
  
- **Initiator Channels (16.7%):** Some Paid Search
  - Higher first-touch than last-touch
  - Good for awareness/discovery
  
- **Mixed Channels (33.3%):** Organic Search, some Paid
  - Complex behavior, doesn't fit clear pattern
  - Multi-role across different customer journeys

**Attribution Differences:**
- Direct: First-touch $94K vs Last-touch $92K (Δ $2K) → Balanced
- Organic: First-touch $21K vs Last-touch $26K (Δ -$5K) → Leans Closer

**Journey Complexity:**
- Direct: 2.32 avg sessions per visitor (short journey)
- Organic: 1.82 avg sessions per visitor (even shorter)
- Indicates: Most conversions happen quickly (1-2 sessions)

---

### 3. Funnel Optimization Insights

**Funnel Progression:**
- Landing → Engagement: 49.0% (35,219 / 71,812)
- Engagement → Deep Engagement: 54.1% (19,066 / 35,219)
- Deep Engagement → Conversion: 5.4% (1,031 / 19,066)
- **Overall:** 1.44% conversion rate

**Critical Finding:**
97.3% of drop-offs occur at Deep Engagement stage
- Users ARE engaging (not bouncing)
- Users ARE viewing multiple pages
- Users ARE spending time on site
- **But:** They're not converting

**Implication:** 
The issue is NOT traffic quality or initial engagement. The issue is converting engaged users. Focus optimization on:
- Checkout process simplification
- Trust signals (reviews, security badges)
- Pricing/offer optimization
- CTA clarity and placement

**Best Performing Funnels:**
- Paid Search + Desktop: 51.81 health score
- Paid Search + Mobile: 48.8 health score
- Better targeting and intent from paid traffic

**Worst Performing Funnels:**
- Organic Search: 32.31 health score
- Broad, informational traffic with lower intent

---

## Challenges & Solutions

### Challenge 1: Session ID Uniqueness
**Problem:** `CONCAT(fullVisitorId, visitId)` created duplicate session IDs  
**Root Cause:** visitId can repeat across different dates  
**Solution:** Added date to session ID: `CONCAT(fullVisitorId, '-', visitId, '-', date)`  
**Learning:** Always validate uniqueness assumptions with tests

---

### Challenge 2: Timestamp Conversion
**Problem:** `PARSE_TIMESTAMP('%s', CAST(visitStartTime AS STRING))` failed  
**Error:** No matching signature for function  
**Root Cause:** visitStartTime is already an integer (seconds since epoch), not a string  
**Solution:** Used `TIMESTAMP_SECONDS(visitStartTime)` instead  
**Learning:** Know your data types before choosing functions

---

### Challenge 3: NULL Revenue Division
**Problem:** `totals.transactionRevenue / 1000000.0` returned NULL for non-converting sessions  
**Impact:** Calculations failed, metrics incorrect  
**Solution:** `COALESCE(totals.transactionRevenue, 0) / 1000000.0`  
**Learning:** Always handle NULLs in calculations

---

### Challenge 4: Test Type Mismatches
**Problem:** `accepted_values` test failed for integer column  
**Error:** `No matching signature for operator IN for argument types INT64 and {STRING}`  
**Root Cause:** dbt converted integer values to strings in test  
**Solution:** Added `quote: false` to test configuration  
```yaml
- accepted_values:
    values: [0, 1]
    quote: false
```
**Learning:** Use `quote: false` for integer comparisons in dbt tests

---

### Challenge 5: Column Ambiguity in CTEs
**Problem:** `Column name traffic_source is ambiguous`  
**Root Cause:** Multiple CTEs with same column names, no aliases  
**Solution:** Added table aliases throughout  
```sql
-- Before
SELECT traffic_source FROM channel_grouping

-- After  
SELECT cg.traffic_source FROM channel_grouping cg
```
**Learning:** Always use table aliases in complex queries

---

### Challenge 6: Ephemeral Models Don't Run Standalone
**Problem:** `dbt run --select int_session_attribution` showed SKIP  
**Root Cause:** Ephemeral models are compiled as CTEs, not materialized  
**Solution:** Run downstream mart that references it, or temporarily change to view  
**Learning:** Ephemeral = code organization, not queryable objects

---

### Challenge 7: Decimal vs Percentage in Looker Studio
**Problem:** Conversion rate showed 0.59% instead of expected value  
**Root Cause:** Model stored rates as decimals (0.0059), Looker formatted as percent (0.59%)  
**Solution:** Changed Looker format to "Percent" type, which correctly shows 0.59%  
**Alternative:** Could multiply by 100 in model, but decimal storage is better practice  
**Learning:** Understand how BI tools format data types

---

### Challenge 8: Overall Conversion Rate Calculation in Looker
**Problem:** Scorecard showed 0.17% instead of expected 1.44%  
**Root Cause:** Used `AVG(overall_conversion_rate)` which averaged per-row rates  
**Solution:** Created calculated field `SUM(sessions_conversion) / SUM(sessions_landing)`  
**Learning:** Aggregation matters - averages of rates ≠ overall rate

---

### Challenge 9: Drop-off Pie Chart Showing Only One Slice
**Problem:** Pie chart showed only "Deep Engagement" at 97.3%  
**Investigation:** Query showed 3 values exist in BigQuery  
**Root Cause:** Looker chart was configured correctly, data actually is 97.3% Deep Engagement  
**Resolution:** Not a bug - real insight! 97% of drop-offs truly occur at Deep Engagement  
**Learning:** Verify data before assuming visualization is broken. Sometimes unexpected results are valuable insights.

---

### Challenge 10: Cross-Page Filtering in Looker Studio
**Problem:** Filters don't flow across all 3 pages  
**Root Cause:** Looker Studio has no semantic model - each data source is independent  
**Solution:** Accepted limitation - this is standard in Looker Studio  
**Alternative:** Could create unified mart, but adds complexity  
**Learning:** Understand tool limitations vs Power BI's semantic model approach

---

## Skills Demonstrated

### Technical Skills

**SQL & Data Transformation:**
- Complex CTEs with 4-5 levels of nesting
- Window functions for attribution logic
- CASE statements for business rule implementation
- NULL handling and type conversions
- Aggregations at multiple granularities

**dbt (Data Build Tool):**
- Project structure and configuration
- Model layering (staging → intermediate → marts)
- Materialization strategies (view, ephemeral, table)
- Schema separation by domain
- Jinja templating with {{ ref() }}
- Data quality testing (60+ tests)
- Documentation with schema.yml

**BigQuery:**
- Wildcard table queries (_TABLE_SUFFIX)
- Partitioned data access optimization
- Cost optimization (date filtering, pre-aggregation)
- Schema design for analytics

**Looker Studio:**
- Multi-page dashboard design
- Calculated fields for custom metrics
- Chart type selection for data storytelling
- Filter configuration
- Data source management

**Data Quality & Testing:**
- Uniqueness constraints
- Range validation
- Business logic validation
- Expression testing
- Debugging test failures

---

### Analytical Skills

**Attribution Modeling:**
- Implemented 3 attribution models (first-touch, last-touch, linear)
- Compared model outcomes to understand channel contributions
- Classified channels by role in customer journey

**Funnel Analysis:**
- Defined meaningful funnel stages based on engagement
- Calculated progression and drop-off rates
- Identified primary optimization opportunities

**Campaign Analysis:**
- ROAS and CAC calculation
- Multi-dimensional analysis (channel, device, campaign)
- Engagement quality scoring

**Data Storytelling:**
- Structured dashboard for different stakeholder needs
- Highlighted key insights visually
- Balanced detail with executive summary

---

### Problem-Solving Skills

**Debugging:**
- Systematic approach to test failures
- Reading error messages for root cause
- Checking assumptions with data queries

**Documentation:**
- Comprehensive model documentation
- Code comments for complex logic
- Learning log of errors and solutions

**Iteration:**
- Started with simple models, added complexity
- Refactored for performance and clarity
- Responded to changing requirements

---

## Future Enhancements

### Short-Term (1-2 days)
1. **Add Time-Series Analysis**
   - Preserve date field in marts
   - Create daily trend models
   - Add date range filtering in dashboard
   - Compare week-over-week performance

2. **Enhanced Attribution**
   - Implement U-shaped attribution (40% first, 40% last, 20% middle)
   - Implement W-shaped attribution (30% first, 30% middle, 30% last, 10% rest)
   - Time decay model (recent touchpoints weighted higher)

3. **Cohort Analysis**
   - Group visitors by first session date
   - Track cohort behavior over time
   - Calculate cohort retention and LTV

---

### Medium-Term (1 week)
4. **Incremental Models**
   - Convert to incremental materialization for scalability
   - Implement proper partitioning and clustering
   - Add slowly changing dimension tracking

5. **Real Cost Integration**
   - Connect to Google Ads API for actual cost data
   - Calculate true ROAS, not estimates
   - Add budget pacing and efficiency metrics

6. **Advanced Funnel Features**
   - Hit-level analysis for in-page behavior
   - Cart abandonment tracking
   - Checkout step analysis
   - Time between funnel stages

7. **Alerting & Monitoring**
   - dbt test failures → Slack notification
   - Daily data quality reports
   - Anomaly detection (sudden metric changes)

---

### Long-Term (2+ weeks)
8. **Predictive Analytics**
   - Propensity to convert model (BigQuery ML)
   - Customer Lifetime Value prediction
   - Churn prediction
   - Next best action recommendations

9. **Advanced Segmentation**
   - RFM analysis (Recency, Frequency, Monetary)
   - K-means clustering for user segments
   - Personalization opportunities

10. **Multi-Source Integration**
    - Combine with CRM data
    - Integrate with ad platforms
    - Email marketing data
    - Product catalog enrichment

11. **CI/CD Pipeline**
    - Automate dbt runs (Airflow/Cloud Composer)
    - Git version control
    - Automated testing in staging environment
    - Production deployment workflow

12. **Dashboard Enhancements**
    - Executive summary page (Page 0)
    - Drill-down functionality
    - Benchmark comparisons (industry averages)
    - Forecasting and goal tracking

---

## Project Timeline

**Total Duration:** 6 days (Feb 26 - Mar 1, 2026)

### Daily Breakdown:
- **Day 1 (Feb 26):** Data exploration, staging model, debugging intentional errors (13 hours)
- **Day 2 (Feb 27):** Intermediate models, data quality tests (11 hours)
- **Day 3 (Feb 28):** Mart models, test debugging and fixes (11 hours)
- **Day 4 (Feb 29):** Looker Studio setup, Campaign Performance dashboard (8 hours)
- **Day 5 (Mar 1 AM):** Attribution and Funnel dashboards, critical fixes (4 hours)
- **Day 6 (Mar 1 PM):** Final polish, documentation (4 hours)

**Total Time Investment:** ~51 hours

---

## Files & Resources

### Project Files
```
marketing_analytics/
├── dbt_project.yml
├── packages.yml
├── profiles.yml (in ~/.dbt/)
├── models/
│   ├── staging/
│   │   ├── stg_ga_sessions.sql
│   │   └── schema.yml (23 tests)
│   ├── intermediate/
│   │   ├── int_session_attribution.sql
│   │   ├── int_funnel_steps.sql
│   │   └── int_campaign_metrics.sql
│   └── marts/
│       ├── campaign_performance/
│       │   ├── mart_campaign_performance.sql
│       │   └── schema.yml (35 tests)
│       ├── attribution/
│       │   ├── mart_attribution_analysis.sql
│       │   └── schema.yml (44 tests)
│       └── funnel/
│           ├── mart_conversion_funnel.sql
│           └── schema.yml (71 tests)
└── target/ (compiled SQL)
```

### Documentation Files
- `project2_complete_documentation.md` - Comprehensive project log
- `project2_continuity_script.md` - Quick reference for resuming work
- `project2_reference.md` - Initial project plan
- This file - Final documentation

### Dashboard
- **Live Link:** [Add your Looker Studio share link]
- **PDF Export:** `Marketing_Campaign_Analysis_Final.pdf`
- **Screenshots:** [Add screenshot folder/link]

---

## Conclusion

This project demonstrates end-to-end analytics engineering skills:
- **Data Engineering:** Building robust, tested data pipelines
- **Analytics:** Multi-model attribution, funnel analysis, campaign optimization
- **Visualization:** Interactive dashboards for stakeholder consumption
- **Problem-Solving:** Debugging complex SQL and test issues
- **Communication:** Documentation for technical and business audiences

**Key Takeaway for Interviews:**
"I built a production-grade marketing analytics pipeline analyzing 72K sessions. Created 7 dbt models with 60+ data quality tests, and a 3-page Looker Studio dashboard. The analysis revealed that 97% of drop-offs occur at deep engagement - not a traffic quality issue, but a conversion optimization opportunity. This insight would help the marketing team focus resources on improving CTAs and checkout flow rather than increasing traffic volume."

---

**Project Status:** ✅ Complete and Portfolio-Ready  
**Last Updated:** March 1, 2026  
**Maintainer:** [Your Name]  
**Contact:** [Your Email/LinkedIn]

---

## Appendix: Key SQL Snippets

### Attribution Logic
```sql
-- Window functions to identify first and last touch
ROW_NUMBER() OVER (
    PARTITION BY visitor_id 
    ORDER BY session_start_timestamp
) AS session_sequence,

COUNT(*) OVER (
    PARTITION BY visitor_id
) AS total_sessions_per_visitor,

-- First touch flag
CASE WHEN session_sequence = 1 THEN 1 ELSE 0 END AS is_first_touch,

-- Last touch flag (only if converted)
CASE 
    WHEN session_sequence = total_sessions_per_visitor 
    AND is_converted = 1 
    THEN 1 
    ELSE 0 
END AS is_last_touch,

-- Linear attribution weight
1.0 / total_sessions_per_visitor AS linear_weight
```

### Funnel Stage Classification
```sql
CASE
    WHEN is_converted = 1 THEN 'converted'
    WHEN pageviews >= 3 AND time_on_site >= 60 THEN 'dropped_at_deep_engagement'
    WHEN pageviews >= 2 AND is_bounced = 0 THEN 'dropped_at_engagement'
    ELSE 'bounced_at_landing'
END AS funnel_exit_stage
```

### ROAS Calculation
```sql
-- Estimated cost (placeholder)
CASE 
    WHEN traffic_medium = 'cpc' THEN total_sessions * 1.0
    ELSE 0 
END AS estimated_cost,

-- ROAS
ROUND(
    SAFE_DIVIDE(
        total_revenue, 
        NULLIF(estimated_cost, 0)
    ), 
    2
) AS roas
```

---

**End of Documentation**
