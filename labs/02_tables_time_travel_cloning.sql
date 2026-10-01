-- =====================================================================
-- Lab 02: Table types, views, Time Travel, Fail-safe, Cloning, Cortex
-- Domain 1 (1.5, 1.6) + Domain 5.1 | Day 2
-- =====================================================================
USE ROLE SYSADMIN;
USE WAREHOUSE wh_xs;
USE SCHEMA study_db.labs;

-- ---------------------------------------------------------------------
-- 1. Table types and their data-protection behavior
--   permanent : Time Travel 0-1 day (Standard) or up to 90 days (Enterprise+), Fail-safe 7 days
--   transient : Time Travel 0-1 day, no Fail-safe, persists until dropped
--   temporary : Time Travel 0-1 day, no Fail-safe, dropped when the session ends
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE orders_perm AS
SELECT * FROM snowflake_sample_data.tpch_sf1.orders LIMIT 10000;

CREATE OR REPLACE TRANSIENT TABLE orders_transient AS SELECT * FROM orders_perm;
CREATE OR REPLACE TEMPORARY TABLE orders_temp AS SELECT * FROM orders_perm;

SHOW TABLES LIKE 'ORDERS%';   -- check "kind" and "retention_time"

-- Enterprise+: extend Time Travel on a permanent table
ALTER TABLE orders_perm SET DATA_RETENTION_TIME_IN_DAYS = 7;

-- ---------------------------------------------------------------------
-- 2. Micro-partitions: metadata Snowflake keeps per partition
-- ---------------------------------------------------------------------
SELECT SYSTEM$CLUSTERING_INFORMATION('orders_perm', '(o_orderdate)');

-- ---------------------------------------------------------------------
-- 3. Time Travel
-- ---------------------------------------------------------------------
SET before_update = (SELECT CURRENT_TIMESTAMP());

UPDATE orders_perm SET o_orderstatus = 'X' WHERE o_orderpriority = '1-URGENT';
SET update_qid = LAST_QUERY_ID();   -- query ID of the UPDATE

SELECT o_orderstatus, COUNT(*) FROM orders_perm GROUP BY 1;                                   -- current
SELECT o_orderstatus, COUNT(*) FROM orders_perm AT (TIMESTAMP => $before_update) GROUP BY 1;  -- past

-- Recover the previous state by cloning a point in time
CREATE OR REPLACE TABLE orders_restored CLONE orders_perm AT (TIMESTAMP => $before_update);

-- Using a query ID instead of a timestamp: state right before the UPDATE ran
SELECT o_orderstatus, COUNT(*) FROM orders_perm BEFORE (STATEMENT => $update_qid) GROUP BY 1;

-- ---------------------------------------------------------------------
-- 4. DROP and UNDROP (works within the Time Travel retention period)
-- ---------------------------------------------------------------------
DROP TABLE orders_restored;
SHOW TABLES HISTORY LIKE 'ORDERS_RESTORED';   -- dropped_on is filled
UNDROP TABLE orders_restored;

-- After Time Travel expires, data moves to Fail-safe (permanent tables only).
-- Fail-safe is NOT user-accessible: recovery only through Snowflake Support.

-- ---------------------------------------------------------------------
-- 5. Zero-Copy Cloning: metadata-only copy, storage is shared until data changes
-- ---------------------------------------------------------------------
CREATE OR REPLACE SCHEMA study_db.labs_dev CLONE study_db.labs;
SHOW TABLES IN SCHEMA study_db.labs_dev;   -- compare with the source schema: is ORDERS_TEMP there?

-- ---------------------------------------------------------------------
-- 6. Views
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_urgent AS
SELECT o_orderkey, o_totalprice FROM orders_perm WHERE o_orderpriority = '1-URGENT';

-- Secure view: hides the definition and disables optimizations that could expose data
CREATE OR REPLACE SECURE VIEW sv_urgent AS
SELECT o_orderkey, o_totalprice FROM orders_perm WHERE o_orderpriority = '1-URGENT';

SHOW VIEWS LIKE '%URGENT';                     -- is_secure column
SELECT GET_DDL('VIEW', 'sv_urgent');           -- owner can still see the DDL

-- Materialized view (Enterprise+): precomputed, maintained by a background service
CREATE OR REPLACE MATERIALIZED VIEW mv_status AS
SELECT o_orderstatus, COUNT(*) AS cnt, SUM(o_totalprice) AS total
FROM orders_perm
GROUP BY o_orderstatus;

-- ---------------------------------------------------------------------
-- 7. Cortex AI SQL functions
-- Requires the SNOWFLAKE.CORTEX_USER (or AI_FUNCTIONS_USER) database role.
-- On a privilege error, run as ACCOUNTADMIN or: GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SYSADMIN;
-- Model availability depends on region. If a model fails, pick one listed for your region.
-- ---------------------------------------------------------------------
SELECT SNOWFLAKE.CORTEX.SENTIMENT('The migration went smoothly and the team is happy.') AS sentiment;

SELECT AI_COMPLETE('mistral-large2',
  'In two sentences, explain Snowflake Time Travel to an Azure Synapse engineer.') AS answer;

-- ---------------------------------------------------------------------
-- 8. Check yourself
-- Q: A staging table is rebuilt daily and must minimize storage cost. Which table type?
-- Q: A table was dropped 10 days ago on Standard edition. Can you UNDROP it?
-- Q: Does a clone consume extra storage right after it is created?
-- ---------------------------------------------------------------------

DROP SCHEMA IF EXISTS study_db.labs_dev;
