-- =============================================================================
-- RavenStack SaaS Revenue Growth & Churn Analysis
-- Data Cleaning & Business Analysis Script
-- Author: dcardosomr-cmd
-- Last Updated: January 2026
-- Database: SQL Server (T-SQL)
-- Description: Data type enforcement, integrity checks, null audits,
--              duplicate detection, and multi-dimensional business analysis
--              across revenue, churn, feature usage, and customer segments.
-- =============================================================================


-- =============================================================================
-- SECTION 1: INITIAL DATA EXPLORATION
-- Preview all five source tables before any transformation
-- =============================================================================

SELECT * FROM [dbo].[ravenstack_subscriptions];
SELECT * FROM [dbo].[ravenstack_support_tickets];
SELECT * FROM [dbo].[ravenstack_feature_usage];
SELECT * FROM [dbo].[ravenstack_churn_events];
SELECT * FROM [dbo].[ravenstack_accounts];


-- =============================================================================
-- SECTION 2: DATA TYPE ENFORCEMENT
-- Enforce correct types on ravenstack_subscriptions.
-- Note: mrr_amount and arr_amount use DECIMAL(12,2) to preserve cent-level
--       precision. Using INT would silently truncate fractional revenue values.
-- =============================================================================

ALTER TABLE [dbo].[ravenstack_subscriptions] ALTER COLUMN [start_date]       DATE;
ALTER TABLE [dbo].[ravenstack_subscriptions] ALTER COLUMN [end_date]         DATE;
ALTER TABLE [dbo].[ravenstack_subscriptions] ALTER COLUMN [seats]            INT;
ALTER TABLE [dbo].[ravenstack_subscriptions] ALTER COLUMN [mrr_amount]       DECIMAL(12, 2);
ALTER TABLE [dbo].[ravenstack_subscriptions] ALTER COLUMN [arr_amount]       DECIMAL(12, 2);
ALTER TABLE [dbo].[ravenstack_subscriptions] ALTER COLUMN [is_trial]         BIT;
ALTER TABLE [dbo].[ravenstack_subscriptions] ALTER COLUMN [upgrade_flag]     BIT;
ALTER TABLE [dbo].[ravenstack_subscriptions] ALTER COLUMN [downgrade_flag]   BIT;
ALTER TABLE [dbo].[ravenstack_subscriptions] ALTER COLUMN [churn_flag]       BIT;
ALTER TABLE [dbo].[ravenstack_subscriptions] ALTER COLUMN [auto_renew_flag]  BIT;


-- =============================================================================
-- SECTION 3: NULL AUDITS
-- Identify columns with missing values that could affect analysis accuracy
-- =============================================================================

-- 3a. Missing end_date in subscriptions (active subs vs. data gaps)
SELECT
    COUNT(*)                                                  AS total_rows,
    SUM(CASE WHEN end_date IS NULL THEN 1 ELSE 0 END)        AS nulls_end_date
FROM [dbo].[ravenstack_subscriptions];

-- 3b. Missing satisfaction scores in support tickets
SELECT
    COUNT(*)                                                        AS total_rows,
    SUM(CASE WHEN satisfaction_score IS NULL THEN 1 ELSE 0 END)    AS nulls_satisfaction_score
FROM [dbo].[ravenstack_support_tickets];

-- 3c. Missing feedback text in churn events
SELECT
    COUNT(*)                                                    AS total_rows,
    SUM(CASE WHEN feedback_text IS NULL THEN 1 ELSE 0 END)     AS nulls_feedback_text
FROM [dbo].[ravenstack_churn_events];


-- =============================================================================
-- SECTION 4: DUPLICATE DETECTION (INTEGRITY CHECKS)
-- Verify primary key uniqueness across all five tables.
-- Any result returned here indicates a data quality issue requiring resolution.
-- =============================================================================

SELECT churn_event_id,  COUNT(*) AS duplicate_count FROM [dbo].[ravenstack_churn_events]    GROUP BY churn_event_id    HAVING COUNT(*) > 1;
SELECT account_id,      COUNT(*) AS duplicate_count FROM [dbo].[ravenstack_accounts]         GROUP BY account_id        HAVING COUNT(*) > 1;
SELECT usage_id,        COUNT(*) AS duplicate_count FROM [dbo].[ravenstack_feature_usage]    GROUP BY usage_id          HAVING COUNT(*) > 1;
SELECT subscription_id, COUNT(*) AS duplicate_count FROM [dbo].[ravenstack_subscriptions]    GROUP BY subscription_id   HAVING COUNT(*) > 1;
SELECT ticket_id,       COUNT(*) AS duplicate_count FROM [dbo].[ravenstack_support_tickets]  GROUP BY ticket_id         HAVING COUNT(*) > 1;


