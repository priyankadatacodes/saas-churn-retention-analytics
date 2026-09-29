-- =====================================================================

USE saas_analytics;

-- ---------------------------------------------------------------------
-- dim_customer (was: accounts.csv)
-- ---------------------------------------------------------------------
ALTER TABLE dim_customer
    MODIFY account_id VARCHAR(20) NOT NULL,
    ADD PRIMARY KEY (account_id);

-- ---------------------------------------------------------------------
-- fact_subscription (was: subscriptions.csv)
-- ---------------------------------------------------------------------
ALTER TABLE fact_subscription
    MODIFY subscription_id VARCHAR(20) NOT NULL,
    MODIFY account_id VARCHAR(20) NOT NULL,
    ADD PRIMARY KEY (subscription_id),
    ADD CONSTRAINT fk_subscription_customer
        FOREIGN KEY (account_id) REFERENCES dim_customer(account_id);

-- ---------------------------------------------------------------------
-- fact_usage (was: usage.csv)
-- ---------------------------------------------------------------------
ALTER TABLE fact_usage
    MODIFY usage_id VARCHAR(20) NOT NULL,
    MODIFY subscription_id VARCHAR(20) NOT NULL,
    ADD CONSTRAINT fk_usage_subscription
        FOREIGN KEY (subscription_id) REFERENCES fact_subscription(subscription_id);

CREATE INDEX idx_usage_id ON fact_usage(usage_id);

-- ---------------------------------------------------------------------
-- fact_support (was: support.csv)
-- ---------------------------------------------------------------------
ALTER TABLE fact_support
    MODIFY ticket_id VARCHAR(20) NOT NULL,
    MODIFY account_id VARCHAR(20) NOT NULL,
    ADD PRIMARY KEY (ticket_id),
    ADD CONSTRAINT fk_support_customer
        FOREIGN KEY (account_id) REFERENCES dim_customer(account_id);

-- ---------------------------------------------------------------------
-- fact_churn (was: churn.csv)
-- ---------------------------------------------------------------------
ALTER TABLE fact_churn
    MODIFY churn_event_id VARCHAR(20) NOT NULL,
    MODIFY account_id VARCHAR(20) NOT NULL,
    ADD PRIMARY KEY (churn_event_id),
    ADD CONSTRAINT fk_churn_customer
        FOREIGN KEY (account_id) REFERENCES dim_customer(account_id);

-- ---------------------------------------------------------------------
-- ---------------------------------------------------------------------
ALTER TABLE master_customer_analytics
    MODIFY account_id VARCHAR(20) NOT NULL,
    ADD PRIMARY KEY (account_id);

-- Quick sanity check: row counts should match 
SELECT 'dim_customer' AS table_name, COUNT(*) AS row_count FROM dim_customer
UNION ALL
SELECT 'fact_subscription', COUNT(*) FROM fact_subscription
UNION ALL
SELECT 'fact_usage', COUNT(*) FROM fact_usage
UNION ALL
SELECT 'fact_support', COUNT(*) FROM fact_support
UNION ALL
SELECT 'fact_churn', COUNT(*) FROM fact_churn
UNION ALL
SELECT 'master_customer_analytics', COUNT(*) FROM master_customer_analytics;