/* ==========================================================================
   Step 3a - Create the BankAnalytics database, schemas and staging tables
   Project : Banking loan-risk analytics (PKDD'99 / Berka dataset)
   Target  : Microsoft SQL Server 2025 (Express)

   Layers
     stg  : raw CSV data, every column as text, nothing changed
     core : typed, cleaned tables (built in a later step)
     mart : analysis-ready tables for Tableau (built in a later step)

   The script is idempotent: it can be rerun safely.
   Staging columns are in the SAME ORDER as the CSV files, because
   BULK INSERT loads by position, not by column name.
   ========================================================================== */

IF DB_ID('BankAnalytics') IS NULL
    CREATE DATABASE BankAnalytics;
GO

USE BankAnalytics;
GO

-- CREATE SCHEMA must be alone in its batch, so it runs through EXEC.
IF SCHEMA_ID('stg')  IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('core') IS NULL EXEC('CREATE SCHEMA core');
IF SCHEMA_ID('mart') IS NULL EXEC('CREATE SCHEMA mart');
GO

/* --------------------------------------------------------------------------
   Staging tables: all NVARCHAR, no keys, no constraints.
   Staging accepts the data exactly as delivered.
   -------------------------------------------------------------------------- */

DROP TABLE IF EXISTS stg.account;
CREATE TABLE stg.account (
    account_id   NVARCHAR(100),
    district_id  NVARCHAR(100),
    frequency    NVARCHAR(100),
    [date]       NVARCHAR(100)
);

DROP TABLE IF EXISTS stg.client;
CREATE TABLE stg.client (
    client_id    NVARCHAR(100),
    birth_number NVARCHAR(100),
    district_id  NVARCHAR(100)
);

DROP TABLE IF EXISTS stg.disp;
CREATE TABLE stg.disp (
    disp_id      NVARCHAR(100),
    client_id    NVARCHAR(100),
    account_id   NVARCHAR(100),
    [type]       NVARCHAR(100)
);

DROP TABLE IF EXISTS stg.[order];
CREATE TABLE stg.[order] (
    order_id     NVARCHAR(100),
    account_id   NVARCHAR(100),
    bank_to      NVARCHAR(100),
    account_to   NVARCHAR(100),
    amount       NVARCHAR(100),
    k_symbol     NVARCHAR(100)
);

DROP TABLE IF EXISTS stg.trans;
CREATE TABLE stg.trans (
    trans_id     NVARCHAR(100),
    account_id   NVARCHAR(100),
    [date]       NVARCHAR(100),
    [type]       NVARCHAR(100),
    operation    NVARCHAR(100),
    amount       NVARCHAR(100),
    balance      NVARCHAR(100),
    k_symbol     NVARCHAR(100),
    bank         NVARCHAR(100),
    [account]    NVARCHAR(100)
);

DROP TABLE IF EXISTS stg.loan;
CREATE TABLE stg.loan (
    loan_id      NVARCHAR(100),
    account_id   NVARCHAR(100),
    [date]       NVARCHAR(100),
    amount       NVARCHAR(100),
    duration     NVARCHAR(100),
    payments     NVARCHAR(100),
    status       NVARCHAR(100)
);

DROP TABLE IF EXISTS stg.card;
CREATE TABLE stg.card (
    card_id      NVARCHAR(100),
    disp_id      NVARCHAR(100),
    [type]       NVARCHAR(100),
    issued       NVARCHAR(100)
);

-- District columns keep their source names A1..A16 in staging.
-- Meaningful names are given in the core layer, using the PKDD'99 documentation.
DROP TABLE IF EXISTS stg.district;
CREATE TABLE stg.district (
    A1  NVARCHAR(100), A2  NVARCHAR(100), A3  NVARCHAR(100), A4  NVARCHAR(100),
    A5  NVARCHAR(100), A6  NVARCHAR(100), A7  NVARCHAR(100), A8  NVARCHAR(100),
    A9  NVARCHAR(100), A10 NVARCHAR(100), A11 NVARCHAR(100), A12 NVARCHAR(100),
    A13 NVARCHAR(100), A14 NVARCHAR(100), A15 NVARCHAR(100), A16 NVARCHAR(100)
);
GO

/* --------------------------------------------------------------------------
   Validation: expect 8 tables in schema stg with column counts
   account 4, card 4, client 3, disp 4, district 16, loan 7, order 6, trans 10
   -------------------------------------------------------------------------- */
SELECT s.name AS schema_name, t.name AS table_name, COUNT(*) AS n_columns
FROM sys.tables  t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
GROUP BY s.name, t.name
ORDER BY t.name;