-- =============================================================================
-- SECTION 5: NEGATIVE VALUE CHECKS
-- Ensure no logically impossible values exist in numeric fields
-- =============================================================================

SELECT * FROM [dbo].[ravenstack_subscriptions]   WHERE mrr_amount < 0;
SELECT * FROM [dbo].[ravenstack_subscriptions]   WHERE arr_amount < 0;
SELECT * FROM [dbo].[ravenstack_support_tickets] WHERE first_response_time_minutes < 0;
SELECT * FROM [dbo].[ravenstack_support_tickets] WHERE resolution_time_hours < 0;
SELECT * FROM [dbo].[ravenstack_feature_usage]   WHERE usage_count < 0;


-- =============================================================================
-- SECTION 6: SUBSCRIPTION & REVENUE ANALYSIS
-- =============================================================================

-- 6a. Most popular plan tiers by subscriber count
SELECT
    plan_tier,
    COUNT(*) AS subscriber_count
FROM [dbo].[ravenstack_subscriptions]
GROUP BY plan_tier
ORDER BY subscriber_count DESC;


-- 6b. Revenue and subscriber count by country and plan tier
SELECT
    a.country,
    s.plan_tier,
    SUM(s.mrr_amount)        AS total_mrr,
    SUM(s.arr_amount)        AS total_arr,
    COUNT(s.subscription_id) AS subscription_count
FROM [dbo].[ravenstack_accounts] AS a
JOIN [dbo].[ravenstack_subscriptions] AS s ON a.account_id = s.account_id
GROUP BY a.country, s.plan_tier
ORDER BY a.country DESC;


-- 6c. Revenue profitability by plan tier
SELECT
    plan_tier,
    SUM(mrr_amount) AS total_mrr,
    SUM(arr_amount) AS total_arr
FROM [dbo].[ravenstack_subscriptions]
GROUP BY plan_tier
ORDER BY total_arr DESC;


-- 6d. Revenue by segment (industry, country, plan tier, billing frequency)
SELECT
    a.industry,
    a.country,
    s.plan_tier,
    s.billing_frequency,
    SUM(s.mrr_amount) AS total_mrr,
    SUM(s.arr_amount) AS total_arr
FROM [dbo].[ravenstack_accounts] AS a
JOIN [dbo].[ravenstack_subscriptions] AS s ON a.account_id = s.account_id
GROUP BY a.industry, a.country, s.plan_tier, s.billing_frequency
ORDER BY a.industry, a.country, s.plan_tier, s.billing_frequency;


-- 6e. Revenue concentration: top 10 accounts by ARR
SELECT TOP 10
    a.account_id,
    a.account_name,
    a.industry,
    a.country,
    SUM(s.arr_amount) AS total_arr
FROM [dbo].[ravenstack_accounts] AS a
JOIN [dbo].[ravenstack_subscriptions] AS s ON a.account_id = s.account_id
GROUP BY a.account_id, a.account_name, a.industry, a.country
ORDER BY total_arr DESC;


-- 6f. Revenue evolution over time by country (monthly granularity)
SELECT
    a.country,
    s.start_date,
    s.end_date,
    SUM(s.mrr_amount)        AS total_mrr,
    SUM(s.arr_amount)        AS total_arr,
    COUNT(s.subscription_id) AS subscription_count
FROM [dbo].[ravenstack_accounts] AS a
JOIN [dbo].[ravenstack_subscriptions] AS s ON a.account_id = s.account_id
GROUP BY a.country, s.start_date, s.end_date
ORDER BY s.end_date DESC;


-- 6g. Expansion vs. contraction: overall net MRR growth
SELECT
    SUM(CASE WHEN upgrade_flag   = 1 THEN mrr_amount ELSE 0 END)                   AS expansion_mrr,
    SUM(CASE WHEN downgrade_flag = 1 THEN mrr_amount ELSE 0 END)                   AS contraction_mrr,
    SUM(CASE WHEN upgrade_flag   = 1 THEN mrr_amount ELSE 0 END)
    - SUM(CASE WHEN downgrade_flag = 1 THEN mrr_amount ELSE 0 END)                 AS net_mrr_growth
