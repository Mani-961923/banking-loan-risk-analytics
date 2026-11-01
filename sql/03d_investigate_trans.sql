/* ==========================================================================
   Step 3d (part 1) - Investigate stg.trans before building core.trans
   Target : Microsoft SQL Server 2025 (Express), database BankAnalytics

   Read-only: nothing is created or changed.

   Open questions from Step 2 profiling:
     Q1. Is the blank 'operation' (183,114 rows) the interest postings
         ('UROK', also 183,114 rows)?
     Q2. Which operations appear under the undocumented type 'VYBER'?
     Q3. Does 'VYBER' move the balance like a debit or like a credit?

   Decision rule for Q3, stated BEFORE looking at the results:
     - First, the control group must work: PRIJEM (credits) mostly
       "balance up by amount", VYDAJ (debits) mostly "balance down by amount".
       If not, the method is unreliable and VYBER is not judged.
     - If VYBER shows "down by amount" at a share similar to VYDAJ,
       it is treated as a debit (original code kept for traceability).
     - Otherwise it stays a separate category, documented as a limitation.
   ========================================================================== */

USE BankAnalytics;
GO

/* --------------------------------------------------------------------------
   Check 1: blank operation vs interest postings
   Expect all three = 183,114 if the blanks are structural.
   TRIM(NULL) is NULL, and NULLIF(x, '') turns an empty string into NULL,
   so "IS NULL" catches both forms of blank.
   -------------------------------------------------------------------------- */
SELECT
    SUM(CASE WHEN NULLIF(TRIM(operation), N'') IS NULL THEN 1 ELSE 0 END) AS operation_blank,
    SUM(CASE WHEN TRIM(k_symbol) = N'UROK'             THEN 1 ELSE 0 END) AS urok_rows,
    SUM(CASE WHEN NULLIF(TRIM(operation), N'') IS NULL
              AND TRIM(k_symbol) = N'UROK'             THEN 1 ELSE 0 END) AS blank_and_urok
FROM stg.trans;

/* --------------------------------------------------------------------------
   Check 2: type x operation crosstab
   -------------------------------------------------------------------------- */
SELECT TRIM([type])                                     AS type_code,
       COALESCE(NULLIF(TRIM(operation), N''), N'(blank)') AS operation,
       COUNT(*)                                         AS n_rows
FROM stg.trans
GROUP BY TRIM([type]), COALESCE(NULLIF(TRIM(operation), N''), N'(blank)')
ORDER BY type_code, n_rows DESC;

/* --------------------------------------------------------------------------
   Check 3: ledger test with LAG
     balance_change = this balance - previous balance on the SAME account.
     Order: date, then trans_id as a tie-breaker for same-day transactions
     (an ASSUMPTION; the "neither" category measures how often it fails).
     Categories are mutually exclusive, so they add up to the row count.
   -------------------------------------------------------------------------- */
WITH t AS (
    SELECT TRY_CONVERT(INT, TRIM(trans_id))                               AS trans_id,
           TRY_CONVERT(INT, TRIM(account_id))                             AS account_id,
           TRY_CONVERT(DATE, N'19' + LEFT(TRIM([date]), 6), 112)          AS trans_date,
           TRIM([type])                                                   AS type_code,
           TRY_CONVERT(DECIMAL(12,2), TRIM(amount))                       AS amount,
           TRY_CONVERT(DECIMAL(12,2), TRIM(balance))                      AS balance
    FROM stg.trans
),
w AS (
    SELECT type_code,
           amount,
           balance - LAG(balance) OVER (PARTITION BY account_id
                                        ORDER BY trans_date, trans_id)    AS balance_change
    FROM t
),
c AS (
    SELECT type_code,
           CASE WHEN balance_change IS NULL      THEN 'first'
                WHEN amount = 0                  THEN 'zero'
                WHEN balance_change =  amount    THEN 'up'
                WHEN balance_change = -amount    THEN 'down'
                ELSE                                  'neither'
           END AS movement
    FROM w
)
SELECT type_code,
       COUNT(*)                                                   AS rows_total,
       SUM(CASE WHEN movement = 'first'   THEN 1 ELSE 0 END)      AS first_of_account,
       SUM(CASE WHEN movement = 'zero'    THEN 1 ELSE 0 END)      AS zero_amount,
       SUM(CASE WHEN movement = 'up'      THEN 1 ELSE 0 END)      AS up_by_amount,
       SUM(CASE WHEN movement = 'down'    THEN 1 ELSE 0 END)      AS down_by_amount,
       SUM(CASE WHEN movement = 'neither' THEN 1 ELSE 0 END)      AS neither,
       -- shares among rows that can be judged (excluding first and zero)
       CAST(100.0 * SUM(CASE WHEN movement = 'up'      THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN movement IN ('up', 'down', 'neither') THEN 1 ELSE 0 END), 0)
            AS DECIMAL(5,1))                                      AS pct_up,
       CAST(100.0 * SUM(CASE WHEN movement = 'down'    THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN movement IN ('up', 'down', 'neither') THEN 1 ELSE 0 END), 0)
            AS DECIMAL(5,1))                                      AS pct_down,
       CAST(100.0 * SUM(CASE WHEN movement = 'neither' THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN movement IN ('up', 'down', 'neither') THEN 1 ELSE 0 END), 0)
            AS DECIMAL(5,1))                                      AS pct_neither
FROM c
GROUP BY type_code
ORDER BY type_code;