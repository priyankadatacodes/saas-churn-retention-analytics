-- =====================================================================
-- ---------------------------------------------------------------------
-- Business questions answered here:
--   - Do low-usage customers churn more?
--   - Which features are most/least used?
--   - How does usage differ between churned and active customers?
-- =====================================================================

USE saas_analytics;

-- 1. Churn rate by usage bucket (Low / Medium / High — built in Python
--    and already stored in master_customer_analytics.usage_bucket)
SELECT
    usage_bucket,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS churn_rate_pct
FROM master_customer_analytics
GROUP BY usage_bucket
ORDER BY FIELD(usage_bucket, 'Low Usage', 'Medium Usage', 'High Usage');

-- 2. Average usage metrics: churned vs active customers
SELECT
    is_churned,
    ROUND(AVG(total_usage_events), 1) AS avg_usage_events,
    ROUND(AVG(distinct_features_used), 1) AS avg_distinct_features,
    ROUND(AVG(active_usage_days), 1) AS avg_active_usage_days
FROM master_customer_analytics
GROUP BY is_churned;

-- 3. Most-used features overall (by total usage_count)
SELECT
    feature_name,
    COUNT(*) AS usage_events,
    SUM(usage_count) AS total_usage_count,
    ROUND(AVG(usage_duration_secs), 1) AS avg_duration_secs
FROM fact_usage
GROUP BY feature_name
ORDER BY total_usage_count DESC
LIMIT 10;

-- 4. Least-used features (candidates for removal or better onboarding)
SELECT
    feature_name,
    COUNT(*) AS usage_events,
    SUM(usage_count) AS total_usage_count
FROM fact_usage
GROUP BY feature_name
ORDER BY total_usage_count ASC
LIMIT 10;

-- 5. Feature error rates (features with unusually high error_count may
--    be driving support tickets and churn)
SELECT
    feature_name,
    SUM(usage_count) AS total_usage_count,
    SUM(error_count) AS total_errors,
    ROUND(100.0 * SUM(error_count) / NULLIF(SUM(usage_count), 0), 2) AS error_rate_pct
FROM fact_usage
GROUP BY feature_name
ORDER BY error_rate_pct DESC
LIMIT 10;