FROM [dbo].[ravenstack_subscriptions];


-- 6h. Expansion vs. contraction by month
SELECT
    DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1)                          AS change_month,
    SUM(CASE WHEN upgrade_flag   = 1 THEN mrr_amount ELSE 0 END)                   AS expansion_mrr,
    SUM(CASE WHEN downgrade_flag = 1 THEN mrr_amount ELSE 0 END)                   AS contraction_mrr,
    SUM(CASE WHEN upgrade_flag   = 1 THEN mrr_amount ELSE 0 END)
    - SUM(CASE WHEN downgrade_flag = 1 THEN mrr_amount ELSE 0 END)                 AS net_mrr_growth
FROM [dbo].[ravenstack_subscriptions]
GROUP BY DATEFROMPARTS(YEAR(start_date), MONTH(start_date), 1)
ORDER BY change_month;


-- =============================================================================
-- SECTION 7: CHURN ANALYSIS
-- =============================================================================

-- 7a. Churn volatility by plan tier and reason code
SELECT
    s.plan_tier,
    c.reason_code,
    COUNT(c.churn_event_id) AS churn_count
FROM [dbo].[ravenstack_churn_events] AS c
JOIN [dbo].[ravenstack_subscriptions] AS s ON c.account_id = s.account_id
GROUP BY s.plan_tier, c.reason_code
ORDER BY s.plan_tier DESC;


-- 7b. Overall logo churn rate (% of accounts churned)
WITH churn_events AS (
    SELECT COUNT(DISTINCT a.account_id) AS total_churn
    FROM [dbo].[ravenstack_accounts] AS a
    LEFT JOIN [dbo].[ravenstack_churn_events] AS e    ON a.account_id = e.account_id
    LEFT JOIN [dbo].[ravenstack_subscriptions] AS s   ON a.account_id = s.account_id
    WHERE a.churn_flag = 1
       OR s.churn_flag = 1
       OR e.account_id IS NOT NULL
),
totals AS (
    SELECT COUNT(*) AS total_accounts
    FROM [dbo].[ravenstack_accounts]
)
SELECT
    ce.total_churn,
    t.total_accounts,
    ce.total_churn * 100.0 / t.total_accounts AS logo_churn_rate_pct
FROM churn_events AS ce
CROSS JOIN totals AS t;


-- 7c. Logo churn rate by year and industry
WITH churned_accounts AS (
    SELECT DISTINCT
        a.account_id,
        a.industry,
        DATEPART(YEAR, e.churn_date) AS churn_year
    FROM [dbo].[ravenstack_accounts] AS a
    LEFT JOIN [dbo].[ravenstack_churn_events] AS e ON a.account_id = e.account_id
    WHERE a.churn_flag = 1 OR e.account_id IS NOT NULL
),
account_base AS (
    SELECT account_id, industry FROM [dbo].[ravenstack_accounts]
)
SELECT
    ca.churn_year,
    ca.industry,
    COUNT(DISTINCT ca.account_id) AS churned_accounts,
    COUNT(DISTINCT ab.account_id) AS total_accounts,
    COUNT(DISTINCT ca.account_id) * 100.0 / COUNT(DISTINCT ab.account_id) AS logo_churn_rate_pct
FROM churned_accounts AS ca
JOIN account_base AS ab ON ca.industry = ab.industry
GROUP BY ca.churn_year, ca.industry
ORDER BY ca.churn_year, ca.industry;


-- 7d. Logo churn rate by year and plan tier
WITH churned_accounts AS (
    SELECT DISTINCT
        a.account_id,
        a.plan_tier,
        DATEPART(YEAR, e.churn_date) AS churn_year
    FROM [dbo].[ravenstack_accounts] AS a
    LEFT JOIN [dbo].[ravenstack_churn_events] AS e ON a.account_id = e.account_id
    WHERE a.churn_flag = 1 OR e.account_id IS NOT NULL
),
account_base AS (
    SELECT account_id, plan_tier FROM [dbo].[ravenstack_accounts]
)
SELECT
    ca.churn_year,
    ca.plan_tier,
    COUNT(DISTINCT ca.account_id) AS churned_accounts,
    COUNT(DISTINCT ab.account_id) AS total_accounts,
    COUNT(DISTINCT ca.account_id) * 100.0 / COUNT(DISTINCT ab.account_id) AS logo_churn_rate_pct
