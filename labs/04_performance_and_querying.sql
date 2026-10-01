-- =====================================================================
-- Lab 04: Query Profile, caching, clustering, semi-structured data, usage views
-- Domain 4 | Day 4
-- =====================================================================
USE ROLE SYSADMIN;
USE WAREHOUSE wh_xs;
USE SCHEMA study_db.labs;

-- ---------------------------------------------------------------------
-- 1. Result cache (cloud services layer)
-- Reused for 24h when the query text is identical and the underlying data has not changed.
-- No warehouse needed for a cache hit.
-- ---------------------------------------------------------------------
SELECT o_orderpriority, COUNT(*), AVG(o_totalprice)
FROM snowflake_sample_data.tpch_sf10.orders
GROUP BY o_orderpriority;

-- Run the exact same query again, then open Query Profile: "QUERY RESULT REUSE"
SELECT o_orderpriority, COUNT(*), AVG(o_totalprice)
FROM snowflake_sample_data.tpch_sf10.orders
GROUP BY o_orderpriority;

-- Disable it to measure real execution time
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

-- ---------------------------------------------------------------------
-- 2. Warehouse cache (local SSD): lost when the warehouse suspends
-- Run twice with result cache off, compare "Percentage scanned from cache" in Query Profile
-- ---------------------------------------------------------------------
SELECT l_returnflag, SUM(l_quantity), SUM(l_extendedprice)
FROM snowflake_sample_data.tpch_sf10.lineitem
WHERE l_shipdate BETWEEN '1995-01-01' AND '1995-03-31'
GROUP BY l_returnflag;

-- ---------------------------------------------------------------------
-- 3. Metadata cache: MIN, MAX, COUNT answered without scanning data
-- Query Profile shows "METADATA-BASED RESULT"
-- ---------------------------------------------------------------------
SELECT COUNT(*), MIN(o_orderdate), MAX(o_orderdate)
FROM snowflake_sample_data.tpch_sf10.orders;

ALTER SESSION UNSET USE_CACHED_RESULT;

-- ---------------------------------------------------------------------
-- 4. Pruning and clustering
-- Query Profile: compare "Partitions scanned" vs "Partitions total"
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE lineitem_copy AS
SELECT * FROM snowflake_sample_data.tpch_sf1.lineitem;

SELECT SYSTEM$CLUSTERING_INFORMATION('lineitem_copy', '(l_shipdate)');

-- Clustering key: useful on very large tables with selective filters on that column
-- Automatic Clustering consumes serverless credits
ALTER TABLE lineitem_copy CLUSTER BY (l_shipdate);
SHOW TABLES LIKE 'LINEITEM_COPY';   -- cluster_by and automatic_clustering columns
ALTER TABLE lineitem_copy SUSPEND RECLUSTER;   -- avoid spending credits in the lab

-- ---------------------------------------------------------------------
-- 5. Spilling: when a warehouse is too small, data spills to local then remote disk
-- Look for "Bytes spilled to local/remote storage" in Query Profile. Fix: bigger warehouse.
-- ---------------------------------------------------------------------
SELECT l_orderkey, l_partkey, l_extendedprice,
       RANK() OVER (PARTITION BY l_partkey ORDER BY l_extendedprice DESC) AS rnk
FROM lineitem_copy
QUALIFY rnk = 1
LIMIT 100;
SET heavy_qid = LAST_QUERY_ID();

-- ---------------------------------------------------------------------
-- 6. Semi-structured data: VARIANT, dot and bracket notation, FLATTEN
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE events_json (payload VARIANT);

INSERT INTO events_json
SELECT PARSE_JSON(column1) FROM VALUES
  ('{"user": {"id": 1, "country": "BR"}, "items": [{"sku": "A", "qty": 2}, {"sku": "B", "qty": 1}]}'),
  ('{"user": {"id": 2, "country": "US"}, "items": [{"sku": "C", "qty": 5}]}');

SELECT payload:user.id::INT          AS user_id,
       payload:user:country::STRING  AS country,
       f.value:sku::STRING           AS sku,
       f.value:qty::INT              AS qty
FROM events_json,
     LATERAL FLATTEN(INPUT => payload:items) f;

SELECT TYPEOF(payload:items), ARRAY_SIZE(payload:items) FROM events_json;

-- ---------------------------------------------------------------------
-- 7. Search Optimization Service (Enterprise+): point lookups on large tables
-- Query Acceleration Service: offloads parts of large scans to serverless compute
-- ---------------------------------------------------------------------
-- ALTER TABLE lineitem_copy ADD SEARCH OPTIMIZATION ON EQUALITY(l_orderkey);
ALTER WAREHOUSE wh_xs SET ENABLE_QUERY_ACCELERATION = TRUE QUERY_ACCELERATION_MAX_SCALE_FACTOR = 2;
SELECT SYSTEM$ESTIMATE_QUERY_ACCELERATION($heavy_qid);   -- is the window query eligible for QAS?
ALTER WAREHOUSE wh_xs SET ENABLE_QUERY_ACCELERATION = FALSE;

-- ---------------------------------------------------------------------
-- 8. Monitoring views
--   INFORMATION_SCHEMA : per database, real time, short retention (7 days to 6 months by view)
--   SNOWFLAKE.ACCOUNT_USAGE : whole account, latency up to ~3h, 1 year retention, includes dropped objects
-- ---------------------------------------------------------------------
SELECT query_id, query_text, warehouse_name, total_elapsed_time / 1000 AS seconds,
       bytes_spilled_to_local_storage, partitions_scanned, partitions_total
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(RESULT_LIMIT => 20))
ORDER BY start_time DESC;

USE ROLE ACCOUNTADMIN;
SELECT warehouse_name, SUM(credits_used) AS credits
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY credits DESC;
USE ROLE SYSADMIN;

-- ---------------------------------------------------------------------
-- 9. Check yourself
-- Q: A query is fast the second time even after the table got new rows. Which cache could still help, and which one cannot?
-- Q: Query Profile shows heavy remote spilling. What is the first fix?
-- Q: Many users run the same point lookup on a 5 TB table by ID. Clustering or Search Optimization?
-- ---------------------------------------------------------------------
