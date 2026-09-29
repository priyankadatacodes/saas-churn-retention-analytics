-- =====================================================================
-- ---------------------------------------------------------------------
-- Business questions answered here:
--   - Do customers with more support tickets churn more?
--   - Is satisfaction score associated with churn?
--   - Do high-priority / escalated tickets correlate with churn?
-- =====================================================================

USE saas_analytics;

-- 1. Average support ticket count: churned vs active customers
SELECT
    is_churned,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_support_tickets), 2) AS avg_support_tickets,
    ROUND(AVG(high_priority_tickets), 2) AS avg_high_priority_tickets,
    ROUND(AVG(escalated_tickets), 2) AS avg_escalated_tickets
FROM master_customer_analytics
GROUP BY is_churned;

-- 2. Average satisfaction score: churned vs active customers

SELECT
    is_churned,
    ROUND(AVG(avg_satisfaction_score), 2) AS avg_satisfaction_score,
    COUNT(avg_satisfaction_score) AS customers_with_a_score
FROM master_customer_analytics
GROUP BY is_churned;

-- 3. Bucket customers by support-ticket volume and compare churn rate
SELECT
    CASE
        WHEN total_support_tickets = 0 THEN '0 tickets'
        WHEN total_support_tickets BETWEEN 1 AND 3 THEN '1-3 tickets'
        WHEN total_support_tickets BETWEEN 4 AND 6 THEN '4-6 tickets'
        ELSE '7+ tickets'
    END AS support_ticket_bucket,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS churn_rate_pct
FROM master_customer_analytics
GROUP BY support_ticket_bucket
ORDER BY MIN(total_support_tickets);

-- 4. Average resolution time by priority level
SELECT
    priority,
    COUNT(*) AS ticket_count,
    ROUND(AVG(resolution_time_hours), 1) AS avg_resolution_time_hours,
    ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction_score
FROM fact_support
GROUP BY priority
ORDER BY avg_resolution_time_hours DESC;

-- 5. Escalated tickets: do they get worse satisfaction scores?
SELECT
    escalation_flag,
    COUNT(*) AS ticket_count,
    ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction_score,
    ROUND(AVG(resolution_time_hours), 1) AS avg_resolution_time_hours
FROM fact_support
GROUP BY escalation_flag;