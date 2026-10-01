# SaaS Customer Churn, Revenue & Retention Analytics

![Python](https://img.shields.io/badge/Python-3.9%2B-3776AB?logo=python\&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-8.0%2B-4479A1?logo=mysql\&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Analytics-336791)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?logo=powerbi\&logoColor=black)
![Status](https://img.shields.io/badge/Status-Completed-success)

## Executive Summary

End-to-end SaaS analytics project focused on **customer churn, recurring revenue, product engagement, support behavior, and retention risk**.

The project combines **Python, MySQL, SQL, and Power BI** to transform raw relational data into customer-level analytics, churn analysis, revenue exposure metrics, risk identification, and stakeholder-ready reporting.

### Business Question

> **Which customers are leaving, why are they leaving, how much recurring revenue is exposed, and which active customers require retention attention?**

---

## 1. Business Problem

A B2B SaaS company offers **Enterprise, Pro, and Basic** subscription plans across multiple industries and acquisition channels.

Leadership needs a reliable view of:

* Customer and revenue churn
* Churn patterns by plan, industry, channel, and tenure
* Recurring revenue and customer value
* Product usage and support behavior
* Active customers with elevated retention risk
* Revenue concentration and MRR exposure
* Key churn drivers

The project addresses these questions through **data-quality reconciliation, customer-level modeling, SQL analytics, and Power BI reporting**.

---

## 2. Business Objectives

* Measure customer and revenue churn
* Identify churn patterns across customer segments
* Analyze recurring revenue and customer value
* Identify customers with elevated retention risk
* Analyze product usage and support behavior
* Quantify revenue concentration and MRR exposure
* Build an interactive Power BI dashboard
* Translate findings into retention actions

---

## 3. Dataset

The project uses five relational CSV datasets.

| Dataset         | Grain          |   Rows |
| --------------- | -------------- | -----: |
| `accounts`      | Customer       |    500 |
| `subscriptions` | Subscription   |  5,000 |
| `usage`         | Usage Event    | 25,000 |
| `support`       | Support Ticket |  2,000 |
| `churn`         | Churn Event    |    600 |

### Customer Segments

**Plans**

* Enterprise
* Pro
* Basic

**Industries**

* DevTools
* FinTech
* Cybersecurity
* HealthTech
* EdTech

**Acquisition Channels**

* Organic
* Ads
* Event
* Partner
* Other

The `churn` dataset is event-level, allowing customers to appear multiple times due to churn and reactivation events. Usage data is connected to customers through `subscription_id`.

---

## 4. Analytics Workflow

```text
Raw CSV Data
     ↓
Python Data Ingestion
     ↓
Data Quality & Validation
     ↓
Customer-Level Aggregation
     ↓
MySQL Star Schema
     ↓
SQL Business Analysis
     ↓
Power BI Dashboard
     ↓
Churn & Retention Insights
```

The workflow covers ingestion, quality checks, customer-level modeling, SQL analysis, dashboard development, and retention analysis.

---

## 5. Data Preparation & Quality

Python is used for:

* Programmatic data ingestion
* Data cleaning
* Missing-value checks
* Duplicate checks
* Primary-key validation
* Referential-integrity checks
* Grain validation
* Customer-level aggregation
* Exploratory analysis
* Master dataset creation

### Customer-Level Modeling

The source datasets operate at different grains:

| Table           | Grain          |
| --------------- | -------------- |
| `accounts`      | Customer       |
| `subscriptions` | Subscription   |
| `usage`         | Usage Event    |
| `support`       | Support Ticket |
| `churn`         | Churn Event    |

Directly joining these tables can create **fan-out and aggregation errors**.

For example:

```text
10 subscriptions
× 50 usage events
× 4 support tickets
= 2,000 rows
```

Instead, each source is aggregated to **one row per customer** before being merged with the customer-level `accounts` dataset.

The final master dataset is validated to ensure exactly one row per customer.

### Usage Relationship

```text
Usage
  ↓
Subscription
  ↓
Customer
```

Because `usage` does not contain `account_id`, usage records must first be mapped through subscriptions before customer-level aggregation.

---

## 6. Data Quality Reconciliation

A key issue was identified between:

* `accounts.csv` → `churn_flag`
* `churn.csv` → churn events

These sources disagree for a meaningful number of customers.

For analytical purposes, the **churn events table is treated as the source of truth** because it provides detailed event-level records.

This definition is applied consistently across the analytical layer.

---

## 7. Data Model

The cleaned data is loaded into a MySQL **star schema**.

```text
                 dim_customer
                      |
        +-------------+-------------+
        |             |             |
        ↓             ↓             ↓
fact_subscription  fact_usage  fact_support
                      |
                      ↓
                 fact_churn

          master_customer_analytics
```

### Core Tables

* `dim_customer`
* `fact_subscription`
* `fact_usage`
* `fact_support`
* `fact_churn`
* `master_customer_analytics`

This structure separates customer dimensions from transactional fact tables and supports controlled joins, analytical queries, and referential integrity.

---

## 8. SQL Analysis

MySQL is used to analyze:

* Customer behavior
* Revenue
* Churn
* Product usage
* Support activity
* Cohort retention
* Customer risk
* Customer value

### SQL Techniques

* Joins
* Common Table Expressions
* Aggregations
* Window Functions
* `RANK`
* `LAG`
* `NTILE`
* Cohort Analysis
* Customer Risk Scoring
* Value Quartile Analysis

The SQL layer also produces a **composite customer risk score** and a **Top-15 at-risk customer list**.

---

## 9. Power BI Dashboard

The project includes a **5-page interactive Power BI dashboard**.

| Dashboard Page      | Focus                                   |
| ------------------- | --------------------------------------- |
| Executive Overview  | Business KPIs and SaaS performance      |
| Churn & Retention   | Churn and retention metrics             |
| Customer Health     | Engagement and risk indicators          |
| Revenue Risk        | MRR exposure and revenue concentration  |
| Acquisition & Value | Acquisition channels and customer value |

### Dashboard Filters

* Date Range
* Plan
* Industry
* Customer Status
* Acquisition Channel

Power BI reproduces the KPI logic from the SQL analytical layer using DAX measures and calculated columns.

---

## 10. Key KPIs

| KPI                   | Definition                                                  |
| --------------------- | ----------------------------------------------------------- |
| Total MRR             | MRR from subscriptions with no `end_date`                   |
| Active MRR            | MRR from accounts where `is_churned = No`                   |
| ARR                   | Active MRR × 12                                             |
| Active Customers      | Distinct customers where `is_churned = No`                  |
| Customer Churn Rate   | Churned customers ÷ total customers                         |
| Revenue Churn Rate    | Ended-subscription MRR ÷ total MRR ever billed              |
| ARPU                  | Active MRR ÷ Active Customers                               |
| Retention Rate        | 1 − Customer Churn Rate                                     |
| MRR at Risk           | Active MRR from low-usage customers with ≥5 support tickets |
| Revenue Concentration | Top-decile MRR ÷ Total MRR                                  |

Active business KPIs consistently use `is_churned = No` to avoid mixing disputed churn records into active metrics.

---

## 11. Key Findings

### Customer & Revenue

| Metric              |         Result |
| ------------------- | -------------: |
| Customer Churn Rate |      **70.4%** |
| Churned Customers   |  **352 / 500** |
| Revenue Churn Rate  |      **10.4%** |
| Total MRR           |    **$10.16M** |
| Active MRR          |     **$3.02M** |
| Active Customers    |        **148** |
| ARPU                | **$20,403.65** |
| ARR                 |    **~$36.2M** |
| MRR at Risk         |    **$238.6K** |

Customer churn is substantially higher than revenue churn, indicating that churn is concentrated among lower-value accounts.

### Revenue Clarity

A **$7.14M difference** exists between Total MRR and Active MRR because accounts with open churn events do not always have formally closed subscriptions.

This highlights the importance of establishing a consistent churn source of truth before using churn metrics for financial reporting.

### Plan Analysis

* Enterprise churn rate: **72.8%**
* Enterprise MRR: **$7.55M**
* Total MRR: **$10.16M**

Enterprise represents the largest concentration of revenue and observed churn.

### Churn Reasons

| Churn Reason | Share |
| ------------ | ----: |
| Features     | 19.0% |
| Support      | 17.3% |
| Budget       | 17.3% |
| Unknown      | 15.8% |
| Competitor   | 15.3% |
| Pricing      | 15.2% |

No single churn reason dominates the dataset.

### Tenure Analysis

| Customer Tenure | Churn Rate |
| --------------- | ---------: |
| 0–3 months      |  **82.9%** |
| 3–6 months      |  **73.9%** |
| 6–12 months     |  **71.4%** |
| 12+ months      |  **53.9%** |

Churn decreases as customer tenure increases.

### Customer Value

The highest-value customer quartile has a **76.8% churn rate**, showing that historical customer value alone does not protect against churn in this dataset.

### Acquisition Channel

* Partner churn: **75.3%**
* Ads churn: **60.2%**

### Revenue Concentration

The top 10% of customers by MRR account for **27.4% of total revenue**.

### Product Usage

Usage volume in the months immediately before churn remains roughly flat. Therefore, **usage volume alone does not visibly predict churn** in this dataset.

---

## 12. Retention Recommendations

Based on the analysis:

1. Establish a consistent **churn source of truth** before reporting churn KPIs.
2. Build an **Enterprise-specific retention motion**.
3. Focus onboarding efforts during the **first 90 days**.
4. Review churn among **high-value customers** at account level.
5. Investigate the **Partner acquisition channel**.
6. Develop separate retention approaches for **Support** and **Budget** churn.
7. Incorporate **tenure and support load** into customer risk assessment.
8. Use the **$238.6K MRR-at-risk** customer list as a Customer Success action list.

---

## 13. Project Structure

```text
saas-churn-retention-analytics/
│
├── README.md
├── requirements.txt
│
├── data/
│   ├── raw/
│   └── processed/
│       └── master_customer_analytics.csv
│
├── python/
│   ├── 01_data_ingestion.py
│   ├── 02_data_quality.py
│   ├── 03_master_dataset_builder.py
│   ├── 04_eda.py
│   └── 05_mysql_load.py
│
├── sql/
│   ├── 01_schema.sql
│   ├── 02_data_quality.sql
│   ├── 03_customer_analysis.sql
│   ├── 04_revenue_analysis.sql
│   ├── 05_churn_analysis.sql
│   ├── 06_usage_analysis.sql
│   ├── 07_support_analysis.sql
│   └── 08_cohort_analysis.sql
│
└── screenshots/
```

---

## 14. How to Run

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

Required packages:

```text
pandas
requests
matplotlib
seaborn
sqlalchemy
pymysql
```

### 2. Download the Data

```bash
python python/01_data_ingestion.py
```

Downloads the five CSV datasets into:

```text
data/raw/
```

### 3. Run Data Quality Checks

```bash
python python/02_data_quality.py
```

Checks:

* Missing values
* Duplicate records
* Primary keys
* Referential integrity
* Churn-source inconsistencies

### 4. Build the Master Dataset

```bash
python python/03_master_dataset_builder.py
```

Creates:

```text
data/processed/master_customer_analytics.csv
```

The script validates that the final dataset contains exactly one row per customer.

### 5. Run EDA

```bash
python python/04_eda.py
```

Generates five charts in:

```text
screenshots/
```

### 6. Create MySQL Database

```sql
CREATE DATABASE IF NOT EXISTS saas_analytics;
```

Update MySQL credentials in:

```text
python/05_mysql_load.py
```

Then run:

```bash
python python/05_mysql_load.py
```

### 7. Run SQL Analysis

Execute the SQL scripts in order, beginning with:

```text
01_schema.sql
```

Then execute the analytical SQL files.

### 8. Build Power BI Dashboard

Connect Power BI to the MySQL database, create the required relationships, implement the DAX measures, and build the five dashboard pages.

---

## 15. Limitations

* Dataset is synthetic and intended for portfolio/practice purposes.
* Analysis is observational; associations do not establish causation.
* `accounts.csv` contains 110 customers flagged as churned, while 352 customers appear in the churn events table.
* Churn events are therefore treated as the analytical source of truth.
* The churn discrepancy creates a **$7.14M difference within Total MRR**.
* Active KPIs are scoped to `is_churned = No`.
* `usage` contains 42 duplicate `usage_id` values out of 25,000 rows.
* Customer health and MRR-at-risk are analytical frameworks, not validated production churn models.
* Results should be validated against real Customer Success data before operational use.

---

## 16. Future Improvements

* Machine-learning churn prediction
* Customer Lifetime Value calculation
* Survival analysis for time-to-churn
* Automated data pipelines using Airflow
* Real-time customer health scoring
* Integration with production Customer Success data

---

## 17. Skills Demonstrated

**Data Analytics**

* Customer Churn Analysis
* Retention Analysis
* Revenue Analytics
* Customer Risk Analysis
* Cohort Analysis
* Customer Segmentation

**SQL & Database**

* MySQL
* CTEs
* Window Functions
* Ranking
* Data Modeling
* Star Schema
* Data Quality Validation

**Python**

* Pandas
* Data Cleaning
* Data Validation
* Data Aggregation
* Exploratory Data Analysis
* SQLAlchemy

**Business Intelligence**

* Power BI
* DAX
* KPI Development
* Interactive Dashboards
* Revenue Risk Reporting

---

## 18. Author

**Priyanka Lakra**
Data Analyst | SQL · Python · Power BI · Business Analytics

**Portfolio:** [bloomindata.in](https://bloomindata.in/)

**GitHub:** [priyankadatacodes](https://github.com/priyankadatacodes)

---

## License

This project is licensed under the **MIT License**.
