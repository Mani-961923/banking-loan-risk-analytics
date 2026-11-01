/* ==========================================================================
   Step 3c - Build the core layer (typed, labeled, constrained tables)
   Target : Microsoft SQL Server 2025 (Express), database BankAnalytics

   Builds: core.code_label, core.district, core.account, core.client,
           core.disp, core.loan, core.card, core.permanent_order
   core.trans is built in Step 3d.

   Design rules
     - TRY_CONVERT + NOT NULL columns = fail fast: a failed conversion
       becomes NULL, hits NOT NULL, and the insert stops with a clear error.
     - Labels come from one lookup table (core.code_label) via LEFT JOIN,
       so an unknown code also fails loudly instead of silently dropping rows.
     - Constraints enforce the rules observed in Step 2 profiling.

   Rerunnable: tables are dropped in child-to-parent order and rebuilt.
   ========================================================================== */

USE BankAnalytics;
GO

/* --------------------------------------------------------------------------
   0. Drop existing core tables, children first (foreign keys point upward)
   -------------------------------------------------------------------------- */
DROP TABLE IF EXISTS core.trans;            -- rebuilt in Step 3d
DROP TABLE IF EXISTS core.permanent_order;
DROP TABLE IF EXISTS core.card;
DROP TABLE IF EXISTS core.loan;
DROP TABLE IF EXISTS core.disp;
DROP TABLE IF EXISTS core.client;
DROP TABLE IF EXISTS core.account;
DROP TABLE IF EXISTS core.district;
DROP TABLE IF EXISTS core.code_label;
GO

/* --------------------------------------------------------------------------
   1. Code-label lookup (Czech codes -> English), per PKDD'99 documentation
      'VYBER' as a transaction TYPE is deliberately absent: Step 3d tests it.
   -------------------------------------------------------------------------- */
CREATE TABLE core.code_label (
    code_type NVARCHAR(30) NOT NULL,
    code      NVARCHAR(30) NOT NULL,
    label_en  NVARCHAR(60) NOT NULL,
    CONSTRAINT pk_code_label PRIMARY KEY (code_type, code)
);

INSERT INTO core.code_label (code_type, code, label_en) VALUES
(N'account_frequency', N'POPLATEK MESICNE',   N'Monthly statement'),
(N'account_frequency', N'POPLATEK TYDNE',     N'Weekly statement'),
(N'account_frequency', N'POPLATEK PO OBRATU', N'Statement after each transaction'),
(N'disp_type',         N'OWNER',              N'Owner'),
(N'disp_type',         N'DISPONENT',          N'Authorized user'),
(N'loan_status',       N'A',                  N'Finished - repaid'),
(N'loan_status',       N'B',                  N'Finished - not repaid'),
(N'loan_status',       N'C',                  N'Running - OK so far'),
(N'loan_status',       N'D',                  N'Running - client in debt'),
(N'order_purpose',     N'SIPO',               N'Household payment'),
(N'order_purpose',     N'POJISTNE',           N'Insurance payment'),
(N'order_purpose',     N'LEASING',            N'Leasing payment'),
(N'order_purpose',     N'UVER',               N'Loan payment'),
(N'trans_type',        N'PRIJEM',             N'Credit'),
(N'trans_type',        N'VYDAJ',              N'Debit'),
(N'trans_operation',   N'VYBER KARTOU',       N'Card withdrawal'),
(N'trans_operation',   N'VKLAD',              N'Cash deposit'),
(N'trans_operation',   N'PREVOD Z UCTU',      N'Collection from another bank'),
(N'trans_operation',   N'VYBER',              N'Cash withdrawal'),
(N'trans_operation',   N'PREVOD NA UCET',     N'Remittance to another bank'),
(N'trans_purpose',     N'POJISTNE',           N'Insurance payment'),
(N'trans_purpose',     N'SLUZBY',             N'Statement fee'),
(N'trans_purpose',     N'UROK',               N'Interest credited'),
(N'trans_purpose',     N'SANKC. UROK',        N'Penalty interest (negative balance)'),
(N'trans_purpose',     N'SIPO',               N'Household payment'),
(N'trans_purpose',     N'DUCHOD',             N'Old-age pension'),
(N'trans_purpose',     N'UVER',               N'Loan payment');
GO

