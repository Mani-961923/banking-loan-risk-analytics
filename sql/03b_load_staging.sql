/* ==========================================================================
   Step 3b - Load the 8 Berka CSV files into staging and reconcile
   Target : Microsoft SQL Server 2025 (Express), database BankAnalytics

   File facts verified in Python before loading:
     - semicolon-delimited, header row, values wrapped in double quotes
     - CRLF line endings, UTF-8 encoding
     - files copied to C:\BankData\raw (readable by the SQL Server service)

   Rerunnable: every table is truncated before it is loaded.
   ========================================================================== */

USE BankAnalytics;
GO

/* --------------------------------------------------------------------------
   1. Load each table
   -------------------------------------------------------------------------- */

TRUNCATE TABLE stg.account;
BULK INSERT stg.account FROM 'C:\BankData\raw\account.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ';',
      ROWTERMINATOR = '0x0d0a', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE stg.client;
BULK INSERT stg.client FROM 'C:\BankData\raw\client.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ';',
      ROWTERMINATOR = '0x0d0a', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE stg.disp;
BULK INSERT stg.disp FROM 'C:\BankData\raw\disp.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ';',
      ROWTERMINATOR = '0x0d0a', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE stg.[order];
BULK INSERT stg.[order] FROM 'C:\BankData\raw\order.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ';',
      ROWTERMINATOR = '0x0d0a', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE stg.trans;
BULK INSERT stg.trans FROM 'C:\BankData\raw\trans.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ';',
      ROWTERMINATOR = '0x0d0a', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE stg.loan;
BULK INSERT stg.loan FROM 'C:\BankData\raw\loan.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ';',
      ROWTERMINATOR = '0x0d0a', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE stg.card;
BULK INSERT stg.card FROM 'C:\BankData\raw\card.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ';',
      ROWTERMINATOR = '0x0d0a', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

TRUNCATE TABLE stg.district;
BULK INSERT stg.district FROM 'C:\BankData\raw\district.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIELDTERMINATOR = ';',
      ROWTERMINATOR = '0x0d0a', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);
GO

/* --------------------------------------------------------------------------
   2. Reconciliation: loaded rows vs counts verified in Step 1b
   -------------------------------------------------------------------------- */
SELECT t.table_name,
       t.expected_rows,
       t.loaded_rows,
       CASE WHEN t.expected_rows = t.loaded_rows THEN 'OK' ELSE 'MISMATCH' END AS status
FROM (
    SELECT 'account'  AS table_name, 4500    AS expected_rows, (SELECT COUNT(*) FROM stg.account)  AS loaded_rows
    UNION ALL SELECT 'client',   5369,    (SELECT COUNT(*) FROM stg.client)
    UNION ALL SELECT 'disp',     5369,    (SELECT COUNT(*) FROM stg.disp)
    UNION ALL SELECT 'order',    6471,    (SELECT COUNT(*) FROM stg.[order])
    UNION ALL SELECT 'trans',    1056320, (SELECT COUNT(*) FROM stg.trans)
    UNION ALL SELECT 'loan',     682,     (SELECT COUNT(*) FROM stg.loan)
    UNION ALL SELECT 'card',     892,     (SELECT COUNT(*) FROM stg.card)
    UNION ALL SELECT 'district', 77,      (SELECT COUNT(*) FROM stg.district)
) AS t;

/* --------------------------------------------------------------------------
   3. Load-artifact checks
   -------------------------------------------------------------------------- */

-- 3a. Quote characters left inside values (expect 0 in every column)
SELECT
    (SELECT COUNT(*) FROM stg.account WHERE frequency LIKE '%"%') AS quotes_in_account_frequency,
    (SELECT COUNT(*) FROM stg.district WHERE A2 LIKE '%"%')       AS quotes_in_district_name,
    (SELECT COUNT(*) FROM stg.trans WHERE [type] LIKE '%"%')      AS quotes_in_trans_type,
    -- Hidden carriage return (CHAR(13)) in the LAST column of a file (expect 0)
    (SELECT COUNT(*) FROM stg.trans WHERE [account] LIKE '%' + CHAR(13) + '%') AS cr_in_trans_account,
    (SELECT COUNT(*) FROM stg.loan  WHERE status    LIKE '%' + CHAR(13) + '%') AS cr_in_loan_status,
    (SELECT COUNT(*) FROM stg.district WHERE A16    LIKE '%' + CHAR(13) + '%') AS cr_in_district_A16;

-- 3b. How the blank k_symbol values arrived.
--     Python counted 481,881 empty + 53,433 single spaces = 535,314.
--     The first three columns must add up to 535,314.
--
--     DATALENGTH (bytes stored), not "=":
--     SQL Server ignores trailing spaces when comparing strings,
--     so ' ' = '' is TRUE and "=" cannot tell an empty string from a space.
--     NVARCHAR uses 2 bytes per character: '' = 0 bytes, ' ' = 2 bytes.
SELECT
    SUM(CASE WHEN k_symbol IS NULL          THEN 1 ELSE 0 END) AS null_values,
    SUM(CASE WHEN DATALENGTH(k_symbol) = 0  THEN 1 ELSE 0 END) AS empty_strings,
    SUM(CASE WHEN DATALENGTH(k_symbol) = 2
              AND k_symbol = ' '            THEN 1 ELSE 0 END) AS single_spaces,
    SUM(CASE WHEN k_symbol IS NULL OR TRIM(k_symbol) = ''
             THEN 1 ELSE 0 END)                                AS total_blank
FROM stg.trans;




-- Quote characters left inside values? Expect 0.
SELECT COUNT(*) FROM stg.account WHERE frequency LIKE '%"%';

-- Hidden carriage return at the end of the last column? Expect 0.
SELECT COUNT(*) FROM stg.trans WHERE [account] LIKE '%' + CHAR(13) + '%';

-- How did the blanks arrive?
SELECT
    SUM(CASE WHEN k_symbol IS NULL THEN 1 ELSE 0 END) AS null_values,
    SUM(CASE WHEN DATALENGTH(k_symbol) = 0 THEN 1 ELSE 0 END) AS empty_strings,
SUM(CASE WHEN DATALENGTH(k_symbol) = 2 AND k_symbol = ' ' THEN 1 ELSE 0 END) AS single_spaces
FROM stg.trans;


select * from stg.loan



WITH cte AS
(
    SELECT
        SUM(CASE WHEN status = 'B' THEN 1 ELSE 0 END) AS bpayments,
        SUM(CASE WHEN status = 'A' THEN 1 ELSE 0 END) AS apayments,
        SUM(CASE WHEN status = 'C' THEN 1 ELSE 0 END) AS cpayments,
        SUM(CASE WHEN status = 'D' THEN 1 ELSE 0 END) AS dpayments
    FROM stg.loan
)

SELECT
    CAST(bpayments AS DECIMAL(10,4))
        / NULLIF(bpayments + apayments, 0)
        AS problemloanrateforfinished,

    CAST(dpayments AS DECIMAL(10,4))
        / NULLIF(cpayments + dpayments, 0)
        AS problemloanrateforrunning,

    CAST(bpayments + dpayments AS DECIMAL(10,4))
        / NULLIF(
            apayments + bpayments + cpayments + dpayments, 0
        )
        AS overallrate

FROM cte;
