

import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

PROCESSED = "data/processed"
OUTPUT_FOLDER = "screenshots"
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

sns.set_style("whitegrid")

# ---------------------------------------------------------------
# 1. Load the master dataset
# ---------------------------------------------------------------

df = pd.read_csv(f"{PROCESSED}/master_customer_analytics.csv")

print("Master dataset loaded:", df.shape)

# ---------------------------------------------------------------
# 2. Overall churn rate
# ---------------------------------------------------------------

churn_counts = df["is_churned"].value_counts()
churn_rate = (df["is_churned"] == "Yes").mean() * 100

print(f"\nOverall churn rate: {churn_rate:.1f}%")
print(churn_counts)

plt.figure(figsize=(5, 5))
plt.pie(
    churn_counts,
    labels=churn_counts.index,
    autopct="%1.1f%%",
    colors=["#4C72B0", "#DD8452"],
)
plt.title(f"Customer Churn Split (overall churn rate: {churn_rate:.1f}%)")
plt.savefig(f"{OUTPUT_FOLDER}/01_overall_churn_rate.png", bbox_inches="tight")
plt.close()

# ---------------------------------------------------------------
# 3. Does usage engagement predict churn?
# ---------------------------------------------------------------

usage_vs_churn = (
    df.groupby("usage_bucket")["is_churned"]
    .apply(lambda s: (s == "Yes").mean() * 100)
    .reindex(["Low Usage", "Medium Usage", "High Usage"])
)

print("\nChurn rate by usage bucket (%):")
print(usage_vs_churn)

plt.figure(figsize=(6, 4))
sns.barplot(x=usage_vs_churn.index, y=usage_vs_churn.values,
            hue=usage_vs_churn.index, palette="Blues_d", legend=False)
plt.title("Churn Rate by Product Usage Level")
plt.ylabel("Churn Rate (%)")
plt.xlabel("Usage Bucket")
plt.savefig(f"{OUTPUT_FOLDER}/02_usage_vs_churn.png", bbox_inches="tight")
plt.close()

# ---------------------------------------------------------------
# 4. Support tickets vs churn
# ---------------------------------------------------------------

plt.figure(figsize=(6, 4))
sns.boxplot(x="is_churned", y="total_support_tickets", data=df)
plt.title("Support Tickets: Churned vs Active Customers")
plt.xlabel("Is Churned?")
plt.ylabel("Total Support Tickets")
plt.savefig(f"{OUTPUT_FOLDER}/03_support_tickets_vs_churn.png", bbox_inches="tight")
plt.close()

# ---------------------------------------------------------------
# 5. Churn rate by plan
# ---------------------------------------------------------------

churn_by_plan = (
    df.groupby("current_plan")["is_churned"]
    .apply(lambda s: (s == "Yes").mean() * 100)
    .sort_values(ascending=False)
)

print("\nChurn rate by plan (%):")
print(churn_by_plan)

plt.figure(figsize=(6, 4))
sns.barplot(x=churn_by_plan.index, y=churn_by_plan.values,
            hue=churn_by_plan.index, palette="Reds_d", legend=False)
plt.title("Churn Rate by Plan")
plt.ylabel("Churn Rate (%)")
plt.xlabel("Plan")
plt.savefig(f"{OUTPUT_FOLDER}/04_churn_by_plan.png", bbox_inches="tight")
plt.close()

# ---------------------------------------------------------------
# 6. MRR distribution
# ---------------------------------------------------------------

plt.figure(figsize=(6, 4))
sns.histplot(df[df["current_mrr"] > 0]["current_mrr"], bins=30, kde=True)
plt.title("Distribution of Current MRR (active customers only)")
plt.xlabel("Current MRR ($)")
plt.savefig(f"{OUTPUT_FOLDER}/05_mrr_distribution.png", bbox_inches="tight")
plt.close()

# ---------------------------------------------------------------
# 7. Revenue at risk: churned customers' lost MRR
# ---------------------------------------------------------------

churned_df = df[df["is_churned"] == "Yes"]
lost_mrr_estimate = churned_df["total_historical_mrr"].sum()
total_mrr_ever = df["total_historical_mrr"].sum()

print(f"\nEstimated historical MRR tied to churned accounts: ${lost_mrr_estimate:,.0f}")
print(f"Total historical MRR across all accounts: ${total_mrr_ever:,.0f}")
print(f"Share of historical MRR from churned accounts: "
      f"{100 * lost_mrr_estimate / total_mrr_ever:.1f}%")

print(f"\nAll charts saved into the '{OUTPUT_FOLDER}/' folder.")
