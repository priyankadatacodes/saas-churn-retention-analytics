

import os
import pandas as pd

RAW = "data/raw"
PROCESSED = "data/processed"
os.makedirs(PROCESSED, exist_ok=True)

# ---------------------------------------------------------------
# 1. Load raw tables
# ---------------------------------------------------------------

accounts = pd.read_csv(f"{RAW}/accounts.csv")
subscriptions = pd.read_csv(f"{RAW}/subscriptions.csv", parse_dates=["start_date", "end_date"])
usage = pd.read_csv(f"{RAW}/usage.csv", parse_dates=["usage_date"])
support = pd.read_csv(f"{RAW}/support.csv", parse_dates=["submitted_at", "closed_at"])
churn = pd.read_csv(f"{RAW}/churn.csv", parse_dates=["churn_date"])

# ---------------------------------------------------------------
# 2. Aggregate SUBSCRIPTIONS to account grain
# ---------------------------------------------------------------


subscriptions["is_active"] = subscriptions["end_date"].isna()

# Current MRR = sum of mrr_amount for subscriptions that are still active
current_mrr = (
    subscriptions[subscriptions["is_active"]]
    .groupby("account_id")["mrr_amount"]
    .sum()
    .rename("current_mrr")
)

# Historical MRR = sum of mrr_amount across ALL subscriptions ever held
historical_mrr = (
    subscriptions.groupby("account_id")["mrr_amount"]
    .sum()
    .rename("total_historical_mrr")
)

subscription_agg = (
    subscriptions.groupby("account_id")
    .agg(
        subscription_count=("subscription_id", "count"),
        active_subscription_count=("is_active", "sum"),
        subscription_start_date=("start_date", "min"),
        latest_subscription_date=("start_date", "max"),
        any_subscription_churned=("churn_flag", "max"),
        current_plan=("plan_tier", "last"),  # most recently STARTED subscription's plan
    )
    .reset_index()
)

subscription_agg = subscription_agg.merge(current_mrr, on="account_id", how="left")
subscription_agg = subscription_agg.merge(historical_mrr, on="account_id", how="left")

# An account with zero ACTIVE subscriptions has current_mrr = NaN from the
# groupby above (because it had no rows in the "active" filter) -> 0.
subscription_agg["current_mrr"] = subscription_agg["current_mrr"].fillna(0)

# ---------------------------------------------------------------
# 3. Aggregate USAGE to account grain
#    (usage -> subscriptions -> account_id, then group by account_id)
# ---------------------------------------------------------------

usage_with_account = usage.merge(
    subscriptions[["subscription_id", "account_id"]],
    on="subscription_id",
    how="left",
)

usage_agg = (
    usage_with_account.groupby("account_id")
    .agg(
        total_usage_events=("usage_id", "count"),
        distinct_features_used=("feature_name", "nunique"),
        total_usage_count=("usage_count", "sum"),
        total_usage_duration_secs=("usage_duration_secs", "sum"),
        total_error_count=("error_count", "sum"),
        active_usage_days=("usage_date", "nunique"),
        latest_usage_date=("usage_date", "max"),
    )
    .reset_index()
)

# ---------------------------------------------------------------
# 4. Aggregate SUPPORT to account grain
# ---------------------------------------------------------------

support_agg = (
    support.groupby("account_id")
    .agg(
        total_support_tickets=("ticket_id", "count"),
        avg_resolution_time_hours=("resolution_time_hours", "mean"),
        avg_satisfaction_score=("satisfaction_score", "mean"),  # NaNs are skipped automatically
        avg_first_response_minutes=("first_response_time_minutes", "mean"),
        high_priority_tickets=("priority", lambda s: (s.isin(["high", "urgent"])).sum()),
        escalated_tickets=("escalation_flag", "sum"),
    )
    .reset_index()
)

# ---------------------------------------------------------------
# 5. Aggregate CHURN to account grain

# ---------------------------------------------------------------

churn_sorted = churn.sort_values("churn_date")

churn_agg = (
    churn_sorted.groupby("account_id")
    .agg(
        churn_event_count=("churn_event_id", "count"),
        churn_reason=("reason_code", "last"),      # reason from the MOST RECENT event
        churn_date=("churn_date", "last"),          # date of the MOST RECENT event
        was_ever_reactivated=("is_reactivation", "max"),
        total_refund_amount_usd=("refund_amount_usd", "sum"),
    )
    .reset_index()
)

# ---------------------------------------------------------------
# 6. Build the master dataset: start from accounts, left-join everything
# ---------------------------------------------------------------

master_df = accounts.copy()

master_df = master_df.merge(subscription_agg, on="account_id", how="left")
master_df = master_df.merge(usage_agg, on="account_id", how="left")
master_df = master_df.merge(support_agg, on="account_id", how="left")
master_df = master_df.merge(churn_agg, on="account_id", how="left")

# ---------------------------------------------------------------
# 7. Fill in sensible defaults for customers with NO events in a table
#    (e.g. a customer who never opened a support ticket)
# ---------------------------------------------------------------

count_cols_fill_zero = [
    "subscription_count", "active_subscription_count", "current_mrr",
    "total_historical_mrr", "total_usage_events", "distinct_features_used",
    "total_usage_count", "total_usage_duration_secs", "total_error_count",
    "active_usage_days", "total_support_tickets", "high_priority_tickets",
    "escalated_tickets", "churn_event_count", "total_refund_amount_usd",
]
for col in count_cols_fill_zero:
    if col in master_df.columns:
        master_df[col] = master_df[col].fillna(0)

master_df["churn_reason"] = master_df["churn_reason"].fillna("Active")
master_df["was_ever_reactivated"] = (
    master_df["was_ever_reactivated"]
    .where(master_df["was_ever_reactivated"].notna(), False)
    .astype(bool)
)
# ---------------------------------------------------------------
# 8. Business rule: is_churned

# ---------------------------------------------------------------

master_df["is_churned"] = master_df["churn_event_count"] > 0
master_df["is_churned"] = master_df["is_churned"].map({True: "Yes", False: "No"})

# ---------------------------------------------------------------
# 9. Usage engagement bucket (Low / Medium / High), used later for the
#    "does engagement predict churn?" analysis.
# ---------------------------------------------------------------

master_df["usage_bucket"] = pd.qcut(
    master_df["total_usage_events"].rank(method="first"),
    q=3,
    labels=["Low Usage", "Medium Usage", "High Usage"],
)

# ---------------------------------------------------------------
# 10. CRITICAL VALIDATION -- this proves there was no fan-out
# ---------------------------------------------------------------

assert master_df["account_id"].is_unique, (
    "FAN-OUT DETECTED: account_id is no longer unique in the master "
    "dataset. Stop and check the merge steps above."
)

print("Rows in master dataset:", len(master_df))
print("Unique customers in accounts.csv:", accounts["account_id"].nunique())
print("Match:", len(master_df) == accounts["account_id"].nunique())

# ---------------------------------------------------------------
# 11. Save the final master dataset
# ---------------------------------------------------------------

output_path = f"{PROCESSED}/master_customer_analytics.csv"
master_df.to_csv(output_path, index=False)

print(f"\nMaster dataset saved to {output_path}")
print(f"Columns: {list(master_df.columns)}")