/* --------------------------------------------------------------------------
   2. District (A1..A16 renamed using the PKDD'99 documentation)
      A12 and A15 each contain one '?': stored as NULL (columns allow NULL).
      Analyses use the complete 1996 columns (A13, A16) instead.
   -------------------------------------------------------------------------- */
CREATE TABLE core.district (
    district_id            INT           NOT NULL,
    district_name          NVARCHAR(60)  NOT NULL,
    region                 NVARCHAR(60)  NOT NULL,
    inhabitants            INT           NOT NULL,
    munic_lt_500           INT           NOT NULL,  -- municipalities < 500 inhabitants
    munic_500_1999         INT           NOT NULL,
    munic_2000_9999        INT           NOT NULL,
    munic_10000_plus       INT           NOT NULL,
    n_cities               INT           NOT NULL,
    urban_ratio_pct        DECIMAL(5,1)  NOT NULL,
    avg_salary             INT           NOT NULL,
    unemployment_rate_95   DECIMAL(5,2)  NULL,      -- one '?' in source
    unemployment_rate_96   DECIMAL(5,2)  NOT NULL,
    entrepreneurs_per_1000 INT           NOT NULL,
    crimes_95              INT           NULL,      -- one '?' in source
    crimes_96              INT           NOT NULL,
    CONSTRAINT pk_district PRIMARY KEY (district_id)
);

INSERT INTO core.district
SELECT TRY_CONVERT(INT, TRIM(A1)),
       TRIM(A2),
       TRIM(A3),
       TRY_CONVERT(INT, TRIM(A4)),
       TRY_CONVERT(INT, TRIM(A5)),
       TRY_CONVERT(INT, TRIM(A6)),
       TRY_CONVERT(INT, TRIM(A7)),
       TRY_CONVERT(INT, TRIM(A8)),
       TRY_CONVERT(INT, TRIM(A9)),
       TRY_CONVERT(DECIMAL(5,1), TRIM(A10)),
       TRY_CONVERT(INT, TRIM(A11)),
       TRY_CONVERT(DECIMAL(5,2), NULLIF(TRIM(A12), N'?')),
       TRY_CONVERT(DECIMAL(5,2), TRIM(A13)),
       TRY_CONVERT(INT, TRIM(A14)),
       TRY_CONVERT(INT, NULLIF(TRIM(A15), N'?')),
       TRY_CONVERT(INT, TRIM(A16))
FROM stg.district;
GO

/* --------------------------------------------------------------------------
   3. Account
   -------------------------------------------------------------------------- */
CREATE TABLE core.account (
    account_id               INT           NOT NULL,
    district_id              INT           NOT NULL,  -- branch location
    statement_frequency_code NVARCHAR(30)  NOT NULL,
    statement_frequency      NVARCHAR(60)  NOT NULL,
    open_date                DATE          NOT NULL,
    CONSTRAINT pk_account PRIMARY KEY (account_id),
    CONSTRAINT fk_account_district FOREIGN KEY (district_id)
        REFERENCES core.district (district_id)
);

INSERT INTO core.account (account_id, district_id, statement_frequency_code,
                          statement_frequency, open_date)
SELECT TRY_CONVERT(INT, TRIM(a.account_id)),
       TRY_CONVERT(INT, TRIM(a.district_id)),
       TRIM(a.frequency),
       l.label_en,
       TRY_CONVERT(DATE, N'19' + LEFT(TRIM(a.[date]), 6), 112)
FROM stg.account a
LEFT JOIN core.code_label l
       ON l.code_type = N'account_frequency'
      AND l.code      = TRIM(a.frequency);
