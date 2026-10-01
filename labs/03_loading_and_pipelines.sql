-- =====================================================================
-- Lab 03: Stages, COPY INTO, unloading, Snowpipe, Streams, Tasks, Dynamic Tables
-- Domain 3 | Day 3
-- Self-contained: uses an internal stage, so no AWS setup is required.
-- The S3 / Snowpipe auto-ingest part at the end is a template for the real project.
-- =====================================================================
USE ROLE SYSADMIN;
USE WAREHOUSE wh_xs;
USE SCHEMA study_db.labs;

-- ---------------------------------------------------------------------
-- 1. Stages
--   user stage  : @~               (one per user, cannot be altered or dropped)
--   table stage : @%table_name     (one per table, no file format options)
--   named stage : @stage_name      (internal or external, most flexible)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT ff_csv
  TYPE = CSV
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL');

CREATE OR REPLACE STAGE stg_internal
  FILE_FORMAT = ff_csv
  DIRECTORY = (ENABLE = TRUE);   -- directory table: queryable file catalog

-- ---------------------------------------------------------------------
-- 2. Unloading: COPY INTO <stage> FROM <table|query>
-- ---------------------------------------------------------------------
COPY INTO @stg_internal/customers/
FROM (SELECT c_custkey, c_name, c_mktsegment, c_acctbal
      FROM snowflake_sample_data.tpch_sf1.customer LIMIT 5000)
FILE_FORMAT = (TYPE = CSV COMPRESSION = GZIP FIELD_OPTIONALLY_ENCLOSED_BY = '"')
HEADER = TRUE
MAX_FILE_SIZE = 50000;   -- small size to force several files

LIST @stg_internal/customers/;
ALTER STAGE stg_internal REFRESH;
SELECT relative_path, size FROM DIRECTORY(@stg_internal);

-- Query staged files directly before loading (positional columns $1, $2 ...)
SELECT $1, $2, $3, $4 FROM @stg_internal/customers/ (FILE_FORMAT => 'ff_csv') LIMIT 5;

-- ---------------------------------------------------------------------
-- 3. Loading: COPY INTO <table>
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE customers_raw (
  custkey     NUMBER,
  name        STRING,
  mktsegment  STRING,
  acctbal     NUMBER(12, 2)
);

-- Dry run: report errors without loading
COPY INTO customers_raw FROM @stg_internal/customers/ VALIDATION_MODE = RETURN_ERRORS;

COPY INTO customers_raw
FROM @stg_internal/customers/
ON_ERROR = 'CONTINUE';          -- other options: ABORT_STATEMENT (default for bulk), SKIP_FILE, SKIP_FILE_<n>

SELECT COUNT(*) FROM customers_raw;

-- Run the same COPY again: 0 rows, because load metadata (kept 64 days) skips loaded files
COPY INTO customers_raw FROM @stg_internal/customers/;
-- FORCE = TRUE would reload them and create duplicates

-- Load history
SELECT file_name, status, row_count, first_error_message
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'CUSTOMERS_RAW',
  START_TIME => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())));

-- ---------------------------------------------------------------------
-- 4. Streams: change tracking (CDC) on a table
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE customers_curated LIKE customers_raw;
CREATE OR REPLACE STREAM s_customers_raw ON TABLE customers_raw;

INSERT INTO customers_raw VALUES (999001, 'New Customer', 'BUILDING', 100.00);
UPDATE customers_raw SET acctbal = acctbal + 1 WHERE custkey = 1;

-- METADATA$ACTION, METADATA$ISUPDATE, METADATA$ROW_ID describe each change
SELECT custkey, acctbal, METADATA$ACTION, METADATA$ISUPDATE FROM s_customers_raw;

-- ---------------------------------------------------------------------
-- 5. Tasks: scheduled SQL. Consuming a stream in DML advances its offset
-- The task owner role needs the account-level EXECUTE TASK privilege
-- ---------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN;
USE ROLE SYSADMIN;

CREATE OR REPLACE TASK t_merge_customers
  WAREHOUSE = wh_xs                 -- omit WAREHOUSE to make it a serverless task
  SCHEDULE = '5 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('S_CUSTOMERS_RAW')
AS
MERGE INTO customers_curated t
USING (SELECT * FROM s_customers_raw WHERE METADATA$ACTION = 'INSERT') s
  ON t.custkey = s.custkey
WHEN MATCHED THEN UPDATE SET t.name = s.name, t.mktsegment = s.mktsegment, t.acctbal = s.acctbal
WHEN NOT MATCHED THEN INSERT (custkey, name, mktsegment, acctbal)
  VALUES (s.custkey, s.name, s.mktsegment, s.acctbal);

-- Tasks are created SUSPENDED. Run once manually instead of resuming the schedule:
EXECUTE TASK t_merge_customers;

SELECT name, state, scheduled_time, completed_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'T_MERGE_CUSTOMERS'))
ORDER BY scheduled_time DESC;

SELECT COUNT(*) FROM s_customers_raw;      -- 0 after the task consumed it
SELECT COUNT(*) FROM customers_curated;

-- ---------------------------------------------------------------------
-- 6. Dynamic Tables: declarative pipelines with a target freshness
-- ---------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE dt_segment_balance
  TARGET_LAG = '1 minute'
  WAREHOUSE = wh_xs
AS
SELECT mktsegment, COUNT(*) AS customers, SUM(acctbal) AS total_balance
FROM customers_curated
GROUP BY mktsegment;

SHOW DYNAMIC TABLES LIKE 'DT_SEGMENT_BALANCE';   -- refresh_mode, target_lag
ALTER DYNAMIC TABLE dt_segment_balance REFRESH;
SELECT * FROM dt_segment_balance;

-- Stop background refreshes to save credits
ALTER DYNAMIC TABLE dt_segment_balance SUSPEND;

-- ---------------------------------------------------------------------
-- 7. TEMPLATE for the real project: S3 + storage integration + Snowpipe auto-ingest
-- Needs ACCOUNTADMIN (or CREATE INTEGRATION) plus an IAM role in AWS. Not run in this lab.
-- ---------------------------------------------------------------------
/*
USE ROLE ACCOUNTADMIN;
CREATE STORAGE INTEGRATION s3_int
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<account_id>:role/<snowflake_role>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<bucket>/<path>/');

DESC INTEGRATION s3_int;   -- copy STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID into the IAM trust policy

CREATE STAGE stg_s3 URL = 's3://<bucket>/<path>/' STORAGE_INTEGRATION = s3_int FILE_FORMAT = ff_csv;

CREATE PIPE p_customers AUTO_INGEST = TRUE AS
  COPY INTO customers_raw FROM @stg_s3;

SHOW PIPES;   -- notification_channel = SQS ARN to set as the S3 event notification target
SELECT SYSTEM$PIPE_STATUS('p_customers');
*/

-- ---------------------------------------------------------------------
-- 8. Check yourself
-- Q: Files land in S3 every few minutes and must be loaded with minimal latency and no warehouse to manage. What do you use?
-- Q: You re-run COPY INTO on the same files and nothing loads. Why, and how do you force it?
-- Q: Stream + Task vs Dynamic Table: when would you pick each?
-- ---------------------------------------------------------------------
