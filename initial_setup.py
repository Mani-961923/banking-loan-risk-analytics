{
 "cells": [
  {
   "cell_type": "code",
   "execution_count": 6,
   "id": "32c37370-a89c-472a-8e7d-b620c078fbd0",
   "metadata": {},
   "outputs": [
    {
     "name": "stdout",
     "output_type": "stream",
     "text": [
      "[account] rows=4,500  expected=4,500  OK\n",
      "    columns (4): ['account_id', 'district_id', 'frequency', 'date']\n",
      "    first row: {'account_id': '576', 'district_id': '55', 'frequency': 'POPLATEK MESICNE', 'date': '930101'}\n",
      "\n",
      "[client] rows=5,369  expected=5,369  OK\n",
      "    columns (3): ['client_id', 'birth_number', 'district_id']\n",
      "    first row: {'client_id': '1', 'birth_number': '706213', 'district_id': '18'}\n",
      "\n",
      "[disp] rows=5,369  expected=5,369  OK\n",
      "    columns (4): ['disp_id', 'client_id', 'account_id', 'type']\n",
      "    first row: {'disp_id': '1', 'client_id': '1', 'account_id': '1', 'type': 'OWNER'}\n",
      "\n",
      "[order] rows=6,471  expected=6,471  OK\n",
      "    columns (6): ['order_id', 'account_id', 'bank_to', 'account_to', 'amount', 'k_symbol']\n",
      "    first row: {'order_id': '29401', 'account_id': '1', 'bank_to': 'YZ', 'account_to': '87144583', 'amount': '2452.00', 'k_symbol': 'SIPO'}\n",
      "\n",
      "[trans] rows=1,056,320  expected=1,056,320  OK\n",
      "    columns (10): ['trans_id', 'account_id', 'date', 'type', 'operation', 'amount', 'balance', 'k_symbol', 'bank', 'account']\n",
      "    first row: {'trans_id': '695247', 'account_id': '2378', 'date': '930101', 'type': 'PRIJEM', 'operation': 'VKLAD', 'amount': '700.00', 'balance': '700.00', 'k_symbol': '', 'bank': '', 'account': ''}\n",
      "\n",
      "[loan] rows=682  expected=682  OK\n",
      "    columns (7): ['loan_id', 'account_id', 'date', 'amount', 'duration', 'payments', 'status']\n",
      "    first row: {'loan_id': '5314', 'account_id': '1787', 'date': '930705', 'amount': '96396', 'duration': '12', 'payments': '8033.00', 'status': 'B'}\n",
      "\n",
      "[card] rows=892  expected=892  OK\n",
      "    columns (4): ['card_id', 'disp_id', 'type', 'issued']\n",
      "    first row: {'card_id': '1005', 'disp_id': '9285', 'type': 'classic', 'issued': '931107 00:00:00'}\n",
      "\n",
      "[district] rows=77  expected=77  OK\n",
      "    columns (16): ['A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9', 'A10', 'A11', 'A12', 'A13', 'A14', 'A15', 'A16']\n",
      "    first row: {'A1': '1', 'A2': 'Hl.m. Praha', 'A3': 'Prague', 'A4': '1204953', 'A5': '0', 'A6': '0', 'A7': '0', 'A8': '1', 'A9': '1', 'A10': '100.0', 'A11': '12541', 'A12': '0.29', 'A13': '0.43', 'A14': '167', 'A15': '85677', 'A16': '99107'}\n",
      "\n",
      "   table  expected_rows  csv_rows  n_columns status\n",
      " account           4500      4500          4     OK\n",
      "  client           5369      5369          3     OK\n",
      "    disp           5369      5369          4     OK\n",
      "   order           6471      6471          6     OK\n",
      "   trans        1056320   1056320         10     OK\n",
      "    loan            682       682          7     OK\n",
      "    card            892       892          4     OK\n",
      "district             77        77         16     OK\n"
     ]
    }
   ],
   "source": [
    "\"\"\"\n",
    "Step 1b - Validate the 8 Berka CSV files downloaded from Kaggle.\n",
    "\n",
    "Source : https://www.kaggle.com/datasets/marceloventura/the-berka-dataset\n",
    "Input  : data/raw/<table>.csv  (semicolon-delimited, header row)\n",
    "Output : data/raw/_validation_log.csv\n",
    "\n",
    "Checks every file exists, counts its rows, lists its columns, and compares\n",
    "the row count with the counts in the original PKDD'99 documentation.\n",
    "\n",
    "Run from the project root:\n",
    "    python scripts/01b_validate_raw.py\n",
    "\"\"\"\n",
    "\n",
    "import os\n",
    "\n",
    "import pandas as pd\n",
    "\n",
    "RAW_DIR = os.path.join(\"data\", \"raw\")\n",
    "\n",
    "# Row counts from the original PKDD'99 data description.\n",
    "EXPECTED = {\n",
    "    \"account\": 4_500,\n",
    "    \"client\": 5_369,\n",
    "    \"disp\": 5_369,\n",
    "    \"order\": 6_471,\n",
    "    \"trans\": 1_056_320,\n",
    "    \"loan\": 682,\n",
    "    \"card\": 892,\n",
    "    \"district\": 77,\n",
    "}\n",
    "\n",
    "results = []\n",
    "for table, expected in EXPECTED.items():\n",
    "    path = os.path.join(RAW_DIR, f\"{table}.csv\")\n",
    "    if not os.path.exists(path):\n",
    "        print(f\"[{table}] MISSING: {path}\")\n",
    "        results.append((table, expected, None, None, \"MISSING\"))\n",
    "        continue\n",
    "\n",
    "    # Read everything as text: this step checks completeness, not types.\n",
    "    # Types, dates and Czech codes are handled in Step 2 (profiling).\n",
    "    try:\n",
    "        df = pd.read_csv(path, sep=\";\", dtype=str, keep_default_na=False)\n",
    "    except UnicodeDecodeError:\n",
    "        df = pd.read_csv(path, sep=\";\", dtype=str, keep_default_na=False,\n",
    "                         encoding=\"latin-1\")\n",
    "\n",
    "    rows = len(df)\n",
    "    status = \"OK\" if rows == expected else \"MISMATCH\"\n",
    "    print(f\"[{table}] rows={rows:,}  expected={expected:,}  {status}\")\n",
    "    print(f\"    columns ({len(df.columns)}): {list(df.columns)}\")\n",
    "    print(f\"    first row: {df.iloc[0].to_dict()}\\n\")\n",
    "    results.append((table, expected, rows, len(df.columns), status))\n",
    "\n",
    "log = pd.DataFrame(results, columns=[\"table\", \"expected_rows\", \"csv_rows\", \"n_columns\", \"status\"])\n",
    "log.to_csv(os.path.join(RAW_DIR, \"_validation_log.csv\"), index=False)\n",
    "print(log.to_string(index=False))"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": 3,
   "id": "bd3d0447-9ab8-4f00-8168-6e14d91f6b17",
   "metadata": {},
   "outputs": [
    {
     "name": "stdout",
     "output_type": "stream",
     "text": [
      "Defaulting to user installation because normal site-packages is not writeable\n",
      "Requirement already satisfied: pymysql in C:\\Users\\manik\\AppData\\Roaming\\Python\\Python314\\site-packages (1.2.3)\n",
      "Note: you may need to restart the kernel to use updated packages.\n"
     ]
    }
   ],
   "source": [
    "   %pip install pymysql"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": 1,
   "id": "67a7a7b8-4322-4ef2-a891-924528b080ad",
   "metadata": {},
   "outputs": [
    {
     "name": "stdout",
     "output_type": "stream",
     "text": [
      "C:\\Users\\manik\\Banking-Project\n"
     ]
    }
   ],
   "source": [
    "   import os\n",
    "   print(os.getcwd())"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": 4,
   "id": "033880e7-0e28-4883-a39f-8304997a728e",
   "metadata": {},
   "outputs": [
    {
     "name": "stdout",
     "output_type": "stream",
     "text": [
      "archive -> ['account.csv', 'card.csv', 'client.csv', 'disp.csv', 'district.csv', 'loan.csv', 'order.csv', 'trans.csv']\n",
      "\n",
      "Moved: ['account.csv', 'card.csv', 'client.csv', 'disp.csv', 'district.csv', 'loan.csv', 'order.csv', 'trans.csv']\n",
      "Now in data\\raw: ['account.csv', 'card.csv', 'client.csv', 'disp.csv', 'district.csv', 'loan.csv', 'order.csv', 'trans.csv', '_validation_log.csv']\n"
     ]
    }
   ],
   "source": [
    "import os, shutil\n",
    "\n",
    "src = \"archive\"\n",
    "dst = os.path.join(\"data\", \"raw\")\n",
    "\n",
    "# 1. Show everything that was extracted, including any subfolders\n",
    "for root, dirs, files in os.walk(src):\n",
    "    print(root, \"->\", files)\n",
    "\n",
    "# 2. Move every CSV into data\\raw\n",
    "moved = []\n",
    "for root, dirs, files in os.walk(src):\n",
    "    for f in files:\n",
    "        if f.lower().endswith(\".csv\"):\n",
    "            shutil.move(os.path.join(root, f), os.path.join(dst, f))\n",
    "            moved.append(f)\n",
    "\n",
    "print(\"\\nMoved:\", moved)\n",
    "print(\"Now in data\\\\raw:\", os.listdir(dst))"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": 5,
   "id": "bec91da4-88f9-44fe-a101-e0bd489c99cb",
   "metadata": {},
   "outputs": [
    {
     "ename": "Exception",
     "evalue": "File `'scripts/01b_validate_raw.py'` not found.",
     "output_type": "error",
     "traceback": [
      "\u001b[31m---------------------------------------------------------------------------\u001b[39m",
      "\u001b[31mOSError\u001b[39m                                   Traceback (most recent call last)",
      "\u001b[31mOSError\u001b[39m: File `'scripts/01b_validate_raw.py'` not found.",
      "\nThe above exception was the direct cause of the following exception:\n",
      "\u001b[31mException\u001b[39m                                 Traceback (most recent call last)",
      "\u001b[36mCell\u001b[39m\u001b[36m \u001b[39m\u001b[32mIn[5]\u001b[39m\u001b[32m, line 1\u001b[39m\n\u001b[32m----> \u001b[39m\u001b[32m1\u001b[39m get_ipython().run_line_magic(\u001b[33m'run'\u001b[39m, \u001b[33m'scripts/01b_validate_raw.py'\u001b[39m)\n",
      "\u001b[31mException\u001b[39m: File `'scripts/01b_validate_raw.py'` not found."
     ]
    }
   ],
   "source": [
    "%run scripts/01b_validate_raw.py"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3 (ipykernel)",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "codemirror_mode": {
    "name": "ipython",
    "version": 3
   },
   "file_extension": ".py",
   "mimetype": "text/x-python",
   "name": "python",
   "nbconvert_exporter": "python",
   "pygments_lexer": "ipython3",
   "version": "3.14.6"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 5
}
