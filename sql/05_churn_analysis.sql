-- =====================================================================
-- 05_churn_analysis.sql
-- ---------------------------------------------------------------------
-- Business questions answered here:
--   - What is the overall customer churn rate?
--   - Which plans / industries / countries churn the most?
--   - What are the top churn reasons?
-- =====================================================================

USE saas_analytics;

-- 1. Overall customer churn rate

SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS churn_rate_pct
FROM master_customer_analytics;

-- 2. Churn rate by plan
SELECT
    current_plan,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS churn_rate_pct
FROM master_customer_analytics
GROUP BY current_plan
ORDER BY churn_rate_pct DESC;

-- 3. Churn rate by industry
SELECT
    industry,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS churn_rate_pct
FROM master_customer_analytics
GROUP BY industry
ORDER BY churn_rate_pct DESC;

-- 4. Top churn reasons 
SELECT
    reason_code,
    COUNT(*) AS churn_event_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fact_churn), 1) AS pct_of_all_churn_events
FROM fact_churn
GROUP BY reason_code
ORDER BY churn_event_count DESC;

-- 5. How many churned customers were later reactivated?
SELECT
    is_reactivation,
    COUNT(*) AS event_count
FROM fact_churn
GROUP BY is_reactivation;

-- 6. Monthly churn trend (how many churn events happened each month?)
SELECT
    DATE_FORMAT(churn_date, '%Y-%m') AS churn_month,
    COUNT(*) AS churn_events
FROM fact_churn
GROUP BY churn_month
ORDER BY churn_month;

-- 7. Window function example: month-over-month change in churn events

WITH monthly_churn AS (
    SELECT
        DATE_FORMAT(churn_date, '%Y-%m') AS churn_month,
        COUNT(*) AS churn_events
    FROM fact_churn
    GROUP BY churn_month
)
SELECT
    churn_month,
    churn_events,
    LAG(churn_events) OVER (ORDER BY churn_month) AS prev_month_churn_events,
    churn_events - LAG(churn_events) OVER (ORDER BY churn_month) AS change_vs_prev_month
FROM monthly_churn
ORDER BY churn_month;