FROM churned_accounts AS ca
JOIN account_base AS ab ON ca.plan_tier = ab.plan_tier
GROUP BY ca.churn_year, ca.plan_tier
ORDER BY ca.churn_year, ca.plan_tier;


-- 7e. Logo churn rate by year, plan tier, and industry (full breakdown)
WITH churned_accounts AS (
    SELECT DISTINCT
        a.account_id,
        a.industry,
        a.plan_tier,
        DATEPART(YEAR, e.churn_date) AS churn_year
    FROM [dbo].[ravenstack_accounts] AS a
    LEFT JOIN [dbo].[ravenstack_churn_events] AS e   ON a.account_id = e.account_id
    LEFT JOIN [dbo].[ravenstack_subscriptions] AS s  ON a.account_id = s.account_id
    WHERE a.churn_flag = 1
       OR s.churn_flag = 1
       OR e.account_id IS NOT NULL
),
account_base AS (
    SELECT account_id, industry, plan_tier FROM [dbo].[ravenstack_accounts]
)
SELECT
    CASE
        WHEN ca.churn_year IS NULL THEN 'Account Still Active'
        ELSE CAST(ca.churn_year AS VARCHAR(10))
    END                                                                        AS churn_year_label,
    ca.industry,
    ca.plan_tier,
    COUNT(DISTINCT ca.account_id)                                              AS churned_accounts,
    COUNT(DISTINCT ab.account_id)                                              AS total_accounts,
    COUNT(DISTINCT ca.account_id) * 100.0 / COUNT(DISTINCT ab.account_id)     AS logo_churn_rate_pct
FROM churned_accounts AS ca
JOIN account_base AS ab ON ca.industry = ab.industry AND ca.plan_tier = ab.plan_tier
GROUP BY
    CASE WHEN ca.churn_year IS NULL THEN 'Account Still Active' ELSE CAST(ca.churn_year AS VARCHAR(10)) END,
    ca.industry, ca.plan_tier
ORDER BY churn_year_label, ca.industry, ca.plan_tier;


-- 7f. Churn events: reason code, refund amount, by industry and geography
SELECT
    e.reason_code,
    e.refund_amount_usd,
    a.industry,
    a.country,
    s.plan_tier,
    s.seats
FROM [dbo].[ravenstack_accounts] AS a
LEFT JOIN [dbo].[ravenstack_churn_events] AS e   ON a.account_id = e.account_id
LEFT JOIN [dbo].[ravenstack_subscriptions] AS s  ON a.account_id = s.account_id
WHERE a.churn_flag = 1
   OR s.churn_flag = 1
   OR e.account_id IS NOT NULL
GROUP BY e.reason_code, a.industry, e.refund_amount_usd, a.country, s.plan_tier, s.seats
ORDER BY e.refund_amount_usd DESC;


-- 7g. Lost MRR/ARR from churned subscriptions per month
SELECT
    YEAR(s.end_date)          AS churn_year,
    MONTH(s.end_date)         AS churn_month,
    SUM(s.mrr_amount)         AS total_mrr_lost,
    SUM(s.arr_amount)         AS total_arr_lost
FROM [dbo].[ravenstack_accounts] AS a
JOIN [dbo].[ravenstack_subscriptions] AS s ON s.account_id = a.account_id
WHERE a.churn_flag = 1
  AND s.end_date IS NOT NULL
GROUP BY YEAR(s.end_date), MONTH(s.end_date)
ORDER BY churn_year, churn_month;


