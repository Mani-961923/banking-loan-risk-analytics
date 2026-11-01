/* ==========================================================================
   Step 4 - Loan-level mart: one row per loan, point-in-time features
   Target : Microsoft SQL Server 2025 (Express), database BankAnalytics
   Output : mart.loan_features (682 rows)

   Point-in-time rule: behavior features use ONLY transactions in the
   90 days strictly before the grant date:
       grant_date - 90 days <= trans_date < grant_date
   Every loan has >= 102 days of account history (Step 2), so every loan
   gets a full 90-day window.

   Features are order-independent (MIN, COUNT, SUM, AVG), because the order
   of transactions within a day is unknown (Step 3d).
   District = branch district (account.district_id).
   ========================================================================== */

USE BankAnalytics;
GO

DROP TABLE IF EXISTS mart.loan_features;
GO

DECLARE @window_days INT  = 90;
DECLARE @data_end    DATE = (SELECT MAX(trans_date) FROM core.trans);   -- 1998-12-31

WITH txn AS (
    -- 90-day pre-loan behavior per loan (LEFT JOIN keeps loans with no activity)
    SELECT l.loan_id,
           COUNT(t.trans_id)                                                    AS n_trans_90d,
           SUM(CASE WHEN t.direction = N'Credit' THEN t.amount ELSE 0 END)      AS credits_90d,
           SUM(CASE WHEN t.direction = N'Debit'  THEN t.amount ELSE 0 END)      AS debits_90d,
           MIN(t.balance)                                                       AS min_balance_90d,
           AVG(t.balance)                                                       AS avg_balance_90d,
           SUM(CASE WHEN t.balance < 0 THEN 1 ELSE 0 END)                       AS n_negative_balance_90d,
           SUM(CASE WHEN t.purpose_code = N'SANKC. UROK' THEN 1 ELSE 0 END)     AS n_penalty_interest_90d
    FROM core.loan l
    LEFT JOIN core.trans t
           ON t.account_id  = l.account_id
          AND t.trans_date >= DATEADD(DAY, -@window_days, l.grant_date)
          AND t.trans_date <  l.grant_date
    GROUP BY l.loan_id
),
owner AS (
    -- Exactly one owner per account (enforced by ux_disp_one_owner_per_account)
    SELECT d.account_id, d.disp_id, c.client_id, c.gender, c.birth_date
    FROM core.disp d
    JOIN core.client c ON c.client_id = d.client_id
    WHERE d.disp_type_code = N'OWNER'
),
users AS (
    SELECT account_id, COUNT(*) AS n_authorized_users
    FROM core.disp
    WHERE disp_type_code = N'DISPONENT'
    GROUP BY account_id
)
SELECT
    -- Loan
    l.loan_id,
    l.account_id,
    l.grant_date,
    YEAR(l.grant_date)                                         AS grant_year,
    l.amount                                                   AS loan_amount,
    l.duration_months,
    l.monthly_payment,
    l.status,
    l.status_desc,
    l.contract_state,
    l.is_problem,
    DATEDIFF(MONTH, l.grant_date, @data_end)                   AS months_observed,

    -- Account
    a.statement_frequency,
    DATEDIFF(DAY, a.open_date, l.grant_date)                   AS account_age_days,

    -- Owner (age at the grant date, corrected for birthdays not yet reached)
    o.client_id                                                AS owner_client_id,
    o.gender                                                   AS owner_gender,
    DATEDIFF(YEAR, o.birth_date, l.grant_date)
      - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, o.birth_date, l.grant_date), o.birth_date)
                  > l.grant_date THEN 1 ELSE 0 END             AS owner_age_at_grant,
    COALESCE(u.n_authorized_users, 0)                          AS n_authorized_users,
    CASE WHEN cd.card_id IS NOT NULL THEN 1 ELSE 0 END         AS had_card_before_grant,
    COALESCE(cd.card_type, N'none')                            AS card_type_before_grant,

    -- Branch district
    di.district_name,
    di.region,
    di.avg_salary                                              AS district_avg_salary,
    di.unemployment_rate_96                                    AS district_unemployment_96,
    CAST(1000.0 * di.crimes_96 / di.inhabitants AS DECIMAL(8,2)) AS district_crimes_per_1000_96,
    di.urban_ratio_pct                                         AS district_urban_ratio_pct,

    -- 90-day pre-loan behavior
    x.n_trans_90d,
    x.credits_90d,
    x.debits_90d,
    x.credits_90d - x.debits_90d                               AS net_flow_90d,
    CAST(x.credits_90d / 3.0 AS DECIMAL(12,2))                 AS avg_monthly_credits_90d,
    x.min_balance_90d,
    CAST(x.avg_balance_90d AS DECIMAL(12,2))                   AS avg_balance_90d,
    x.n_negative_balance_90d,
    CASE WHEN x.n_negative_balance_90d > 0 THEN 1 ELSE 0 END   AS had_negative_balance_90d,
    x.n_penalty_interest_90d,
    CAST(l.monthly_payment / NULLIF(x.credits_90d / 3.0, 0)
         AS DECIMAL(8,3))                                      AS payment_to_credits_ratio
