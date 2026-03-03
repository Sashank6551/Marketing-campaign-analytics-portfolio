# Marketing Campaign Analytics - Metrics & Definitions Guide

**Project:** Marketing Campaign Performance Analytics (dbt + BigQuery)  
**Date:** February 27, 2026  
**Purpose:** Reference guide for Looker Studio dashboard metrics  

---

## 📊 Dashboard Structure Overview

### Dashboard 1: Campaign Performance (ROAS/CAC)
- Primary metrics: Revenue, sessions, conversions, ROAS, CAC
- Dimensions: Campaign, channel, device, date

### Dashboard 2: Attribution Analysis
- Primary metrics: Attribution revenue by model, channel role
- Dimensions: Traffic source, attribution model, journey complexity

### Dashboard 3: Conversion Funnel
- Primary metrics: Funnel stage progression, drop-off rates
- Dimensions: Campaign, device, country, funnel stage

---

## 🎯 Core Performance Metrics

### Traffic Metrics

#### **Sessions**
- **Definition:** Total number of visits to the website
- **Calculation:** `COUNT(DISTINCT session_id)`
- **Use Case:** Overall traffic volume measurement
- **Good:** Higher is better (indicates reach)
- **Typical Range:** Varies by industry; track trends over time
- **Dashboard:** All three dashboards

#### **Unique Visitors**
- **Definition:** Count of distinct individuals visiting the site
- **Calculation:** `COUNT(DISTINCT fullVisitorId)`
- **Use Case:** Audience size measurement
- **Note:** One visitor can have multiple sessions
- **Dashboard:** Campaign Performance

#### **New vs Returning Visitors**
- **Definition:** First-time visitors vs repeat visitors
- **Calculation:** Based on visitor session count
- **Use Case:** Audience acquisition vs retention balance
- **Typical Goal:** 60-70% new, 30-40% returning for growth
- **Dashboard:** Campaign Performance (device breakdown)

---

### Engagement Metrics

#### **Bounce Rate**
- **Definition:** Percentage of single-page sessions with no interaction
- **Calculation:** `bounced_sessions / total_sessions * 100`
- **Use Case:** Landing page quality indicator
- **Good:** Lower is better
- **Typical Range:** 
  - Excellent: < 30%
  - Good: 30-50%
  - Average: 50-70%
  - Poor: > 70%
- **Dashboard:** Campaign Performance, Funnel

#### **Pages per Session**
- **Definition:** Average number of pages viewed per session
- **Calculation:** `SUM(pageviews) / COUNT(sessions)`
- **Use Case:** Content engagement depth
- **Good:** Higher is better (indicates exploration)
- **Typical Range:** 2-4 pages for most sites
- **Dashboard:** Campaign Performance

#### **Average Session Duration**
- **Definition:** Mean time users spend on site per session
- **Calculation:** `AVG(time_on_site_seconds)` converted to MM:SS
- **Use Case:** Content stickiness indicator
- **Good:** Higher is better (but context-dependent)
- **Typical Range:**
  - E-commerce: 3-5 minutes
  - Content/Blog: 5-10 minutes
  - SaaS: 2-4 minutes
- **Dashboard:** Campaign Performance, Funnel

#### **Engagement Score**
- **Definition:** Composite metric (0-100) based on pageviews, time, and interaction
- **Calculation:** Weighted average of normalized metrics
- **Formula:**
  ```
  (pageview_score * 0.4 + time_score * 0.4 + interaction_score * 0.2)
  ```
- **Use Case:** Overall session quality assessment
- **Good:** > 60 is strong engagement
- **Dashboard:** Campaign Performance, Funnel

---

### Conversion Metrics

#### **Conversion Rate**
- **Definition:** Percentage of sessions resulting in a transaction
- **Calculation:** `conversions / total_sessions * 100`
- **Use Case:** Campaign effectiveness measurement
- **Good:** Higher is better
- **Typical Range:**
  - E-commerce: 2-3%
  - SaaS: 2-5%
  - Lead Gen: 5-10%
- **Dashboard:** All three dashboards

#### **Total Conversions**
- **Definition:** Count of completed transactions
- **Calculation:** `COUNT(session_id WHERE is_converted = 1)`
- **Use Case:** Absolute conversion volume
- **Dashboard:** Campaign Performance, Attribution

#### **Goal Completion Rate**
- **Definition:** Percentage reaching specific funnel milestones
- **Calculation:** `reached_goal_stage / total_sessions * 100`
- **Use Case:** Micro-conversion tracking
- **Dashboard:** Conversion Funnel

---

### Revenue Metrics

