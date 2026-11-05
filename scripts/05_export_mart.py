"""
Step 5 - Export mart.loan_features from SQL Server to CSV for Tableau.

Tableau Desktop Public Edition connects to files, not to SQL Server,
so the mart is exported once and validated.

Input  : BankAnalytics.mart.loan_features (SQL Server)
Output : data/processed/loan_features.csv

Run from the project root:
    python scripts/05_export_mart.py
"""

import os
import warnings

import pandas as pd
import pyodbc

# Server name as shown in SSMS. Override without editing: set SQL_SERVER=MANI\SQLEXPRESS
SERVER = os.environ.get("SQL_SERVER", r"localhost\SQLEXPRESS")
DATABASE = "BankAnalytics"
OUT_DIR = os.path.join("data", "processed")
OUT_FILE = os.path.join(OUT_DIR, "loan_features.csv")

# 1. Pick the newest SQL Server ODBC driver installed on this PC
installed = pyodbc.drivers()
preferred = ["ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server", "SQL Server"]
driver = next((d for d in preferred if d in installed), None)
print("SQL Server ODBC drivers found:", [d for d in installed if "SQL Server" in d])
if driver is None:
    raise SystemExit("No SQL Server ODBC driver found. Install 'ODBC Driver 18 for SQL Server'.")
print("Using driver:", driver)

# 2. Connect with Windows Authentication (no password in the code)
conn_str = (
    f"DRIVER={{{driver}}};SERVER={SERVER};DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
)
if driver.startswith("ODBC Driver 18"):
    # Driver 18 encrypts by default; a local Express instance uses a
    # self-signed certificate, so it must be trusted explicitly.
    conn_str += "TrustServerCertificate=yes;"

conn = pyodbc.connect(conn_str)

# 3. Read the mart (pandas warns about raw DBAPI connections; harmless here)
with warnings.catch_warnings():
    warnings.simplefilter("ignore", UserWarning)
    df = pd.read_sql("SELECT * FROM mart.loan_features ORDER BY loan_id", conn)
conn.close()

# 4. Write the CSV (empty cells for NULL, not the text 'NULL')
os.makedirs(OUT_DIR, exist_ok=True)
df.to_csv(OUT_FILE, index=False, encoding="utf-8")

# 5. Validate the file that was actually written, not the DataFrame in memory
check = pd.read_csv(OUT_FILE)
results = {
    "rows (expect 682)": len(check),
    "unique loans (expect 682)": check["loan_id"].nunique(),
    "problem loans (expect 76)": int(check["is_problem"].sum()),
    "finished loans (expect 234)": int((check["contract_state"] == "Finished").sum()),
    "columns": check.shape[1],
}
for k, v in results.items():
    print(f"{k:30s} {v}")

ok = (results["rows (expect 682)"] == 682
      and results["unique loans (expect 682)"] == 682
      and results["problem loans (expect 76)"] == 76
      and results["finished loans (expect 234)"] == 234)
print("\nEXPORT OK" if ok else "\nEXPORT MISMATCH - do not use this file")

print("\nColumns (type, missing values):")
summary = pd.DataFrame({"dtype": check.dtypes.astype(str), "missing": check.isna().sum()})
print(summary.to_string())
print(f"\nSaved {OUT_FILE}")
