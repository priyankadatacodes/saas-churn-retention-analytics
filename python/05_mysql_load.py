

import pandas as pd
from sqlalchemy import create_engine

# ---------------------------------------------------------------
# 1. MySQL login
# ---------------------------------------------------------------

MYSQL_USER = "root"
MYSQL_PASSWORD = "pricass00"
MYSQL_HOST = "localhost"
MYSQL_PORT = 3306
MYSQL_DATABASE = "saas_analytics"

# ---------------------------------------------------------------
# 2. Build the SQLAlchemy connection
# ---------------------------------------------------------------

connection_string = (
    f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}"
    f"@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DATABASE}"
)

engine = create_engine(connection_string)

# Quick connection test
with engine.connect() as test_conn:
    print(f"Connected successfully to MySQL database '{MYSQL_DATABASE}'.")

# ---------------------------------------------------------------
# 3. Load raw CSVs
# ---------------------------------------------------------------

RAW = "data/raw"
PROCESSED = "data/processed"

accounts = pd.read_csv(f"{RAW}/accounts.csv")
subscriptions = pd.read_csv(f"{RAW}/subscriptions.csv")
usage = pd.read_csv(f"{RAW}/usage.csv")
support = pd.read_csv(f"{RAW}/support.csv")
churn = pd.read_csv(f"{RAW}/churn.csv")
master_df = pd.read_csv(f"{PROCESSED}/master_customer_analytics.csv")

# ---------------------------------------------------------------
# 4. Write each table to MySQL
#    
# ---------------------------------------------------------------

tables_to_load = {
    "dim_customer": accounts,
    "fact_subscription": subscriptions,
    "fact_usage": usage,
    "fact_support": support,
    "fact_churn": churn,
    "master_customer_analytics": master_df,
}

for table_name, df in tables_to_load.items():
    print(f"Uploading {table_name} ({df.shape[0]} rows)...")
    df.to_sql(table_name, con=engine, if_exists="replace", index=False)
    print(f"  -> done.")

print("\nAll tables loaded into MySQL successfully.")