#### **Total Revenue**
- **Definition:** Sum of all transaction revenue in USD
- **Calculation:** `SUM(totals.transactionRevenue) / 1000000`
- **Note:** BigQuery stores revenue in micros (divide by 1M)
- **Use Case:** Overall business impact
- **Dashboard:** All three dashboards

#### **Revenue per Session (RPS)**
- **Definition:** Average revenue generated per session
- **Calculation:** `total_revenue / total_sessions`
- **Use Case:** Session value measurement
- **Good:** Higher is better
- **Typical Range:** Highly variable by industry
- **Dashboard:** Campaign Performance

#### **Revenue per Conversion (RPC) / Average Order Value (AOV)**
- **Definition:** Average revenue per transaction
- **Calculation:** `total_revenue / total_conversions`
- **Use Case:** Transaction size analysis
- **Good:** Higher is better (unless volume drops)
- **Dashboard:** Campaign Performance, Attribution

#### **Customer Lifetime Value (CLV)** - Future Enhancement
- **Definition:** Predicted total revenue from a customer relationship
- **Calculation:** Requires cohort analysis over time
- **Use Case:** Long-term customer value assessment
- **Note:** Not in current project, requires historical data

---

## 💰 Campaign Financial Metrics

### **ROAS (Return on Ad Spend)**
- **Definition:** Revenue generated per dollar spent on advertising
- **Calculation:** `total_revenue / total_ad_spend`
- **Current Implementation:** Uses placeholder $1 per session for paid traffic
- **Use Case:** Advertising efficiency measurement
- **Good:** 
  - Break-even: ROAS = 1.0 (earning back ad spend)
  - Target: ROAS > 4.0 for most e-commerce
  - Excellent: ROAS > 10.0
- **Formula Example:** $10,000 revenue / $2,000 ad spend = 5.0 ROAS
- **Dashboard:** Campaign Performance

#### **ROAS Interpretation Guide:**
- **< 1.0:** Losing money on ads
- **1.0-2.0:** Breaking even or small profit
- **2.0-4.0:** Good profitability
- **4.0-8.0:** Very profitable
- **> 8.0:** Exceptional performance

### **CAC (Customer Acquisition Cost)**
- **Definition:** Cost to acquire one new customer
- **Calculation:** `total_ad_spend / total_conversions`
- **Current Implementation:** Uses placeholder cost data
- **Use Case:** Efficiency of customer acquisition
- **Good:** Lower is better (but compare to CLV)
- **Target:** CAC should be < 1/3 of CLV
- **Formula Example:** $2,000 ad spend / 100 conversions = $20 CAC
- **Dashboard:** Campaign Performance

#### **CAC:CLV Ratio**
- **Definition:** Relationship between acquisition cost and lifetime value
- **Calculation:** `CAC / CLV`
- **Target:** CAC should be 1/3 or less of CLV (ratio < 0.33)
- **Note:** CLV calculation requires future enhancement

### **Cost per Session (CPS)**
- **Definition:** Average cost per website visit
- **Calculation:** `total_ad_spend / total_sessions`
- **Use Case:** Traffic acquisition efficiency
- **Dashboard:** Campaign Performance

### **Cost per Click (CPC)** - If Click Data Available
- **Definition:** Average cost per ad click
- **Calculation:** `total_ad_spend / total_clicks`
- **Use Case:** Bid management for paid search
- **Note:** Requires click-level data (not in current dataset)

---

## 🎭 Attribution Metrics

### Attribution Models Explained

#### **First-Touch Attribution**
- **Definition:** 100% credit to the first interaction in customer journey
- **Calculation:** Revenue assigned to session where `is_first_touch = TRUE`
- **Use Case:** Understanding awareness channels
- **Best For:** Measuring top-of-funnel performance
- **Limitation:** Ignores nurturing channels
- **Dashboard:** Attribution Analysis

#### **Last-Touch Attribution**
- **Definition:** 100% credit to the final interaction before conversion
- **Calculation:** Revenue assigned to session where `is_last_touch = TRUE`
- **Use Case:** Understanding closing channels
- **Best For:** Measuring bottom-of-funnel performance
- **Limitation:** Ignores initial touchpoints
- **Dashboard:** Attribution Analysis

#### **Linear Attribution**
- **Definition:** Equal credit distributed across all touchpoints
- **Calculation:** `Revenue / COUNT(sessions_per_visitor)` per session
- **Use Case:** Balanced view of channel contribution
- **Best For:** Understanding full journey impact
- **Formula:** 3 touchpoints, $300 revenue = $100 per touchpoint
- **Dashboard:** Attribution Analysis