GO



/* --------------------------------------------------------------------------
   4. Client: birth_number YYMMDD, women's month stored as month + 50
      Store birth_date (fixed fact), not age (depends on a reference date).
   -------------------------------------------------------------------------- */
CREATE TABLE core.client (
    client_id   INT      NOT NULL,
    district_id INT      NOT NULL,  -- client's home district
    birth_date  DATE     NOT NULL,
    gender      CHAR(1)  NOT NULL,
    CONSTRAINT pk_client PRIMARY KEY (client_id),
    CONSTRAINT fk_client_district FOREIGN KEY (district_id)
        REFERENCES core.district (district_id),
    CONSTRAINT ck_client_gender CHECK (gender IN ('F', 'M'))
);

WITH src AS (
    SELECT TRY_CONVERT(INT, TRIM(client_id))                     AS client_id,
           TRY_CONVERT(INT, TRIM(district_id))                   AS district_id,
           TRY_CONVERT(INT, SUBSTRING(TRIM(birth_number), 1, 2)) AS yy,
           TRY_CONVERT(INT, SUBSTRING(TRIM(birth_number), 3, 2)) AS mm_raw,
           TRY_CONVERT(INT, SUBSTRING(TRIM(birth_number), 5, 2)) AS dd
    FROM stg.client
),
decoded AS (
    SELECT client_id,
           district_id,
           yy,
           CASE WHEN mm_raw > 50 THEN mm_raw - 50 ELSE mm_raw END AS mm,
           dd,
           CASE WHEN mm_raw > 50 THEN 'F' ELSE 'M' END            AS gender
    FROM src
)
INSERT INTO core.client (client_id, district_id, birth_date, gender)
SELECT client_id,
       district_id,
       -- build yyyymmdd text with zero padding, then convert (style 112)
       TRY_CONVERT(DATE,
           CONCAT('19',
                  RIGHT('0' + CAST(yy AS VARCHAR(2)), 2),
                  RIGHT('0' + CAST(mm AS VARCHAR(2)), 2),
                  RIGHT('0' + CAST(dd AS VARCHAR(2)), 2)), 112),
       gender
FROM decoded;
GO

/* --------------------------------------------------------------------------
   5. Disposition (who may operate which account)
      Filtered unique index: exactly the Step 2 finding, now enforced:
      one OWNER per account; authorized users are not limited.
   -------------------------------------------------------------------------- */
CREATE TABLE core.disp (
    disp_id        INT           NOT NULL,
    client_id      INT           NOT NULL,
    account_id     INT           NOT NULL,
    disp_type_code NVARCHAR(20)  NOT NULL,
    disp_type      NVARCHAR(60)  NOT NULL,
    CONSTRAINT pk_disp PRIMARY KEY (disp_id),
    CONSTRAINT fk_disp_client  FOREIGN KEY (client_id)  REFERENCES core.client (client_id),
    CONSTRAINT fk_disp_account FOREIGN KEY (account_id) REFERENCES core.account (account_id)
);

CREATE UNIQUE INDEX ux_disp_one_owner_per_account
    ON core.disp (account_id)
    WHERE disp_type_code = N'OWNER';

INSERT INTO core.disp (disp_id, client_id, account_id, disp_type_code, disp_type)
SELECT TRY_CONVERT(INT, TRIM(d.disp_id)),
       TRY_CONVERT(INT, TRIM(d.client_id)),
       TRY_CONVERT(INT, TRIM(d.account_id)),
       TRIM(d.[type]),
       l.label_en
FROM stg.disp d
LEFT JOIN core.code_label l
       ON l.code_type = N'disp_type'
      AND l.code      = TRIM(d.[type]);
GO

/* --------------------------------------------------------------------------
   6. Loan
      amount = monthly_payment x duration for all 682 loans (Step 2):
      the data holds no interest, so no profitability fields exist.
      contract_state and is_problem are computed columns: the business
      definitions are written once, in the table.
   -------------------------------------------------------------------------- */
