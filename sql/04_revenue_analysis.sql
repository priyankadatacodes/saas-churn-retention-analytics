-- =====================================================================
-- 04_revenue_analysis.sql
-- ---------------------------------------------------------------------
-- Business questions answered here:
--   - What is our current MRR and ARR?
--   - Which plans generate the most revenue?
--   - How much revenue is concentrated in our top customers?
-- =====================================================================

USE saas_analytics;

-- 1. Company-wide current MRR and ARR
--    MRR = sum of mrr_amount for ACTIVE subscriptions only (end_date IS NULL)
--    ARR = MRR x 12
SELECT
    SUM(mrr_amount) AS total_current_mrr,
    SUM(mrr_amount) * 12 AS total_current_arr
FROM fact_subscription
WHERE end_date IS NULL;

-- 2. MRR by plan tier (active subscriptions only)
SELECT
    plan_tier,
    COUNT(*) AS active_subscriptions,
    SUM(mrr_amount) AS total_mrr,
    ROUND(AVG(mrr_amount), 2) AS avg_mrr_per_subscription
FROM fact_subscription
WHERE end_date IS NULL
GROUP BY plan_tier
ORDER BY total_mrr DESC;

-- 3. MRR by billing frequency (monthly vs annual customers)
SELECT
    billing_frequency,
    COUNT(*) AS active_subscriptions,
    SUM(mrr_amount) AS total_mrr
FROM fact_subscription
WHERE end_date IS NULL
GROUP BY billing_frequency;

-- 4. Revenue concentration: what % of total MRR comes from the top 10% of customers?

WITH ranked_customers AS (
    SELECT
        account_id,
        current_mrr,
        NTILE(10) OVER (ORDER BY current_mrr DESC) AS decile
    FROM master_customer_analytics
    WHERE current_mrr > 0
)
SELECT
    SUM(CASE WHEN decile = 1 THEN current_mrr ELSE 0 END) AS mrr_from_top_10_pct,
    SUM(current_mrr) AS total_mrr,
    ROUND(
        100.0 * SUM(CASE WHEN decile = 1 THEN current_mrr ELSE 0 END) / SUM(current_mrr),
        1
    ) AS pct_of_mrr_from_top_10_pct
FROM ranked_customers;

-- 5. Revenue churn: how much MRR was lost from subscriptions that ended?
--    (Revenue Churn Rate = Lost MRR / Starting MRR 
SELECT
    SUM(CASE WHEN end_date IS NOT NULL THEN mrr_amount ELSE 0 END) AS lost_mrr_from_ended_subs,
    SUM(mrr_amount) AS total_mrr_all_subscriptions,
    ROUND(
        100.0 * SUM(CASE WHEN end_date IS NOT NULL THEN mrr_amount ELSE 0 END)
        / SUM(mrr_amount),
        1
    ) AS revenue_churn_rate_pct
FROM fact_subscription;