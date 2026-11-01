/* ==========================================================================
   Step 3d (part 2) - Build core.trans
   Target : Microsoft SQL Server 2025 (Express), database BankAnalytics
   Run after 03c_build_core.sql (core.account and core.code_label must exist).

   Evidence-based rules (from 03d part 1 and part 1b):
     - Blank operation = interest posting: all 183,114 blanks are 'UROK'
       and all 'UROK' rows are blank. Encoded as a CHECK constraint.
     - type 'VYBER' = debit: 100% "balance down by amount" on 9,597 clean
       rows (controls: PRIJEM 97.0% up, VYDAJ 99.6% down); every VYBER row
       has operation 'VYBER' (cash withdrawal). Original code kept in
       type_code_raw for traceability.
     - Within-day order is unknown (dates only), so later features must not
       depend on the order of transactions within a day.
     - Limitation: ~5,300 clean rows (PRIJEM 4,160; VYDAJ 1,136) do not
       reconcile to +/- amount; cause unknown, documented.
   ========================================================================== */

USE BankAnalytics;
GO

/* --------------------------------------------------------------------------
   1. Record the VYBER decision in the lookup table (one place, rerunnable)
   -------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM core.code_label
               WHERE code_type = N'trans_type' AND code = N'VYBER')
    INSERT INTO core.code_label (code_type, code, label_en)
    VALUES (N'trans_type', N'VYBER', N'Debit');
GO

/* --------------------------------------------------------------------------
   2. Table
   -------------------------------------------------------------------------- */
DROP TABLE IF EXISTS core.trans;

CREATE TABLE core.trans (
    trans_id        INT            NOT NULL,
    account_id      INT            NOT NULL,
    trans_date      DATE           NOT NULL,
    type_code_raw   NVARCHAR(10)   NOT NULL,   -- PRIJEM / VYDAJ / VYBER, as delivered
    direction       NVARCHAR(10)   NOT NULL,   -- Credit / Debit (from core.code_label)
    operation_code  NVARCHAR(30)   NULL,       -- NULL only for interest postings
    operation       NVARCHAR(60)   NOT NULL,
    amount          DECIMAL(12,2)  NOT NULL,
    signed_amount   AS (CASE WHEN direction = N'Credit' THEN amount ELSE -amount END),
    balance         DECIMAL(12,2)  NOT NULL,   -- may be negative (overdraft)
    purpose_code    NVARCHAR(20)   NULL,
    purpose         NVARCHAR(60)   NULL,
    partner_bank    NVARCHAR(10)   NULL,
    partner_account NVARCHAR(20)   NULL,       -- identifier, kept as text
    CONSTRAINT pk_trans PRIMARY KEY (trans_id),
    CONSTRAINT fk_trans_account FOREIGN KEY (account_id)
        REFERENCES core.account (account_id),
    CONSTRAINT ck_trans_direction CHECK (direction IN (N'Credit', N'Debit')),
    CONSTRAINT ck_trans_amount    CHECK (amount >= 0),      -- 14 zero amounts exist
    -- Finding from Check 1, enforced: a blank operation is only allowed for interest
    CONSTRAINT ck_trans_blank_operation_is_interest
        CHECK (operation_code IS NOT NULL OR purpose_code = N'UROK'),
    -- Fail-fast for a nullable column: a purpose code without a label is rejected
    CONSTRAINT ck_trans_purpose_pair
        CHECK ((purpose_code IS NULL AND purpose IS NULL)
            OR (purpose_code IS NOT NULL AND purpose IS NOT NULL))
);
GO

/* --------------------------------------------------------------------------
   3. Load (TABLOCK on an empty table allows minimal logging under the
      SIMPLE recovery model, which makes a 1M-row insert faster)
      Blanks in staging arrive as NULL or a single space:
      NULLIF(TRIM(x), N'') turns both into NULL.
   -------------------------------------------------------------------------- */
