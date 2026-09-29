--   - Customer tenure (avg + median)
--   - Do high-value customers churn disproportionately?
--   - Usage trend in the months leading up to churn
--   - Support ticket concentration by plan
--   - Which churn reason causes the most MRR loss?
--   - Do churn reasons vary by plan?
--   - Early-tenure churn risk (does churn concentrate in new customers?)
--   - 12-month cohort retention (extends 08_cohort_analysis.sql)
--   - Composite risk score + concrete "Top At-Risk Customers" list
-- =====================================================================

USE saas_analytics;

-- ---------------------------------------------------------------------
-- 1. Average & median customer tenure (in days)
--    Churned customers: signup_date -> churn_date
--    Active customers:  signup_date -> reference date (still counting)
-- ---------------------------------------------------------------------
WITH tenure_calc AS (
    SELECT
        account_id,2
        is_churned,
        CASE
            WHEN is_churned = 'Yes' THEN DATEDIFF(churn_date, signup_date)
            ELSE DATEDIFF('2024-12-31', signup_date)
        END AS tenure_days
    FROM master_customer_analytics
),
ranked_tenure AS (
    SELECT
        tenure_days,
        ROW_NUMBER() OVER (ORDER BY tenure_days) AS rn,
        COUNT(*) OVER () AS cnt
    FROM tenure_calc
)
SELECT
    (SELECT ROUND(AVG(tenure_days), 0) FROM tenure_calc) AS avg_tenure_days,
    (SELECT AVG(tenure_days) FROM ranked_tenure
        WHERE rn IN (FLOOR((cnt + 1) / 2), FLOOR((cnt + 2) / 2))) AS median_tenure_days;

-- ---------------------------------------------------------------------
-- 2. Do high-value customers churn disproportionately?
--    Bucket customers into value quartiles by total_historical_mrr
-- ---------------------------------------------------------------------
WITH value_quartile AS (
    SELECT
        account_id,
        total_historical_mrr,
        is_churned,
        NTILE(4) OVER (ORDER BY total_historical_mrr DESC) AS value_quartile
        -- quartile 1 = highest-value customers, quartile 4 = lowest
    FROM master_customer_analytics
)
SELECT
    value_quartile,
    COUNT(*) AS customers,
    SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_rate_pct
FROM value_quartile
GROUP BY value_quartile
ORDER BY value_quartile;

-- ---------------------------------------------------------------------
-- 3. Usage trend in the months leading up to churn (churned customers)
--    Does usage visibly decline right before churn, or stay flat?
-- ---------------------------------------------------------------------
WITH churned_usage AS (
    SELECT
        s.account_id,
        c.churn_date,
        u.usage_date,
        u.usage_count,
        TIMESTAMPDIFF(MONTH, u.usage_date, c.churn_date) AS months_before_churn
    FROM fact_usage u
    JOIN fact_subscription s ON u.subscription_id = s.subscription_id
    JOIN (
        SELECT account_id, MAX(churn_date) AS churn_date
        FROM fact_churn
        GROUP BY account_id
    ) c ON s.account_id = c.account_id
    WHERE TIMESTAMPDIFF(MONTH, u.usage_date, c.churn_date) BETWEEN 0 AND 5
)
SELECT
    months_before_churn,
    COUNT(DISTINCT account_id) AS customers,
    ROUND(AVG(usage_count), 2) AS avg_usage_count_per_event,
    SUM(usage_count) AS total_usage_count
FROM churned_usage
GROUP BY months_before_churn
ORDER BY months_before_churn DESC;

-- ---------------------------------------------------------------------
-- 4. Support ticket concentration by plan
-- ---------------------------------------------------------------------
SELECT
    current_plan,
    COUNT(*) AS customers,
    SUM(total_support_tickets) AS total_tickets,
    ROUND(AVG(total_support_tickets), 2) AS avg_tickets_per_customer
FROM master_customer_analytics
GROUP BY current_plan
ORDER BY avg_tickets_per_customer DESC;

-- ---------------------------------------------------------------------
-- 5. Which churn reason causes the most MRR loss?
-- ---------------------------------------------------------------------
SELECT
    fc.reason_code,
    COUNT(DISTINCT fc.account_id) AS churned_accounts,
    SUM(m.total_historical_mrr) AS historical_mrr_lost
FROM fact_churn fc
JOIN master_customer_analytics m ON fc.account_id = m.account_id
GROUP BY fc.reason_code
ORDER BY historical_mrr_lost DESC;

