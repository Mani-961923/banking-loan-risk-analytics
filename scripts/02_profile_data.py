"""
Step 2 - Data profiling and data-quality assessment for the Berka dataset.

Input  : data/raw/<table>.csv   (semicolon-delimited, validated in Step 1b)
Output : docs/data_quality_report.txt   (full printed report)
         docs/column_profile.csv        (one row per table column)

Run from the project root:
    python scripts/02_profile_data.py
"""

import os

import pandas as pd

RAW = os.path.join("data", "raw")
DOCS = "docs"
os.makedirs(DOCS, exist_ok=True)

TABLES = ["account", "client", "disp", "order", "trans", "loan", "card", "district"]
PKS = {"account": "account_id", "client": "client_id", "disp": "disp_id",
       "order": "order_id", "trans": "trans_id", "loan": "loan_id",
       "card": "card_id", "district": "A1"}

report = []


def say(line=""):
    print(line)
    report.append(str(line))


def section(title):
    say()
    say("=" * 70)
    say(title)
    say("=" * 70)


def load(name):
    # Everything as text: nothing is converted silently before we look at it.
    return pd.read_csv(os.path.join(RAW, f"{name}.csv"), sep=";", dtype=str,
                       keep_default_na=False)


def parse_yymmdd(s):
    """Parse YYMMDD text (optionally followed by a time) into a date."""
    return pd.to_datetime("19" + s.str.strip().str[:6], format="%Y%m%d",
                          errors="coerce")


def is_blank(s):
    return s.str.strip() == ""


T = {name: load(name) for name in TABLES}

# --------------------------------------------------------------------------
section("1. COLUMN PROFILE (blank = empty or spaces; '?' = explicit unknown)")
rows = []
for name, df in T.items():
    for col in df.columns:
        s = df[col]
        top = s.replace("", "<blank>").value_counts().head(3)
        rows.append({
            "table": name,
            "column": col,
            "rows": len(s),
            "blank": int(is_blank(s).sum()),
            "question_mark": int((s.str.strip() == "?").sum()),
            "distinct": int(s.nunique()),
            "top_values": "; ".join(f"{k} ({v})" for k, v in top.items()),
        })
profile = pd.DataFrame(rows)
profile.to_csv(os.path.join(DOCS, "column_profile.csv"), index=False)
issues = profile[(profile["blank"] > 0) | (profile["question_mark"] > 0)]
say("Columns with blank or '?' values:")
say(issues[["table", "column", "rows", "blank", "question_mark"]].to_string(index=False)
    if len(issues) else "None")
say("Full per-column profile saved to docs/column_profile.csv")

# --------------------------------------------------------------------------
section("2. PRIMARY KEYS AND DUPLICATE ROWS")
for name, pk in PKS.items():
    df = T[name]
    dup_pk = int(df[pk].duplicated().sum())
    dup_rest = int(df.drop(columns=pk).duplicated().sum())
    say(f"{name:9s} key={pk:11s} duplicate keys={dup_pk:<6} "
        f"rows identical apart from the key={dup_rest}")
say("Note: identical rows apart from the key are not automatically errors "
    "(e.g. two equal payments on one day). They are flagged for review.")

# --------------------------------------------------------------------------
section("3. REFERENTIAL INTEGRITY (orphans = child rows with no parent)")
FKS = [("account", "district_id", "district", "A1"),
       ("client", "district_id", "district", "A1"),
       ("disp", "client_id", "client", "client_id"),
       ("disp", "account_id", "account", "account_id"),
       ("order", "account_id", "account", "account_id"),
       ("trans", "account_id", "account", "account_id"),
       ("loan", "account_id", "account", "account_id"),
       ("card", "disp_id", "disp", "disp_id")]
for child, ccol, parent, pcol in FKS:
    orphans = int((~T[child][ccol].isin(T[parent][pcol])).sum())
    say(f"{child}.{ccol} -> {parent}.{pcol}: orphans={orphans}")

# --------------------------------------------------------------------------
section("4. CARDINALITY (join fan-out risks)")
acc, disp, loan, card = T["account"], T["disp"], T["loan"], T["card"]

loans_per_acc = loan.groupby("account_id").size()
say(f"Max loans per account: {loans_per_acc.max()} "
    f"(documentation says at most 1)")

say("Disposition types: " + disp["type"].value_counts().to_dict().__repr__())
owners = disp[disp["type"].str.upper() == "OWNER"]
owners_per_acc = owners.groupby("account_id").size()
say(f"Accounts with exactly 1 owner: {(owners_per_acc == 1).sum()} of {len(acc)}")
say(f"Accounts with more than 1 owner: {(owners_per_acc > 1).sum()}")
say(f"Accounts with no owner: {(~acc['account_id'].isin(owners['account_id'])).sum()}")

disp_per_acc = disp.groupby("account_id").size().value_counts().sort_index()
say("Accounts by number of linked clients (owner + users): "
    + disp_per_acc.to_dict().__repr__())
say(f"Clients who own more than one account: "
    f"{(owners.groupby('client_id').size() > 1).sum()}")
say(f"Max cards per disposition: {card.groupby('disp_id').size().max()}")
say(f"Cards issued to non-owner dispositions: "
    f"{(~card['disp_id'].isin(owners['disp_id'])).sum()}")