INSERT INTO core.trans WITH (TABLOCK)
       (trans_id, account_id, trans_date, type_code_raw, direction,
        operation_code, operation, amount, balance,
        purpose_code, purpose, partner_bank, partner_account)
SELECT TRY_CONVERT(INT, TRIM(s.trans_id)),
       TRY_CONVERT(INT, TRIM(s.account_id)),
       TRY_CONVERT(DATE, N'19' + LEFT(TRIM(s.[date]), 6), 112),
       TRIM(s.[type]),
       lt.label_en,
       NULLIF(TRIM(s.operation), N''),
       CASE WHEN NULLIF(TRIM(s.operation), N'') IS NULL
            THEN N'Interest posting'
            ELSE lo.label_en          -- unknown operation code -> NULL -> load fails
       END,
       TRY_CONVERT(DECIMAL(12,2), TRIM(s.amount)),
       TRY_CONVERT(DECIMAL(12,2), TRIM(s.balance)),
       NULLIF(TRIM(s.k_symbol), N''),
       lp.label_en,
       NULLIF(TRIM(s.bank), N''),
       NULLIF(TRIM(s.[account]), N'')
FROM stg.trans s
LEFT JOIN core.code_label lt
       ON lt.code_type = N'trans_type'
      AND lt.code      = TRIM(s.[type])
LEFT JOIN core.code_label lo
       ON lo.code_type = N'trans_operation'
      AND lo.code      = NULLIF(TRIM(s.operation), N'')
LEFT JOIN core.code_label lp
       ON lp.code_type = N'trans_purpose'
      AND lp.code      = NULLIF(TRIM(s.k_symbol), N'');
GO

/* --------------------------------------------------------------------------
   4. Covering index for per-account, date-range queries (built after load)
   -------------------------------------------------------------------------- */
CREATE NONCLUSTERED INDEX ix_trans_account_date
    ON core.trans (account_id, trans_date)
    INCLUDE (direction, amount, balance, purpose_code);
GO

/* ==========================================================================
   VALIDATION
   ========================================================================== */

-- V1. Row count and money control total (core must equal staging exactly)
SELECT (SELECT COUNT(*) FROM stg.trans)                                    AS stg_rows,
       (SELECT COUNT(*) FROM core.trans)                                   AS core_rows,
       (SELECT SUM(TRY_CONVERT(DECIMAL(18,2), TRIM(amount))) FROM stg.trans) AS stg_amount_total,
       (SELECT SUM(CAST(amount AS DECIMAL(18,2))) FROM core.trans)         AS core_amount_total;

-- V2. Direction by original type
--     Expect PRIJEM->Credit 405,083 / VYBER->Debit 16,666 / VYDAJ->Debit 634,571
SELECT type_code_raw, direction, COUNT(*) AS n_rows
FROM core.trans
GROUP BY type_code_raw, direction
ORDER BY type_code_raw;

-- V3. Operation labels (expect 'Interest posting' = 183,114)
SELECT operation, COUNT(*) AS n_rows
FROM core.trans
GROUP BY operation
ORDER BY n_rows DESC;

-- V4. Transactions with no purpose (expect 535,314 = 481,881 + 53,433)
SELECT SUM(CASE WHEN purpose_code IS NULL THEN 1 ELSE 0 END) AS no_purpose
FROM core.trans;

-- V5. Cross-table check: loan payments vs loans
--     Expect 682 accounts with loan payments, 0 of them without a loan
SELECT
    (SELECT COUNT(DISTINCT account_id)
       FROM core.trans
      WHERE purpose_code = N'UVER')                                  AS accounts_with_loan_payments,
    (SELECT COUNT(DISTINCT t.account_id)
       FROM core.trans t
      WHERE t.purpose_code = N'UVER'
        AND NOT EXISTS (SELECT 1 FROM core.loan l
                        WHERE l.account_id = t.account_id))          AS loan_payments_without_loan;