#### **Multi-Touch Attribution Models** - Future Enhancement
- **Position-Based (U-Shaped):** 40% first, 40% last, 20% middle
- **Time-Decay:** More credit to recent touchpoints
- **W-Shaped:** 30% first, 30% middle, 30% last, 10% remaining

### Attribution-Specific Metrics

#### **Channel Role Classification**
- **Initiator:** More first-touch revenue than last-touch
- **Closer:** More last-touch revenue than first-touch  
- **Balanced:** Similar first and last-touch contributions
- **Use Case:** Understanding channel functions in funnel
- **Dashboard:** Attribution Analysis

#### **Journey Complexity**
- **Single-Touch:** Conversion in first session (1 touchpoint)
- **Short Journey:** 2-3 touchpoints before conversion
- **Medium Journey:** 4-6 touchpoints
- **Long Journey:** 7+ touchpoints
- **Use Case:** Understanding sales cycle length
- **Dashboard:** Attribution Analysis

#### **Attribution Revenue Difference**
- **Definition:** Gap between first-touch and last-touch revenue
- **Calculation:** `first_touch_revenue - last_touch_revenue`
- **Use Case:** Identifying over/under-credited channels
- **Dashboard:** Attribution Analysis

#### **Assisted Conversions**
- **Definition:** Conversions where channel was present but not last-touch
- **Use Case:** Measuring nurturing contribution
- **Note:** Requires future enhancement with better journey tracking

---

## 🚦 Conversion Funnel Metrics

### Funnel Stages (Project 2 Implementation)

#### **Stage 1: Landing**
- **Definition:** All sessions that reach the website
- **Calculation:** `COUNT(session_id)`
- **Progress Rate:** 100% (baseline)
- **Dashboard:** Conversion Funnel

#### **Stage 2: Engagement**
- **Definition:** Non-bounce sessions with 2+ pageviews
- **Calculation:** `COUNT(session_id WHERE is_bounced = 0 AND pageviews >= 2)`
- **Progress Rate:** `engaged_sessions / landing_sessions * 100`
- **Typical Range:** 40-60% of landing
- **Dashboard:** Conversion Funnel

#### **Stage 3: Deep Engagement**
- **Definition:** Sessions with 3+ pageviews AND 60+ seconds on site
- **Calculation:** `COUNT(session_id WHERE pageviews >= 3 AND time_on_site >= 60)`
- **Progress Rate:** `deep_engaged / landing_sessions * 100`
- **Typical Range:** 20-30% of landing
- **Dashboard:** Conversion Funnel

#### **Stage 4: Conversion**
- **Definition:** Sessions with completed transaction
- **Calculation:** `COUNT(session_id WHERE is_converted = 1)`
- **Progress Rate:** Conversion rate (2-3% typical)
- **Dashboard:** Conversion Funnel

### Funnel Analysis Metrics

#### **Drop-off Rate by Stage**
- **Definition:** Percentage lost at each funnel step
- **Calculation:** `(previous_stage - current_stage) / previous_stage * 100`
- **Use Case:** Identifying optimization opportunities
- **Example:** 
  - Landing: 10,000 (100%)
  - Engagement: 5,000 (50% drop-off)
  - Deep: 2,000 (60% drop-off from engagement)
  - Conversion: 300 (85% drop-off from deep)
- **Dashboard:** Conversion Funnel

#### **Stage Progression Rate**
- **Definition:** Percentage advancing from stage N to N+1
- **Calculation:** `stage_n_plus_1 / stage_n * 100`
- **Use Case:** Stage-by-stage performance
- **Dashboard:** Conversion Funnel

#### **Primary Drop-off Stage**
- **Definition:** Stage with highest absolute drop-off
- **Calculation:** Stage with `MAX(previous_stage - current_stage)`
- **Use Case:** Focus area for optimization
- **Dashboard:** Conversion Funnel

#### **Funnel Health Score**
- **Definition:** Composite metric (0-100) based on progression rates
- **Calculation:** Weighted average of stage-to-stage conversion rates
- **Good:** > 50 indicates healthy funnel
- **Dashboard:** Conversion Funnel

#### **Exit Distribution**
- **Definition:** Percentage exiting at each stage without converting
- **Calculation:** `exits_at_stage / total_exits * 100`
- **Use Case:** Understanding where users abandon
- **Dashboard:** Conversion Funnel

---

## 📈 Channel & Segmentation Metrics

### Channel Grouping

#### **Organic Search**
- **Definition:** Traffic from search engines (unpaid)
- **Criteria:** `traffic_medium = 'organic'`
- **Key Metrics:** Sessions, bounce rate, conversions
- **Dashboard:** Campaign Performance, Attribution

