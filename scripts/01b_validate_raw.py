{
 "cells": [
  {
   "cell_type": "code",
   "execution_count": 1,
   "id": "580f9b3a-0ec8-42d1-892e-1a07aaf1aa93",
   "metadata": {},
   "outputs": [
    {
     "name": "stdout",
     "output_type": "stream",
     "text": [
      "[account] MISSING: data\\raw\\account.csv\n",
      "[client] MISSING: data\\raw\\client.csv\n",
      "[disp] MISSING: data\\raw\\disp.csv\n",
      "[order] MISSING: data\\raw\\order.csv\n",
      "[trans] MISSING: data\\raw\\trans.csv\n",
      "[loan] MISSING: data\\raw\\loan.csv\n",
      "[card] MISSING: data\\raw\\card.csv\n",
      "[district] MISSING: data\\raw\\district.csv\n"
     ]
    },
    {
     "ename": "OSError",
     "evalue": "Cannot save file into a non-existent directory: 'data\\raw'",
     "output_type": "error",
     "traceback": [
      "\u001b[31m---------------------------------------------------------------------------\u001b[39m",
      "\u001b[31mOSError\u001b[39m                                   Traceback (most recent call last)",
      "\u001b[36mCell\u001b[39m\u001b[36m \u001b[39m\u001b[32mIn[1]\u001b[39m\u001b[32m, line 57\u001b[39m\n\u001b[32m     53\u001b[39m     print(f\"    first row: {df.iloc[\u001b[32m0\u001b[39m].to_dict()}\\n\")\n\u001b[32m     54\u001b[39m     results.append((table, expected, rows, len(df.columns), status))\n\u001b[32m     55\u001b[39m \n\u001b[32m     56\u001b[39m log = pd.DataFrame(results, columns=[\u001b[33m\"table\"\u001b[39m, \u001b[33m\"expected_rows\"\u001b[39m, \u001b[33m\"csv_rows\"\u001b[39m, \u001b[33m\"n_columns\"\u001b[39m, \u001b[33m\"status\"\u001b[39m])\n\u001b[32m---> \u001b[39m\u001b[32m57\u001b[39m log.to_csv(os.path.join(RAW_DIR, \u001b[33m\"_validation_log.csv\"\u001b[39m), index=\u001b[38;5;28;01mFalse\u001b[39;00m)\n\u001b[32m     58\u001b[39m print(log.to_string(index=\u001b[38;5;28;01mFalse\u001b[39;00m))\n",
      "\u001b[36mFile \u001b[39m\u001b[32mC:\\ProgramData\\anaconda3\\Lib\\site-packages\\pandas\\core\\generic.py:3988\u001b[39m, in \u001b[36mNDFrame.to_csv\u001b[39m\u001b[34m(self, path_or_buf, sep, na_rep, float_format, columns, header, index, index_label, mode, encoding, compression, quoting, quotechar, lineterminator, chunksize, date_format, doublequote, escapechar, decimal, errors, storage_options)\u001b[39m\n\u001b[32m   3984\u001b[39m             float_format=float_format,\n\u001b[32m   3985\u001b[39m             decimal=decimal,\n\u001b[32m   3986\u001b[39m         )\n\u001b[32m   3987\u001b[39m \n\u001b[32m-> \u001b[39m\u001b[32m3988\u001b[39m         return DataFrameRenderer(formatter).to_csv(\n\u001b[32m   3989\u001b[39m             path_or_buf,\n\u001b[32m   3990\u001b[39m             lineterminator=lineterminator,\n\u001b[32m   3991\u001b[39m             sep=sep,\n",
      "\u001b[36mFile \u001b[39m\u001b[32mC:\\ProgramData\\anaconda3\\Lib\\site-packages\\pandas\\io\\formats\\format.py:1025\u001b[39m, in \u001b[36mDataFrameRenderer.to_csv\u001b[39m\u001b[34m(self, path_or_buf, encoding, sep, columns, index_label, mode, compression, quoting, quotechar, lineterminator, chunksize, date_format, doublequote, escapechar, errors, storage_options)\u001b[39m\n\u001b[32m   1004\u001b[39m     created_buffer = \u001b[38;5;28;01mFalse\u001b[39;00m\n\u001b[32m   1006\u001b[39m csv_formatter = CSVFormatter(\n\u001b[32m   1007\u001b[39m     path_or_buf=path_or_buf,\n\u001b[32m   1008\u001b[39m     lineterminator=lineterminator,\n\u001b[32m   (...)\u001b[39m\u001b[32m   1023\u001b[39m     formatter=\u001b[38;5;28mself\u001b[39m.fmt,\n\u001b[32m   1024\u001b[39m )\n\u001b[32m-> \u001b[39m\u001b[32m1025\u001b[39m \u001b[43mcsv_formatter\u001b[49m\u001b[43m.\u001b[49m\u001b[43msave\u001b[49m\u001b[43m(\u001b[49m\u001b[43m)\u001b[49m\n\u001b[32m   1027\u001b[39m \u001b[38;5;28;01mif\u001b[39;00m created_buffer:\n\u001b[32m   1028\u001b[39m     \u001b[38;5;28;01massert\u001b[39;00m \u001b[38;5;28misinstance\u001b[39m(path_or_buf, StringIO)\n",
      "\u001b[36mFile \u001b[39m\u001b[32mC:\\ProgramData\\anaconda3\\Lib\\site-packages\\pandas\\io\\formats\\csvs.py:251\u001b[39m, in \u001b[36mCSVFormatter.save\u001b[39m\u001b[34m(self)\u001b[39m\n\u001b[32m    247\u001b[39m \u001b[38;5;250m\u001b[39m\u001b[33;03m\"\"\"\u001b[39;00m\n\u001b[32m    248\u001b[39m \u001b[33;03mCreate the writer & save.\u001b[39;00m\n\u001b[32m    249\u001b[39m \u001b[33;03m\"\"\"\u001b[39;00m\n\u001b[32m    250\u001b[39m \u001b[38;5;66;03m# apply compression and byte/text conversion\u001b[39;00m\n\u001b[32m--> \u001b[39m\u001b[32m251\u001b[39m \u001b[38;5;28;01mwith\u001b[39;00m \u001b[43mget_handle\u001b[49m\u001b[43m(\u001b[49m\n\u001b[32m    252\u001b[39m \u001b[43m    \u001b[49m\u001b[38;5;28;43mself\u001b[39;49m\u001b[43m.\u001b[49m\u001b[43mfilepath_or_buffer\u001b[49m\u001b[43m,\u001b[49m\n\u001b[32m    253\u001b[39m \u001b[43m    \u001b[49m\u001b[38;5;28;43mself\u001b[39;49m\u001b[43m.\u001b[49m\u001b[43mmode\u001b[49m\u001b[43m,\u001b[49m\n\u001b[32m    254\u001b[39m \u001b[43m    \u001b[49m\u001b[43mencoding\u001b[49m\u001b[43m=\u001b[49m\u001b[38;5;28;43mself\u001b[39;49m\u001b[43m.\u001b[49m\u001b[43mencoding\u001b[49m\u001b[43m,\u001b[49m\n\u001b[32m    255\u001b[39m \u001b[43m    \u001b[49m\u001b[43merrors\u001b[49m\u001b[43m=\u001b[49m\u001b[38;5;28;43mself\u001b[39;49m\u001b[43m.\u001b[49m\u001b[43merrors\u001b[49m\u001b[43m,\u001b[49m\n\u001b[32m    256\u001b[39m \u001b[43m    \u001b[49m\u001b[43mcompression\u001b[49m\u001b[43m=\u001b[49m\u001b[38;5;28;43mself\u001b[39;49m\u001b[43m.\u001b[49m\u001b[43mcompression\u001b[49m\u001b[43m,\u001b[49m\n\u001b[32m    257\u001b[39m \u001b[43m    \u001b[49m\u001b[43mstorage_options\u001b[49m\u001b[43m=\u001b[49m\u001b[38;5;28;43mself\u001b[39;49m\u001b[43m.\u001b[49m\u001b[43mstorage_options\u001b[49m\u001b[43m,\u001b[49m\n\u001b[32m    258\u001b[39m \u001b[43m\u001b[49m\u001b[43m)\u001b[49m \u001b[38;5;28;01mas\u001b[39;00m handles:\n\u001b[32m    259\u001b[39m     \u001b[38;5;66;03m# Note: self.encoding is irrelevant here\u001b[39;00m\n\u001b[32m    260\u001b[39m     \u001b[38;5;66;03m# error: Argument \"quoting\" to \"writer\" has incompatible type \"int\";\u001b[39;00m\n\u001b[32m    261\u001b[39m     \u001b[38;5;66;03m# expected \"Literal[0, 1, 2, 3]\"\u001b[39;00m\n\u001b[32m    262\u001b[39m     \u001b[38;5;28mself\u001b[39m.writer = csvlib.writer(\n\u001b[32m    263\u001b[39m         handles.handle,\n\u001b[32m    264\u001b[39m         lineterminator=\u001b[38;5;28mself\u001b[39m.lineterminator,\n\u001b[32m   (...)\u001b[39m\u001b[32m    269\u001b[39m         quotechar=\u001b[38;5;28mself\u001b[39m.quotechar,\n\u001b[32m    270\u001b[39m     )\n\u001b[32m    272\u001b[39m     \u001b[38;5;28mself\u001b[39m._save()\n",
      "\u001b[36mFile \u001b[39m\u001b[32mC:\\ProgramData\\anaconda3\\Lib\\site-packages\\pandas\\io\\common.py:797\u001b[39m, in \u001b[36mget_handle\u001b[39m\u001b[34m(path_or_buf, mode, encoding, compression, memory_map, is_text, errors, storage_options)\u001b[39m\n\u001b[32m    795\u001b[39m \u001b[38;5;66;03m# Only for write methods\u001b[39;00m\n\u001b[32m    796\u001b[39m \u001b[38;5;28;01mif\u001b[39;00m \u001b[33m\"\u001b[39m\u001b[33mr\u001b[39m\u001b[33m\"\u001b[39m \u001b[38;5;129;01mnot\u001b[39;00m \u001b[38;5;129;01min\u001b[39;00m mode \u001b[38;5;129;01mand\u001b[39;00m is_path:\n\u001b[32m--> \u001b[39m\u001b[32m797\u001b[39m     \u001b[43mcheck_parent_directory\u001b[49m\u001b[43m(\u001b[49m\u001b[38;5;28;43mstr\u001b[39;49m\u001b[43m(\u001b[49m\u001b[43mhandle\u001b[49m\u001b[43m)\u001b[49m\u001b[43m)\u001b[49m\n\u001b[32m    799\u001b[39m \u001b[38;5;28;01mif\u001b[39;00m compression:\n\u001b[32m    800\u001b[39m     \u001b[38;5;28;01mif\u001b[39;00m compression != \u001b[33m\"\u001b[39m\u001b[33mzstd\u001b[39m\u001b[33m\"\u001b[39m:\n\u001b[32m    801\u001b[39m         \u001b[38;5;66;03m# compression libraries do not like an explicit text-mode\u001b[39;00m\n",
      "\u001b[36mFile \u001b[39m\u001b[32mC:\\ProgramData\\anaconda3\\Lib\\site-packages\\pandas\\io\\common.py:656\u001b[39m, in \u001b[36mcheck_parent_directory\u001b[39m\u001b[34m(path)\u001b[39m\n\u001b[32m    654\u001b[39m parent = Path(path).parent\n\u001b[32m    655\u001b[39m \u001b[38;5;28;01mif\u001b[39;00m \u001b[38;5;129;01mnot\u001b[39;00m parent.is_dir():\n\u001b[32m--> \u001b[39m\u001b[32m656\u001b[39m     \u001b[38;5;28;01mraise\u001b[39;00m \u001b[38;5;167;01mOSError\u001b[39;00m(\u001b[33mrf\u001b[39m\u001b[33m\"\u001b[39m\u001b[33mCannot save file into a non-existent directory: \u001b[39m\u001b[33m'\u001b[39m\u001b[38;5;132;01m{\u001b[39;00mparent\u001b[38;5;132;01m}\u001b[39;00m\u001b[33m'\u001b[39m\u001b[33m\"\u001b[39m)\n",
      "\u001b[31mOSError\u001b[39m: Cannot save file into a non-existent directory: 'data\\raw'"
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