# --------------------------------------------------------------------------
section("5. CATEGORY VALUES (counts, blanks shown as <blank>)")
CATS = [("account", "frequency"), ("disp", "type"), ("trans", "type"),
        ("trans", "operation"), ("trans", "k_symbol"), ("order", "k_symbol"),
        ("loan", "status"), ("loan", "duration"), ("card", "type"),
        ("district", "A3")]
for t, c in CATS:
    vc = T[t][c].replace("", "<blank>").value_counts()
    say(f"{t}.{c}: " + ", ".join(f"'{k}'={v}" for k, v in vc.items()))

# --------------------------------------------------------------------------
section("6. DATES (format, unparseable values, range)")
DATES = [("account", "date"), ("trans", "date"), ("loan", "date"), ("card", "issued")]
parsed = {}
for t, c in DATES:
    raw = T[t][c]
    d = parse_yymmdd(raw)
    parsed[(t, c)] = d
    lengths = raw.str.len().value_counts().to_dict()
    say(f"{t}.{c}: text lengths={lengths}  unparseable={int(d.isna().sum())}  "
        f"min={d.min().date()}  max={d.max().date()}")

# --------------------------------------------------------------------------
section("7. NUMERIC COLUMNS (non-numeric text, min, max)")
NUMS = [("order", "amount"), ("trans", "amount"), ("trans", "balance"),
        ("loan", "amount"), ("loan", "duration"), ("loan", "payments")]
NUMS += [("district", f"A{i}") for i in range(4, 17)]
num = {}
for t, c in NUMS:
    raw = T[t][c]
    v = pd.to_numeric(raw.str.strip(), errors="coerce")
    num[(t, c)] = v
    bad = raw[v.isna() & ~is_blank(raw)].unique()[:5]
    say(f"{t}.{c}: non-numeric={int((v.isna() & ~is_blank(raw)).sum())} "
        f"{list(bad) if len(bad) else ''}  min={v.min()}  max={v.max()}")

bal = num[("trans", "balance")]
amt = num[("trans", "amount")]
say(f"\nTransactions with negative balance after them: {int((bal < 0).sum())}")
say(f"Transactions with amount <= 0: {int((amt <= 0).sum())}")

# --------------------------------------------------------------------------
section("8. BUSINESS RULE CHECKS")
la, ld, lp = num[("loan", "amount")], num[("loan", "duration")], num[("loan", "payments")]
exact = ((la - lp * ld).abs() < 1).sum()
say(f"Loans where amount = payments x duration (within 1 unit): {exact} of {len(loan)}")
say("If this is all loans, the data contains no interest information.")

bn = T["client"]["birth_number"].str.strip().str.zfill(6)
yy, mm, dd = bn.str[:2].astype(int), bn.str[2:4].astype(int), bn.str[4:6].astype(int)
female = mm > 50
month = mm.where(~female, mm - 50)
invalid = ~month.between(1, 12) | ~dd.between(1, 31)
say(f"birth_number: female (month > 50)={int(female.sum())}  "
    f"male={int((~female).sum())}  invalid month/day={int(invalid.sum())}")
say(f"Birth years range: 19{yy.min():02d} to 19{yy.max():02d}")

uver_acc = T["trans"].loc[T["trans"]["k_symbol"].str.strip() == "UVER", "account_id"].unique()
say(f"Accounts with loan-payment transactions ('UVER'): {len(uver_acc)}")
say(f"...of which have no loan record (anti-join): "
    f"{int((~pd.Series(uver_acc).isin(loan['account_id'])).sum())}")

# --------------------------------------------------------------------------
section("9. POINT-IN-TIME COVERAGE (history available before each loan)")
L = loan[["loan_id", "account_id", "status"]].copy()
L["loan_date"] = parsed[("loan", "date")]
A = acc[["account_id"]].copy()
A["acc_date"] = parsed[("account", "date")]
L = L.merge(A, on="account_id", how="left")
L["days_acc_to_loan"] = (L["loan_date"] - L["acc_date"]).dt.days

tr = T["trans"][["account_id"]].copy()
tr["tdate"] = parsed[("trans", "date")]
tl = tr[tr["account_id"].isin(L["account_id"])].merge(
    L[["account_id", "loan_date"]], on="account_id")
before = tl[tl["tdate"] < tl["loan_date"]].groupby("account_id").size()
after = tl[tl["tdate"] >= tl["loan_date"]].groupby("account_id").size()
L["trans_before_loan"] = L["account_id"].map(before).fillna(0).astype(int)
L["trans_on_or_after_loan"] = L["account_id"].map(after).fillna(0).astype(int)

say("Days from account opening to loan:")
say(L["days_acc_to_loan"].describe().round(1).to_string())
say(f"\nLoans with zero transactions before the loan date: "
    f"{int((L['trans_before_loan'] == 0).sum())}")
say("Transactions before the loan date, per loan:")
say(L["trans_before_loan"].describe().round(1).to_string())
say(f"\nLast transaction date in the whole dataset: {tr['tdate'].max().date()}")
say("\nLoan status counts and median pre-loan history:")
say(L.groupby("status").agg(loans=("loan_id", "count"),
                            median_days_acc_to_loan=("days_acc_to_loan", "median"),
                            median_trans_before=("trans_before_loan", "median"))
     .to_string())

# --------------------------------------------------------------------------
with open(os.path.join(DOCS, "data_quality_report.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(report))
print("\nSaved docs/data_quality_report.txt and docs/column_profile.csv")