#### **Paid Search**
- **Definition:** Traffic from paid search ads (SEM)
- **Criteria:** `traffic_medium = 'cpc' OR traffic_medium = 'ppc'`
- **Key Metrics:** ROAS, CAC, conversion rate
- **Dashboard:** Campaign Performance, Attribution

#### **Referral**
- **Definition:** Traffic from external websites
- **Criteria:** `traffic_medium = 'referral'`
- **Use Case:** Partnership and backlink value
- **Dashboard:** Campaign Performance, Attribution

#### **Direct**
- **Definition:** Type-in traffic or bookmarked visits
- **Criteria:** `traffic_source = '(direct)'`
- **Note:** Can include dark social, untagged campaigns
- **Dashboard:** Campaign Performance, Attribution

#### **Social**
- **Definition:** Traffic from social media platforms
- **Criteria:** `traffic_medium LIKE '%social%'`
- **Key Metrics:** Engagement rate, conversions
- **Dashboard:** Campaign Performance, Attribution

#### **Display**
- **Definition:** Traffic from display advertising
- **Criteria:** `traffic_medium = 'display'`
- **Key Metrics:** View-through conversions, ROAS
- **Dashboard:** Campaign Performance, Attribution

#### **Email**
- **Definition:** Traffic from email campaigns
- **Criteria:** `traffic_medium = 'email'`
- **Key Metrics:** Click-through rate, conversion rate
- **Dashboard:** Campaign Performance

### Device Segmentation

#### **Desktop**
- **Sessions by device type:** Desktop/laptop computers
- **Typical Behavior:** Higher conversion rates, longer sessions
- **Dashboard:** Campaign Performance, Funnel

#### **Mobile**
- **Sessions by device type:** Smartphones
- **Typical Behavior:** Higher bounce, shorter sessions, growing conversion
- **Dashboard:** Campaign Performance, Funnel

#### **Tablet**
- **Sessions by device type:** Tablets
- **Typical Behavior:** Between desktop and mobile performance
- **Dashboard:** Campaign Performance, Funnel

### Geographic Segmentation

#### **Country-Level Metrics**
- **Top converting countries:** By conversion rate and revenue
- **Use Case:** Geographic targeting and localization
- **Dashboard:** Funnel Analysis

---

## 🔍 Advanced & Calculated Metrics

### Engagement Quality Metrics

#### **Engagement Rate**
- **Definition:** Percentage of sessions that are engaged (non-bounce)
- **Calculation:** `(total_sessions - bounced_sessions) / total_sessions * 100`
- **Inverse of:** Bounce rate
- **Dashboard:** Campaign Performance

#### **Page Depth Rate**
- **Definition:** Percentage reaching certain page view thresholds
- **Example:** % with 3+ pageviews, % with 5+ pageviews
- **Use Case:** Content depth analysis
- **Dashboard:** Funnel Analysis

#### **Dwell Time Distribution**
- **Definition:** Sessions bucketed by time on site
- **Buckets:** 0-30s, 30-60s, 1-3min, 3-5min, 5-10min, 10min+
- **Use Case:** Understanding engagement patterns
- **Dashboard:** Funnel Analysis

### Efficiency Metrics

#### **Revenue per Visitor (RPV)**
- **Definition:** Revenue divided by unique visitors
- **Calculation:** `total_revenue / unique_visitors`
- **Use Case:** Visitor monetization efficiency
- **Note:** Different from RPS (uses visitors, not sessions)

#### **Session Value**
- **Definition:** Same as Revenue per Session
- **Also Called:** Average Session Value
- **Dashboard:** Campaign Performance

#### **Traffic Quality Score**
- **Definition:** Composite metric combining bounce, engagement, conversion
- **Calculation:** Custom weighted formula
- **Use Case:** Overall traffic quality assessment
- **Dashboard:** Campaign Performance

### Time-Based Metrics (Future Enhancement)

#### **Days to Conversion**
- **Definition:** Time between first session and conversion
- **Use Case:** Sales cycle length measurement
- **Requires:** Multi-session tracking with conversion dates

#### **Time to Engagement**
- **Definition:** Seconds until first meaningful interaction
- **Use Case:** Landing page effectiveness
- **Requires:** Hit-level timing data

---

## 📊 Benchmark Comparison Context

### Industry Benchmarks (E-commerce Reference)

| Metric | Poor | Average | Good | Excellent |
|--------|------|---------|------|-----------|
| Bounce Rate | > 70% | 50-70% | 30-50% | < 30% |
| Conversion Rate | < 1% | 1-2% | 2-3% | > 3% |
| Pages/Session | < 2 | 2-3 | 3-4 | > 4 |
| Avg Session Duration | < 1min | 1-3min | 3-5min | > 5min |
| ROAS | < 2.0 | 2.0-4.0 | 4.0-8.0 | > 8.0 |

