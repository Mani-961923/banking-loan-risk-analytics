"""
Step 3 (prep) - Check the CSV file format and copy the files for BULK INSERT.

BULK INSERT runs as the SQL Server service account, which usually cannot read
files under C:\\Users\\..., so the CSVs are copied to C:\\BankData\\raw.
The printed line endings, quoting and encoding decide the BULK INSERT options
used in sql/03b_load_staging.sql (CRLF, quoted fields, UTF-8).

Input  : data/raw/<table>.csv
Output : C:\\BankData\\raw\\<table>.csv

Run from the project root:
    python scripts/03_check_and_copy_for_sql.py
"""

import os
import shutil

SRC = os.path.join("data", "raw")
DST = r"C:\BankData\raw"
TABLES = ["account", "card", "client", "disp", "district", "loan", "order", "trans"]

os.makedirs(DST, exist_ok=True)

for name in TABLES:
    path = os.path.join(SRC, f"{name}.csv")
    with open(path, "rb") as fh:  # raw bytes: see the real line endings and quotes
        data = fh.read()

    endings = "CRLF" if b"\r\n" in data[:2000] else "LF"
    quoted = "has quotes" if b'"' in data[:2000] else "no quotes"
    try:
        data.decode("utf-8")
        encoding = "utf-8 OK"
    except UnicodeDecodeError:
        encoding = "NOT utf-8"

    shutil.copy2(path, os.path.join(DST, f"{name}.csv"))
    print(f"{name:9s} {endings:5s} {quoted:11s} {encoding}")

print("\nCopied to:", DST, sorted(os.listdir(DST)))