CREATE TABLE core.loan (
    loan_id         INT            NOT NULL,
    account_id      INT            NOT NULL,
    grant_date      DATE           NOT NULL,
    amount          DECIMAL(12,2)  NOT NULL,
    duration_months INT            NOT NULL,
    monthly_payment DECIMAL(12,2)  NOT NULL,
    status          CHAR(1)        NOT NULL,
    status_desc     NVARCHAR(60)   NOT NULL,
    contract_state  AS (CASE WHEN status IN ('A', 'B') THEN 'Finished' ELSE 'Running' END),
    is_problem      AS (CASE WHEN status IN ('B', 'D') THEN 1 ELSE 0 END),
    CONSTRAINT pk_loan PRIMARY KEY (loan_id),
    CONSTRAINT uq_loan_account UNIQUE (account_id),           -- max 1 loan per account
    CONSTRAINT fk_loan_account FOREIGN KEY (account_id) REFERENCES core.account (account_id),
    CONSTRAINT ck_loan_status   CHECK (status IN ('A', 'B', 'C', 'D')),
    CONSTRAINT ck_loan_amount   CHECK (amount > 0),
    CONSTRAINT ck_loan_duration CHECK (duration_months IN (12, 24, 36, 48, 60))
);

INSERT INTO core.loan (loan_id, account_id, grant_date, amount, duration_months,
                       monthly_payment, status, status_desc)
SELECT TRY_CONVERT(INT, TRIM(s.loan_id)),
       TRY_CONVERT(INT, TRIM(s.account_id)),
       TRY_CONVERT(DATE, N'19' + LEFT(TRIM(s.[date]), 6), 112),
       TRY_CONVERT(DECIMAL(12,2), TRIM(s.amount)),
       TRY_CONVERT(INT, TRIM(s.duration)),
       TRY_CONVERT(DECIMAL(12,2), TRIM(s.payments)),
       TRIM(s.status),                 -- longer than 1 char would fail: truncation error
       l.label_en
FROM stg.loan s
LEFT JOIN core.code_label l
       ON l.code_type = N'loan_status'
      AND l.code      = TRIM(s.status);
GO

/* --------------------------------------------------------------------------
   7. Card ('issued' has a time part: LEFT(...,6) keeps YYMMDD)
   -------------------------------------------------------------------------- */
CREATE TABLE core.card (
    card_id    INT           NOT NULL,
    disp_id    INT           NOT NULL,
    card_type  NVARCHAR(20)  NOT NULL,
    issue_date DATE          NOT NULL,
    CONSTRAINT pk_card PRIMARY KEY (card_id),
    CONSTRAINT fk_card_disp FOREIGN KEY (disp_id) REFERENCES core.disp (disp_id),
    CONSTRAINT ck_card_type CHECK (card_type IN (N'junior', N'classic', N'gold'))
);

INSERT INTO core.card (card_id, disp_id, card_type, issue_date)
SELECT TRY_CONVERT(INT, TRIM(card_id)),
       TRY_CONVERT(INT, TRIM(disp_id)),
       TRIM([type]),
       TRY_CONVERT(DATE, N'19' + LEFT(TRIM(issued), 6), 112)
FROM stg.card;
GO

/* --------------------------------------------------------------------------
   8. Permanent order (source table "order", renamed: ORDER is a reserved word)
      Blank purpose (single space in source) -> NULL.
      recipient_account stays text: it is an identifier, not a quantity.
   -------------------------------------------------------------------------- */
CREATE TABLE core.permanent_order (
    order_id          INT            NOT NULL,
    account_id        INT            NOT NULL,
    recipient_bank    NVARCHAR(10)   NOT NULL,
    recipient_account NVARCHAR(20)   NOT NULL,
    amount            DECIMAL(12,2)  NOT NULL,
    purpose_code      NVARCHAR(20)   NULL,
    purpose           NVARCHAR(60)   NULL,
    CONSTRAINT pk_permanent_order PRIMARY KEY (order_id),
    CONSTRAINT fk_order_account FOREIGN KEY (account_id) REFERENCES core.account (account_id),
    CONSTRAINT ck_order_amount CHECK (amount > 0)
);

