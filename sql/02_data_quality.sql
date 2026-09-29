
USE saas_analytics;

-- 1. Duplicate check: are there any exact duplicate rows in dim_customer?
SELECT account_id, COUNT(*) AS n
FROM dim_customer
GROUP BY account_id
HAVING COUNT(*) > 1;

-- 2. Referential integrity: any subscription pointing to a customer
SELECT s.subscription_id, s.account_id
FROM fact_subscription s
LEFT JOIN dim_customer c ON s.account_id = c.account_id
WHERE c.account_id IS NULL;

-- 3. How many customers have NO subscriptions at all?
SELECT COUNT(*) AS customers_with_no_subscriptions
FROM dim_customer c
LEFT JOIN fact_subscription s ON c.account_id = s.account_id
WHERE s.subscription_id IS NULL;

-- 4. How many active subscriptions (end_date IS NULL) vs churned ones?
SELECT
    CASE WHEN end_date IS NULL THEN 'Active' ELSE 'Ended' END AS subscription_status,
    COUNT(*) AS subscription_count
FROM fact_subscription
GROUP BY subscription_status;

-- 5. Support tickets missing a satisfaction score (nulls found earlier)
SELECT
    COUNT(*) AS total_tickets,
    SUM(CASE WHEN satisfaction_score IS NULL THEN 1 ELSE 0 END) AS missing_satisfaction,
    ROUND(100.0 * SUM(CASE WHEN satisfaction_score IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS pct_missing
FROM fact_support;