INTO mart.loan_features
FROM core.loan l
JOIN core.account  a  ON a.account_id   = l.account_id
JOIN core.district di ON di.district_id = a.district_id
JOIN owner         o  ON o.account_id   = l.account_id
LEFT JOIN users    u  ON u.account_id   = l.account_id
LEFT JOIN core.card cd
       ON cd.disp_id    = o.disp_id
      AND cd.issue_date < l.grant_date          -- card held BEFORE the loan only
JOIN txn           x  ON x.loan_id      = l.loan_id;
GO

ALTER TABLE mart.loan_features
    ADD CONSTRAINT pk_loan_features PRIMARY KEY (loan_id);
GO

/* ==========================================================================
   VALIDATION
   ========================================================================== */

-- V1. One row per loan (expect 682 / 682: no fan-out)
SELECT COUNT(*)                AS n_rows,
       COUNT(DISTINCT loan_id) AS n_distinct_loans
FROM mart.loan_features;

-- V2. Outcomes (expect Finished 234 / 31, Running 448 / 45)
SELECT contract_state, COUNT(*) AS loans, SUM(is_problem) AS problem_loans
FROM mart.loan_features
GROUP BY contract_state
ORDER BY contract_state;

-- V3. Feature ranges (sanity checks)
SELECT MIN(account_age_days)                                      AS min_account_age_days,  -- expect 102
       SUM(CASE WHEN n_trans_90d = 0 THEN 1 ELSE 0 END)           AS loans_no_trans_90d,    -- expect 0
       MIN(n_trans_90d)                                           AS min_trans_90d,
       MAX(n_trans_90d)                                           AS max_trans_90d,
       MIN(owner_age_at_grant)                                    AS min_owner_age,
       MAX(owner_age_at_grant)                                    AS max_owner_age,
       SUM(had_card_before_grant)                                 AS loans_with_card_before,
       SUM(had_negative_balance_90d)                              AS loans_with_negative_balance_90d,
       SUM(CASE WHEN payment_to_credits_ratio IS NULL THEN 1 ELSE 0 END) AS ratio_null
FROM mart.loan_features;

-- V4. First look: problem-loan rate by negative balance in the 90 days
--     before the loan, split by contract state (do not mix finished/running)
SELECT contract_state,
       had_negative_balance_90d,
       COUNT(*)                                       AS loans,
       SUM(is_problem)                                AS problem_loans,
       CAST(100.0 * SUM(is_problem) / COUNT(*) AS DECIMAL(5,1)) AS problem_rate_pct
FROM mart.loan_features
GROUP BY contract_state, had_negative_balance_90d
ORDER BY contract_state, had_negative_balance_90d;



SELECT owner_age_at_grant, COUNT(*) AS loans, SUM(is_problem) AS problem_loans
FROM mart.loan_features
WHERE owner_age_at_grant < 18
GROUP BY owner_age_at_grant
ORDER BY owner_age_at_grant;