INSERT INTO core.permanent_order (order_id, account_id, recipient_bank, recipient_account,
                                  amount, purpose_code, purpose)
SELECT TRY_CONVERT(INT, TRIM(o.order_id)),
       TRY_CONVERT(INT, TRIM(o.account_id)),
       TRIM(o.bank_to),
       TRIM(o.account_to),
       TRY_CONVERT(DECIMAL(12,2), TRIM(o.amount)),
       NULLIF(TRIM(o.k_symbol), N''),
       l.label_en
FROM stg.[order] o
LEFT JOIN core.code_label l
       ON l.code_type = N'order_purpose'
      AND l.code      = NULLIF(TRIM(o.k_symbol), N'');
GO

/* ==========================================================================
   VALIDATION
   ========================================================================== */

-- V1. Row counts: core must equal staging
SELECT t.table_name, t.stg_rows, t.core_rows,
       CASE WHEN t.stg_rows = t.core_rows THEN 'OK' ELSE 'MISMATCH' END AS status
FROM (
    SELECT 'district' AS table_name, (SELECT COUNT(*) FROM stg.district) AS stg_rows,
           (SELECT COUNT(*) FROM core.district) AS core_rows
    UNION ALL SELECT 'account', (SELECT COUNT(*) FROM stg.account), (SELECT COUNT(*) FROM core.account)
    UNION ALL SELECT 'client',  (SELECT COUNT(*) FROM stg.client),  (SELECT COUNT(*) FROM core.client)
    UNION ALL SELECT 'disp',    (SELECT COUNT(*) FROM stg.disp),    (SELECT COUNT(*) FROM core.disp)
    UNION ALL SELECT 'loan',    (SELECT COUNT(*) FROM stg.loan),    (SELECT COUNT(*) FROM core.loan)
    UNION ALL SELECT 'card',    (SELECT COUNT(*) FROM stg.card),    (SELECT COUNT(*) FROM core.card)
    UNION ALL SELECT 'order',   (SELECT COUNT(*) FROM stg.[order]), (SELECT COUNT(*) FROM core.permanent_order)
) AS t;
-- V2. Known NULLs (expect 1 and 1) and unmapped labels (expect 0)
SELECT
    (SELECT COUNT(*) FROM core.district WHERE unemployment_rate_95 IS NULL) AS unemployment_95_null,
    (SELECT COUNT(*) FROM core.district WHERE crimes_95 IS NULL)            AS crimes_95_null,
    (SELECT COUNT(*) FROM core.permanent_order
      WHERE purpose_code IS NOT NULL AND purpose IS NULL)                    AS unmapped_labels;

-- V3. Gender (expect F = 2645, M = 2724, from Step 2 profiling)
SELECT gender, COUNT(*) AS clients
FROM core.client
GROUP BY gender
ORDER BY gender;

-- V4. Loans by contract state (expect Finished 234 / 31, Running 448 / 45)
SELECT contract_state,
       COUNT(*)        AS loans,
       SUM(is_problem) AS problem_loans
FROM core.loan
GROUP BY contract_state
ORDER BY contract_state;

-- V5. Negative test: the foreign key must reject a loan for a non-existent account
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO core.loan (loan_id, account_id, grant_date, amount, duration_months,
                           monthly_payment, status, status_desc)
    VALUES (999999, 99999999, '1998-01-01', 1200, 12, 100, 'A', N'negative test');
    ROLLBACK TRANSACTION;
    SELECT 'FAIL: orphan loan was accepted' AS negative_test;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'PASS: orphan loan rejected - ' + ERROR_MESSAGE() AS negative_test;
END CATCH;