-- ---------------------------------------------------------------------
-- 6. Do churn reasons vary by plan?
-- ---------------------------------------------------------------------
SELECT
    m.current_plan,
    fc.reason_code,
    COUNT(*) AS event_count
FROM fact_churn fc
JOIN master_customer_analytics m ON fc.account_id = m.account_id
GROUP BY m.current_plan, fc.reason_code
ORDER BY m.current_plan, event_count DESC;

-- ---------------------------------------------------------------------
-- 7. Early-tenure churn risk: does churn concentrate in newer customers?
-- ---------------------------------------------------------------------
WITH tenure_calc2 AS (
    SELECT
        account_id, is_churned,
        CASE WHEN is_churned = 'Yes' THEN DATEDIFF(churn_date, signup_date)
             ELSE DATEDIFF('2024-12-31', signup_date) END AS tenure_days
    FROM master_customer_analytics
)
SELECT
    CASE
        WHEN tenure_days < 90 THEN '0-3 months'
        WHEN tenure_days < 180 THEN '3-6 months'
        WHEN tenure_days < 365 THEN '6-12 months'
        ELSE '12+ months'
    END AS tenure_bucket,
    COUNT(*) AS customers,
    SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_rate_pct
FROM tenure_calc2
GROUP BY tenure_bucket
ORDER BY MIN(tenure_days);

-- ---------------------------------------------------------------------
-- 8. 12-month cohort retention ( which
--    only went out to 6 months). Only shows cohorts old enough (signed
--    up by Dec 2023) to actually have a full 12-month window to measure.
-- ---------------------------------------------------------------------
WITH customer_cohorts AS (
    SELECT
        m.account_id,
        DATE_FORMAT(a.signup_date, '%Y-%m') AS cohort_month,
        m.is_churned,
        CASE WHEN m.is_churned = 'Yes'
             THEN TIMESTAMPDIFF(MONTH, a.signup_date, m.churn_date)
             ELSE NULL END AS months_to_churn
    FROM master_customer_analytics m
    JOIN dim_customer a ON m.account_id = a.account_id
),
cohort_sizes2 AS (
    SELECT cohort_month, COUNT(*) AS cohort_size FROM customer_cohorts GROUP BY cohort_month
),
month_offsets2 AS (
    SELECT 0 AS month_offset UNION ALL SELECT 3 UNION ALL SELECT 6
    UNION ALL SELECT 9 UNION ALL SELECT 12
)
SELECT
    c.cohort_month,
    s.cohort_size,
    o.month_offset,
    ROUND(
        100.0 * SUM(
            CASE WHEN c.is_churned = 'No' THEN 1
                 WHEN c.months_to_churn > o.month_offset THEN 1
                 ELSE 0 END
        ) / s.cohort_size, 1
    ) AS pct_retained
FROM customer_cohorts c
JOIN cohort_sizes2 s ON c.cohort_month = s.cohort_month
CROSS JOIN month_offsets2 o
WHERE c.cohort_month <= '2023-12'
GROUP BY c.cohort_month, s.cohort_size, o.month_offset
ORDER BY c.cohort_month, o.month_offset;

-- ---------------------------------------------------------------------
-- 9. Composite risk score + concrete "Top At-Risk Customers" list
--    Score components (each adds risk points):
--      +2 if Low Usage bucket, +1 if Medium Usage
--      +2 if >=5 support tickets, +1 if 3-4 tickets
--      +1 if tenure under 180 days (new customers are inherently riskier)
--    Only ranks CURRENTLY ACTIVE, paying customers — no point flagging
--    someone who already churned.
-- ---------------------------------------------------------------------
SELECT
    account_id,
    account_name,
    current_plan,
    current_mrr,
    total_usage_events,
    total_support_tickets,
    DATEDIFF('2024-12-31', signup_date) AS tenure_days,
    (
        (CASE WHEN usage_bucket = 'Low Usage' THEN 2
              WHEN usage_bucket = 'Medium Usage' THEN 1 ELSE 0 END)
        + (CASE WHEN total_support_tickets >= 5 THEN 2
                WHEN total_support_tickets >= 3 THEN 1 ELSE 0 END)
        + (CASE WHEN DATEDIFF('2024-12-31', signup_date) < 180 THEN 1 ELSE 0 END)
    ) AS risk_score
FROM master_customer_analytics
WHERE is_churned = 'No' AND current_mrr > 0
ORDER BY risk_score DESC, current_mrr DESC
LIMIT 15;