**Note:** Benchmarks vary significantly by:
- Industry (B2B vs B2C, product complexity)
- Traffic source (paid vs organic)
- Device type (mobile vs desktop)
- Geographic market

---

## 🎨 Dashboard Visualization Recommendations

### Campaign Performance Dashboard

**Key Charts:**
1. **Scorecard Row:** Revenue, Sessions, Conversions, ROAS
2. **Time Series:** Revenue and sessions trend over time
3. **Bar Chart:** Top campaigns by ROAS
4. **Table:** Campaign details with all metrics
5. **Pie Chart:** Channel distribution by revenue
6. **Scatter Plot:** ROAS vs CAC by campaign

**Filters:**
- Date range
- Campaign name
- Channel grouping
- Device category

---

### Attribution Analysis Dashboard

**Key Charts:**
1. **Comparison Table:** Revenue by attribution model
2. **Sankey Diagram:** User journey flows (if tool supports)
3. **Stacked Bar:** First vs Last touch by channel
4. **Scatter Plot:** Journey complexity vs conversion value
5. **Heatmap:** Channel role classification

**Filters:**
- Date range
- Traffic source
- Journey complexity
- Device category

---

### Conversion Funnel Dashboard

**Key Charts:**
1. **Funnel Visualization:** 4-stage funnel with percentages
2. **Drop-off Analysis:** Bar chart of losses by stage
3. **Trend Line:** Funnel health score over time
4. **Table:** Stage metrics by campaign/device/country
5. **Waterfall Chart:** Progression rates between stages

**Filters:**
- Date range
- Campaign
- Device category
- Country

---

## 🚨 Important Notes & Caveats

### Current Data Limitations

1. **Placeholder Costs:** ROAS/CAC use $1 per paid session assumption
   - **Action:** Replace with actual cost data from ad platforms
   - **Impact:** Current ROAS values are directional only

2. **Single Month Data:** July 2017 only (71K sessions)
   - **Impact:** Cannot calculate true CLV or cohort behavior
   - **Action:** Expand date range for trend analysis

3. **Revenue in Micros:** BigQuery stores revenue * 1,000,000
   - **Handled in staging:** Division by 1M applied in stg_ga_sessions
   - **Verify:** All revenue queries use staged model

4. **Session ID Construction:** Requires visitor + visit + date
   - **Why:** visitId repeats across different dates
   - **Format:** `{fullVisitorId}-{visitId}-{date}`

5. **Ephemeral Models:** Intermediate models are CTEs only
   - **Cannot query directly:** Must access via mart tables
   - **Marts available:** 3 final tables in separate schemas

### Metric Calculation Notes

1. **Attribution Logic:**
   - Requires visitor-level aggregation (multiple sessions per visitor)
   - Last-touch = last session BEFORE conversion (not after)
   - Linear weight = 1 / total_sessions_per_visitor

2. **Funnel Progression:**
   - Stages are cumulative (deep engagement implies engagement)
   - Sessions can skip stages (e.g., direct to conversion)
   - Exit stage = highest stage reached before bounce

3. **Conversion Tracking:**
   - Only transaction events counted (totals.transactions > 0)
   - Does not include micro-conversions (add to cart, signup)
   - Requires hit-level data for event-based goals

---

## 🔗 Related Documentation

- **Full Project Docs:** project2_complete_documentation.md
- **SQL Model Definitions:** Located in dbt project
- **Data Source:** `bigquery-public-data.google_analytics_sample.ga_sessions_*`
- **BigQuery Schemas:**
  - `marketing_analytics_staging`
  - `marketing_analytics_campaign_performance`
  - `marketing_analytics_attribution`
  - `marketing_analytics_funnel`

---

## 📝 Glossary of Terms

**CAC** - Customer Acquisition Cost  
**CLV** - Customer Lifetime Value  
**CPC** - Cost Per Click  
**CPS** - Cost Per Session  
**CTE** - Common Table Expression (SQL)  
**GA** - Google Analytics  
**ROAS** - Return on Ad Spend  
**RPC** - Revenue Per Conversion  
**RPS** - Revenue Per Session  
**RPV** - Revenue Per Visitor  
**SEM** - Search Engine Marketing  
**UTM** - Urchin Tracking Module (campaign tracking parameters)

---

**Last Updated:** February 27, 2026  
**Version:** 1.0  
**Status:** Ready for Looker Studio dashboard implementation  
**Next Steps:** Connect marts to visualization tool and build 3 dashboards
