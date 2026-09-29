
import pandas as pd


RAW = "data/raw"


# Load all 5 datasets
accounts = pd.read_csv(f"{RAW}/accounts.csv")
subscriptions = pd.read_csv(f"{RAW}/subscriptions.csv")
usage = pd.read_csv(f"{RAW}/usage.csv")
support = pd.read_csv(f"{RAW}/support.csv")
churn = pd.read_csv(f"{RAW}/churn.csv")

dfs = {
    "accounts": accounts,
    "subscriptions": subscriptions,
    "usage": usage,
    "support": support,
    "churn": churn,
}


# Basic profiling for every table
for name, df in dfs.items():
    print(f"\n===== {name.upper()} =====")
    print("Shape:", df.shape)
    print("\nData types:")
    print(df.dtypes)
    print("\nMissing values per column:")
    print(df.isna().sum())
    print("\nFully duplicated rows:", df.duplicated().sum())


# Primary key checks
print("\n===== PRIMARY KEY CHECKS =====")

print(
    "accounts.account_id is unique:",
    accounts["account_id"].is_unique,
)

print(
    "subscriptions.subscription_id is unique:",
    subscriptions["subscription_id"].is_unique,
)

print(
    "usage.usage_id is unique:",
    usage["usage_id"].is_unique,
)

if not usage["usage_id"].is_unique:
    n_dupe_rows = usage["usage_id"].duplicated(keep=False).sum()

    print(
        f"  NOTE: {n_dupe_rows} rows share a usage_id with another row "
        f"(random 6-character ID collision in the synthetic data, "
        f"~0.2% of rows). This does NOT affect our analysis because we "
        f"never aggregate by usage_id itself — we group by "
        f"subscription_id / account_id instead."
    )

print(
    "support.ticket_id is unique:",
    support["ticket_id"].is_unique,
)

print(
    "churn.churn_event_id is unique:",
    churn["churn_event_id"].is_unique,
)


# Referential integrity checks
# (does every foreign key value exist in its parent table?)
print("\n===== REFERENTIAL INTEGRITY CHECKS =====")

valid_account_ids = set(accounts["account_id"])
valid_subscription_ids = set(subscriptions["subscription_id"])

bad_sub_accounts = ~subscriptions["account_id"].isin(valid_account_ids)

print(
    "subscriptions with an unknown account_id:",
    bad_sub_accounts.sum(),
)

# IMPORTANT: usage links to SUBSCRIPTION_id, not account_id directly.
bad_usage_subs = ~usage["subscription_id"].isin(valid_subscription_ids)

print(
    "usage rows with an unknown subscription_id:",
    bad_usage_subs.sum(),
)

bad_support_accounts = ~support["account_id"].isin(valid_account_ids)

print(
    "support rows with an unknown account_id:",
    bad_support_accounts.sum(),
)

bad_churn_accounts = ~churn["account_id"].isin(valid_account_ids)

print(
    "churn rows with an unknown account_id:",
    bad_churn_accounts.sum(),
)


# Data grain
print("\n===== DATA GRAIN =====")

print("accounts:       one row per account")
print(
    "subscriptions:  one row per subscription "
    "(an account can have MANY)"
)
print(
    "usage:          one row per usage EVENT, "
    "linked to subscription_id"
)
print(
    "support:        one row per support TICKET, "
    "linked to account_id"
)
print(
    "churn:          one row per churn EVENT "
    "(an account can appear more"
)
print(
    "                than once if it churned, reactivated, "
    "then churned again)"
)


# Known data-quality issue: churn_flag disagreement
print("\n===== KNOWN ISSUE: churn_flag vs churn events table =====")

churned_account_ids = set(churn["account_id"].unique())

accounts["flagged_in_accounts_csv"] = accounts["churn_flag"]
accounts["present_in_churn_events"] = accounts["account_id"].isin(
    churned_account_ids
)

agreement = pd.crosstab(
    accounts["flagged_in_accounts_csv"],
    accounts["present_in_churn_events"],
)

print(agreement)

print(
    "\nThe accounts.csv 'churn_flag' column does NOT fully agree with the "
    "churn.csv events table.\n"
    "DECISION: we will treat the churn.csv events table as the source of "
    "truth for 'is this customer churned?', because it is the more detailed, "
    "event-level record. This is documented as a data-quality finding in "
    "the README's Limitations section."
)

print("\nData quality checks complete.")
