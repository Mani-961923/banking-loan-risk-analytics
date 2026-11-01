/* ==========================================================================
   Step 3d (part 1b) - Clean ledger test (read-only)
   Target : Microsoft SQL Server 2025 (Express), database BankAnalytics

   Why: in part 1, 46-59% of control rows (PRIJEM, VYDAJ) were "neither".
        Hypothesis: same-day transactions whose true order is unknown
        (the data has dates but no times; trans_id was only a guess).

   Test: judge only rows where BOTH this transaction and the previous one
         were the only transaction of their day for that account.
         There, "previous balance" is certain: no ordering guess involved.

   Decision rule, stated BEFORE the results:
     - "neither" near 0% on clean rows -> balances are reliable; the earlier
       "neither" was ordering noise. Judge VYBER on the clean rows using the
       original rule (debit if "down" share is similar to VYDAJ's).
     - "neither" still high -> the balance chain has gaps; balance-based
       features need caution and this is documented as a limitation.
   ========================================================================== */

USE BankAnalytics;
GO

WITH t AS (
    SELECT TRY_CONVERT(INT, TRIM(trans_id))                       AS trans_id,
           TRY_CONVERT(INT, TRIM(account_id))                     AS account_id,
           TRY_CONVERT(DATE, N'19' + LEFT(TRIM([date]), 6), 112)  AS trans_date,
           TRIM([type])                                           AS type_code,
           TRY_CONVERT(DECIMAL(12,2), TRIM(amount))               AS amount,
           TRY_CONVERT(DECIMAL(12,2), TRIM(balance))              AS balance
    FROM stg.trans
),
d AS (
    -- How many transactions this account has on this day (kept on every row)
    SELECT *,
           COUNT(*) OVER (PARTITION BY account_id, trans_date) AS n_same_day
    FROM t
),
w AS (
    -- A window function cannot be nested inside another one,
    -- so LAG is applied to n_same_day in this separate CTE.
    SELECT type_code,
           amount,
           n_same_day,
           LAG(n_same_day) OVER (PARTITION BY account_id
                                 ORDER BY trans_date, trans_id)   AS prev_n_same_day,
           balance - LAG(balance) OVER (PARTITION BY account_id
                                        ORDER BY trans_date, trans_id) AS balance_change
    FROM d
),
c AS (
    SELECT type_code,
           CASE WHEN balance_change IS NULL                     THEN 'first'
                WHEN n_same_day > 1 OR prev_n_same_day > 1      THEN 'ambiguous_order'
                WHEN amount = 0                                 THEN 'zero'
                WHEN balance_change =  amount                   THEN 'up'
                WHEN balance_change = -amount                   THEN 'down'
                ELSE                                                 'neither'
           END AS movement
    FROM w
)
SELECT type_code,
       COUNT(*)                                                       AS rows_total,
       SUM(CASE WHEN movement = 'first'           THEN 1 ELSE 0 END)  AS first_of_account,
       SUM(CASE WHEN movement = 'ambiguous_order' THEN 1 ELSE 0 END)  AS ambiguous_order,
       SUM(CASE WHEN movement = 'zero'            THEN 1 ELSE 0 END)  AS zero_amount,
       SUM(CASE WHEN movement IN ('up', 'down', 'neither')
                                                  THEN 1 ELSE 0 END)  AS clean_rows_judged,
       SUM(CASE WHEN movement = 'up'              THEN 1 ELSE 0 END)  AS up_by_amount,
       SUM(CASE WHEN movement = 'down'            THEN 1 ELSE 0 END)  AS down_by_amount,
       SUM(CASE WHEN movement = 'neither'         THEN 1 ELSE 0 END)  AS neither,
       CAST(100.0 * SUM(CASE WHEN movement = 'up'      THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN movement IN ('up', 'down', 'neither') THEN 1 ELSE 0 END), 0)
            AS DECIMAL(5,1))                                          AS pct_up,
       CAST(100.0 * SUM(CASE WHEN movement = 'down'    THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN movement IN ('up', 'down', 'neither') THEN 1 ELSE 0 END), 0)
            AS DECIMAL(5,1))                                          AS pct_down,
       CAST(100.0 * SUM(CASE WHEN movement = 'neither' THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN movement IN ('up', 'down', 'neither') THEN 1 ELSE 0 END), 0)
            AS DECIMAL(5,1))                                          AS pct_neither
FROM c
GROUP BY type_code
ORDER BY type_code;