-- 7h. Is churn more likely after an upgrade or downgrade?
WITH churn_labels AS (
    SELECT DISTINCT
        e.account_id,
        DATEPART(YEAR,    e.churn_date) AS churn_year,
        DATEPART(QUARTER, e.churn_date) AS churn_quarter,
        CASE
            WHEN e.preceding_upgrade_flag   = 1 THEN 'After Upgrade'
            WHEN e.preceding_downgrade_flag = 1 THEN 'After Downgrade'
            ELSE 'No Prior Plan Change'
        END AS prior_change_type
    FROM [dbo].[ravenstack_churn_events] AS e
),
accounts_base AS (
    SELECT account_id FROM [dbo].[ravenstack_accounts]
)
SELECT
    cl.churn_year,
    cl.churn_quarter,
    cl.prior_change_type,
    COUNT(DISTINCT cl.account_id)                                               AS churned_accounts,
    COUNT(DISTINCT ab.account_id)                                               AS total_accounts,
    COUNT(DISTINCT cl.account_id) * 100.0 / COUNT(DISTINCT ab.account_id)      AS churn_rate_pct
FROM churn_labels AS cl
CROSS JOIN accounts_base AS ab
GROUP BY cl.churn_year, cl.churn_quarter, cl.prior_change_type
ORDER BY cl.churn_year, cl.churn_quarter, cl.prior_change_type;


-- =============================================================================
-- SECTION 8: FEATURE USAGE ANALYSIS
-- =============================================================================

-- 8a. Active subscriptions per feature (adoption breadth)
SELECT
    f.feature_name,
    COUNT(DISTINCT f.subscription_id) AS active_subscriptions
FROM [dbo].[ravenstack_feature_usage] AS f
GROUP BY f.feature_name
ORDER BY active_subscriptions DESC;


-- 8b. Power features vs. nice-to-have (usage depth: count + duration)
SELECT
    f.feature_name,
    COUNT(DISTINCT f.subscription_id)  AS active_subscriptions,
    SUM(f.usage_count)                 AS total_usage_count,
    SUM(f.usage_duration_secs)         AS total_usage_duration_secs
FROM [dbo].[ravenstack_feature_usage] AS f
GROUP BY f.feature_name
ORDER BY total_usage_count DESC, total_usage_duration_secs DESC;


-- 8c. Feature usage by plan tier
SELECT
    s.plan_tier,
    f.feature_name,
    SUM(f.usage_count) AS total_usage
FROM [dbo].[ravenstack_subscriptions] AS s
JOIN [dbo].[ravenstack_feature_usage] AS f ON s.subscription_id = f.subscription_id
GROUP BY s.plan_tier, f.feature_name
ORDER BY s.plan_tier DESC;


-- 8d. Features driving longer subscription tenure (retention indicators)
SELECT
    f.feature_name,
    a.country,
    a.plan_tier,
    DATEDIFF(DAY, s.start_date, s.end_date) AS subscription_days,
    SUM(s.mrr_amount)                        AS total_mrr,
    SUM(s.arr_amount)                        AS total_arr,
    COUNT(s.subscription_id)                 AS subscription_count
FROM [dbo].[ravenstack_accounts] AS a
JOIN [dbo].[ravenstack_subscriptions] AS s  ON a.account_id = s.account_id
JOIN [dbo].[ravenstack_feature_usage] AS f  ON f.subscription_id = s.subscription_id
GROUP BY a.country, f.feature_name, a.plan_tier, DATEDIFF(DAY, s.start_date, s.end_date)
ORDER BY subscription_days DESC;


-- 8e. Feature profitability vs. support burden
SELECT
    f.feature_name,
    SUM(s.arr_amount)    AS total_arr,
    SUM(s.mrr_amount)    AS total_mrr,
    COUNT(t.ticket_id)   AS total_support_tickets
FROM [dbo].[ravenstack_subscriptions] AS s
JOIN [dbo].[ravenstack_feature_usage] AS f     ON s.subscription_id = f.subscription_id
JOIN [dbo].[ravenstack_support_tickets] AS t   ON t.account_id = s.account_id
GROUP BY f.feature_name
ORDER BY total_arr DESC;


-- 8f. Engagement vs. churn: 30-day usage compared between churned and retained subs
WITH recent_usage AS (
    SELECT
        f.subscription_id,
        SUM(f.usage_count)         AS usage_count_30d,
        SUM(f.usage_duration_secs) AS usage_duration_30d
    FROM [dbo].[ravenstack_feature_usage] AS f
    WHERE f.usage_date >= DATEADD(DAY, -30, CONVERT(DATE, GETDATE()))
    GROUP BY f.subscription_id
),
usage_with_churn AS (
    SELECT
        s.subscription_id,
        COALESCE(r.usage_count_30d,    0) AS usage_count_30d,
        COALESCE(r.usage_duration_30d, 0) AS usage_duration_30d,
        s.churn_flag
    FROM [dbo].[ravenstack_subscriptions] AS s
    LEFT JOIN recent_usage AS r ON s.subscription_id = r.subscription_id
)
SELECT
    churn_flag,
    COUNT(*)                        AS subscriptions,
    AVG(usage_count_30d    * 1.0)   AS avg_usage_count_30d,
    AVG(usage_duration_30d * 1.0)   AS avg_usage_duration_30d
