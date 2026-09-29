

from pathlib import Path
import pandas as pd


# Where the rest of the pipeline expects to find the files
RAW_DATA_FOLDER = Path("data/raw")
RAW_DATA_FOLDER.mkdir(parents=True, exist_ok=True)


# Mapping: dataset key -> filename
FILE_NAMES = {
    "accounts": "ravenstack_accounts.csv",
    "subscriptions": "ravenstack_subscriptions.csv",
    "usage": "ravenstack_feature_usage.csv",
    "support": "ravenstack_support_tickets.csv",
    "churn": "ravenstack_churn_events.csv",
}


dfs = {}

for name, filename in FILE_NAMES.items():

    # Check with full name (ravenstack_*.csv)
    file_path = Path(filename)

    # Check fallback (e.g. accounts.csv)
    if not file_path.exists():
        fallback_path = Path(f"{name}.csv")

        if fallback_path.exists():
            file_path = fallback_path
        else:
            raise FileNotFoundError(
                f"File not found: {filename} or {name}.csv "
                "in the current folder."
            )

    print(f"Loading {name} ({file_path.name})...")

    df = pd.read_csv(file_path)
    dfs[name] = df

    # Save a clean, simplified copy for downstream pipeline steps
    save_path = RAW_DATA_FOLDER / f"{name}.csv"
    df.to_csv(save_path, index=False)

    print(
        f"  -> {name}: {df.shape[0]} rows x {df.shape[1]} columns "
        f"(saved to {save_path})"
    )


print("\nAll 5 files loaded successfully!")
