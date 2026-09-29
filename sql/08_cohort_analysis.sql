-- =====================================================================

USE saas_analytics;

-- 1. Basic cohort sizes: how many customers signed up each month?
SELECT
    DATE_FORMAT(signup_date, '%Y-%m') AS signup_month,
    COUNT(*) AS cohort_size
FROM dim_customer
GROUP BY signup_month
ORDER BY signup_month;

-- 2. For each customer, how many months after signup did they churn
--    (if they churned at all)? This is the building block for the
--    cohort retention curve.
SELECT
    m.account_id,
    a.signup_date,
    m.churn_date,
    m.is_churned,
    CASE
        WHEN m.is_churned = 'Yes'
        THEN TIMESTAMPDIFF(MONTH, a.signup_date, m.churn_date)
        ELSE NULL
    END AS months_to_churn
FROM master_customer_analytics m
JOIN dim_customer a ON m.account_id = a.account_id
LIMIT 20;

-- 3. Cohort retention table: % of each signup cohort still ACTIVE
--    (not yet churned) at 0, 1, 2, 3, ... months after signup.
--    We cap the lookout window at 6 months here for readability —
--    extend the "WHERE months_since_signup <= 6" filter if you want more.
WITH customer_cohorts AS (
    SELECT
        m.account_id,
        DATE_FORMAT(a.signup_date, '%Y-%m') AS cohort_month,
        m.is_churned,
        CASE
            WHEN m.is_churned = 'Yes'
            THEN TIMESTAMPDIFF(MONTH, a.signup_date, m.churn_date)
            ELSE NULL
        END AS months_to_churn
    FROM master_customer_analytics m
    JOIN dim_customer a ON m.account_id = a.account_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
),
-- one row per (cohort, month_offset) with a "still active" flag
month_offsets AS (
    SELECT 0 AS month_offset UNION ALL SELECT 1 UNION ALL SELECT 2
    UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6
)
SELECT
    c.cohort_month,
    s.cohort_size,
    o.month_offset,
    SUM(
        CASE
            WHEN c.is_churned = 'No' THEN 1                     -- never churned: always "active"
            WHEN c.months_to_churn > o.month_offset THEN 1       -- churned, but LATER than this month
            ELSE 0
        END
    ) AS customers_still_active,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN c.is_churned = 'No' THEN 1
                WHEN c.months_to_churn > o.month_offset THEN 1
                ELSE 0
            END
        ) / s.cohort_size,
        1
    ) AS pct_retained
FROM customer_cohorts c
JOIN cohort_sizes s ON c.cohort_month = s.cohort_month
CROSS JOIN month_offsets o
GROUP BY c.cohort_month, s.cohort_size, o.month_offset
ORDER BY c.cohort_month, o.month_offset;