FROM usage_with_churn
GROUP BY churn_flag;


-- 8g. Beta feature impact on churn and upgrade rates
WITH subs_beta_flag AS (
    SELECT
        f.subscription_id,
        MAX(CASE WHEN f.is_beta_feature = 1 THEN 1 ELSE 0 END) AS used_beta
    FROM [dbo].[ravenstack_feature_usage] AS f
    GROUP BY f.subscription_id
)
SELECT
    sb.used_beta,
    COUNT(*)                                                                 AS subscriptions,
    SUM(CASE WHEN s.churn_flag   = 1 THEN 1 ELSE 0 END)                     AS churned_subs,
    SUM(CASE WHEN s.upgrade_flag = 1 THEN 1 ELSE 0 END)                     AS upgraded_subs,
    SUM(CASE WHEN s.churn_flag   = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)  AS churn_rate_pct,
    SUM(CASE WHEN s.upgrade_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)  AS upgrade_rate_pct
FROM subs_beta_flag AS sb
JOIN [dbo].[ravenstack_subscriptions] AS s ON sb.subscription_id = s.subscription_id
GROUP BY sb.used_beta;


-- 8h. Error-heavy features vs. churn (subscription-level error rate buckets)
WITH subs_error_stats AS (
    SELECT
        f.subscription_id,
        SUM(f.usage_count)  AS total_usage_count,
        SUM(f.error_count)  AS total_error_count,
        CASE
            WHEN SUM(f.usage_count) = 0 THEN 0.0
            ELSE SUM(f.error_count) * 1.0 / SUM(f.usage_count)
        END AS error_rate
    FROM [dbo].[ravenstack_feature_usage] AS f
    GROUP BY f.subscription_id
)
SELECT
    CASE
        WHEN se.error_rate >= 0.1 THEN 'High Error Rate (>=10%)'
        WHEN se.error_rate  > 0   THEN 'Low Error Rate (>0%)'
        ELSE 'No Errors'
    END                                                                     AS error_bucket,
    COUNT(*)                                                                AS subscriptions,
    SUM(CASE WHEN s.churn_flag = 1 THEN 1 ELSE 0 END)                      AS churned_subs,
    SUM(CASE WHEN s.churn_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)   AS churn_rate_pct
FROM subs_error_stats AS se
JOIN [dbo].[ravenstack_subscriptions] AS s ON se.subscription_id = s.subscription_id
GROUP BY
    CASE
        WHEN se.error_rate >= 0.1 THEN 'High Error Rate (>=10%)'
        WHEN se.error_rate  > 0   THEN 'Low Error Rate (>0%)'
        ELSE 'No Errors'
    END;


-- =============================================================================
-- SECTION 9: TRIAL & CONVERSION ANALYSIS
-- =============================================================================

-- 9a. Trial-to-paid conversion rate
WITH trial_subs AS (
    SELECT
        s.account_id,
        MIN(s.start_date) AS first_trial_start
    FROM [dbo].[ravenstack_subscriptions] AS s
    WHERE s.is_trial = 1
    GROUP BY s.account_id
),
paid_after_trial AS (
    SELECT DISTINCT t.account_id
    FROM trial_subs AS t
    JOIN [dbo].[ravenstack_subscriptions] AS s
        ON t.account_id = s.account_id
       AND s.is_trial = 0
       AND s.start_date >= t.first_trial_start
)
SELECT
    (SELECT COUNT(*) FROM trial_subs)                                  AS trial_accounts,
    (SELECT COUNT(*) FROM paid_after_trial)                            AS converted_accounts,
    (SELECT COUNT(*) * 100.0 FROM paid_after_trial)
        / NULLIF((SELECT COUNT(*) FROM trial_subs), 0)                 AS trial_conversion_rate_pct;


-- =============================================================================
-- END OF SCRIPT
-- =============================================================================
