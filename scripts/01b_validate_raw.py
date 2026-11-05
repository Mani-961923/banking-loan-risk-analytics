"""
Step 1b - Validate the 8 Berka CSV files downloaded from Kaggle.

Source : https://www.kaggle.com/datasets/marceloventura/the-berka-dataset
Input  : data/raw/<table>.csv  (semicolon-delimited, header row)
Output : data/raw/_validation_log.csv

Checks every file exists, counts its rows, lists its columns, and compares
the row count with the counts in the original PKDD'99 documentation.

Run from the project root:
    python scripts/01b_validate_raw.py
"""

import os

import pandas as pd

RAW_DIR = os.path.join("data", "raw")

# Row counts from the original PKDD'99 data description.
EXPECTED = {
    "account": 4_500,
    "client": 5_369,
    "disp": 5_369,
    "order": 6_471,
    "trans": 1_056_320,
    "loan": 682,
    "card": 892,
    "district": 77,
}

results = []
for table, expected in EXPECTED.items():
    path = os.path.join(RAW_DIR, f"{table}.csv")
    if not os.path.exists(path):
        print(f"[{table}] MISSING: {path}")
        results.append((table, expected, None, None, "MISSING"))
        continue

    # Read everything as text: this step checks completeness, not types.
    # Types, dates and Czech codes are handled in Step 2 (profiling).
    try:
        df = pd.read_csv(path, sep=";", dtype=str, keep_default_na=False)
    except UnicodeDecodeError:
        df = pd.read_csv(path, sep=";", dtype=str, keep_default_na=False,
                         encoding="latin-1")

    rows = len(df)
    status = "OK" if rows == expected else "MISMATCH"
    print(f"[{table}] rows={rows:,}  expected={expected:,}  {status}")
    print(f"    columns ({len(df.columns)}): {list(df.columns)}")
    print(f"    first row: {df.iloc[0].to_dict()}\n")
    results.append((table, expected, rows, len(df.columns), status))

log = pd.DataFrame(results, columns=["table", "expected_rows", "csv_rows", "n_columns", "status"])
log.to_csv(os.path.join(RAW_DIR, "_validation_log.csv"), index=False)
print(log.to_string(index=False))
