-- =====================================================================
-- Lab 01: Setup, object hierarchy, parameters and warehouses
-- Domain 1 (1.1 to 1.4) | Day 1
-- Run in a Snowsight worksheet on a trial account (AWS)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Context: who am I, where am I
-- ---------------------------------------------------------------------
SELECT CURRENT_ACCOUNT(), CURRENT_REGION(), CURRENT_ROLE(), CURRENT_USER(), CURRENT_VERSION();

-- SYSADMIN owns databases and warehouses by convention, ACCOUNTADMIN is for account-level admin only
USE ROLE SYSADMIN;

-- ---------------------------------------------------------------------
-- 2. Object hierarchy: account > database > schema > objects
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS study_db COMMENT = 'SnowPro Core study';
CREATE SCHEMA IF NOT EXISTS study_db.labs;
USE SCHEMA study_db.labs;

SHOW DATABASES LIKE 'STUDY_DB';
SHOW SCHEMAS IN DATABASE study_db;   -- note INFORMATION_SCHEMA and PUBLIC are created automatically

-- ---------------------------------------------------------------------
-- 3. Warehouses
-- Credits per hour double with each size (XS = 1, S = 2, M = 4, L = 8 ...)
-- Billing is per second with a 60-second minimum each time it resumes
-- ---------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS wh_xs
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60          -- seconds of inactivity before suspending
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Lab warehouse';

-- Gen2 standard warehouse (default for new standard warehouses where available)
CREATE WAREHOUSE IF NOT EXISTS wh_gen2
  WAREHOUSE_SIZE = 'XSMALL'
  GENERATION = '2'
  AUTO_SUSPEND = 60
  INITIALLY_SUSPENDED = TRUE;

SHOW WAREHOUSES;   -- compare the "generation" and "type" columns

-- Multi-cluster warehouse (Enterprise edition or higher)
-- Scaling policy STANDARD favors starting clusters, ECONOMY favors saving credits
CREATE WAREHOUSE IF NOT EXISTS wh_multi
  WAREHOUSE_SIZE = 'XSMALL'
  MIN_CLUSTER_COUNT = 1
  MAX_CLUSTER_COUNT = 3       -- MIN < MAX = auto-scale mode, MIN = MAX = maximized mode
  SCALING_POLICY = 'ECONOMY'
  AUTO_SUSPEND = 60
  INITIALLY_SUSPENDED = TRUE;

-- Resize: scale UP for complex queries, scale OUT (multi-cluster) for concurrency
ALTER WAREHOUSE wh_xs SET WAREHOUSE_SIZE = 'SMALL';
ALTER WAREHOUSE wh_xs SET WAREHOUSE_SIZE = 'XSMALL';

USE WAREHOUSE wh_xs;

-- ---------------------------------------------------------------------
-- 4. Sample data and a first query
-- If SNOWFLAKE_SAMPLE_DATA is missing, add it from Data Products > Marketplace
-- ---------------------------------------------------------------------
SELECT c_mktsegment, COUNT(*) AS customers
FROM snowflake_sample_data.tpch_sf1.customer
GROUP BY c_mktsegment
ORDER BY customers DESC;

-- ---------------------------------------------------------------------
-- 5. Parameters and precedence
-- Most specific level wins: session overrides user, user overrides account
-- ---------------------------------------------------------------------
SHOW PARAMETERS LIKE 'STATEMENT_TIMEOUT_IN_SECONDS' IN ACCOUNT;
SHOW PARAMETERS LIKE 'STATEMENT_TIMEOUT_IN_SECONDS' IN SESSION;

ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = 600;
SHOW PARAMETERS LIKE 'STATEMENT_TIMEOUT_IN_SECONDS' IN SESSION;   -- level column = SESSION
ALTER SESSION UNSET STATEMENT_TIMEOUT_IN_SECONDS;

-- Object-level parameter: warehouse timeout
ALTER WAREHOUSE wh_xs SET STATEMENT_TIMEOUT_IN_SECONDS = 1800;
SHOW PARAMETERS IN WAREHOUSE wh_xs;

-- ---------------------------------------------------------------------
-- 6. Check yourself
-- Q: A dashboard has 50 concurrent users and queries are queuing. Bigger size or more clusters?
-- Q: Which layer handles authentication, metadata and query optimization?
-- Q: Which edition is the minimum for multi-cluster warehouses?
-- ---------------------------------------------------------------------

-- Cleanup to save credits (keep the database for later labs)
ALTER WAREHOUSE wh_gen2 SUSPEND;
DROP WAREHOUSE IF EXISTS wh_multi;
