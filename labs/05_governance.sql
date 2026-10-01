-- =====================================================================
-- Lab 05: RBAC, policies, resource monitors
-- Domain 2 | Day 5
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. System role hierarchy
--   ORGADMIN : organization level (accounts across the org)
--   ACCOUNTADMIN = SYSADMIN + SECURITYADMIN (top of the account, use sparingly, enable MFA)
--   SECURITYADMIN : manages grants (MANAGE GRANTS), inherits USERADMIN
--   USERADMIN : creates users and roles
--   SYSADMIN : creates warehouses and databases. Custom roles should roll up to it
--   PUBLIC : granted to every user automatically
-- ---------------------------------------------------------------------
USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS analyst_role;
CREATE ROLE IF NOT EXISTS engineer_role;

-- Role hierarchy: grant custom roles up to SYSADMIN so admins keep visibility
GRANT ROLE analyst_role  TO ROLE engineer_role;
GRANT ROLE engineer_role TO ROLE SYSADMIN;

CREATE USER IF NOT EXISTS lab_analyst
  PASSWORD = 'ChangeMe_Lab_2026!'
  DEFAULT_ROLE = analyst_role
  DEFAULT_WAREHOUSE = wh_xs
  MUST_CHANGE_PASSWORD = TRUE;

GRANT ROLE analyst_role TO USER lab_analyst;

-- Also grant it to yourself so you can USE ROLE analyst_role in this lab
SET my_user = CURRENT_USER();
GRANT ROLE analyst_role TO USER IDENTIFIER($my_user);

-- ---------------------------------------------------------------------
-- 2. Privileges: object owner (DAC) or a role with MANAGE GRANTS can grant
-- ---------------------------------------------------------------------
USE ROLE SYSADMIN;
GRANT USAGE ON WAREHOUSE wh_xs TO ROLE analyst_role;
GRANT USAGE ON DATABASE study_db TO ROLE analyst_role;
GRANT USAGE ON SCHEMA study_db.labs TO ROLE analyst_role;
GRANT SELECT ON ALL TABLES IN SCHEMA study_db.labs TO ROLE analyst_role;

-- Future grants: apply automatically to objects created later
USE ROLE SECURITYADMIN;
GRANT SELECT ON FUTURE TABLES IN SCHEMA study_db.labs TO ROLE analyst_role;

SHOW GRANTS TO ROLE analyst_role;
SHOW GRANTS OF ROLE analyst_role;   -- who has the role

-- Database roles: scoped to one database, can be shared with consumers
USE ROLE SYSADMIN;
CREATE DATABASE ROLE IF NOT EXISTS study_db.reader;
GRANT USAGE ON SCHEMA study_db.labs TO DATABASE ROLE study_db.reader;
GRANT SELECT ON ALL TABLES IN SCHEMA study_db.labs TO DATABASE ROLE study_db.reader;

-- Secondary roles: a session can use privileges of all granted roles at once
-- USE SECONDARY ROLES ALL;

-- ---------------------------------------------------------------------
-- 3. Column-level security: masking policy (Enterprise+)
-- ---------------------------------------------------------------------
USE ROLE SYSADMIN;
USE WAREHOUSE wh_xs;
USE SCHEMA study_db.labs;

CREATE OR REPLACE MASKING POLICY mp_balance AS (val NUMBER(12, 2)) RETURNS NUMBER(12, 2) ->
  CASE WHEN IS_ROLE_IN_SESSION('ENGINEER_ROLE') THEN val ELSE NULL END;

ALTER TABLE customers_raw MODIFY COLUMN acctbal SET MASKING POLICY mp_balance;

SELECT custkey, acctbal FROM customers_raw LIMIT 5;      -- SYSADMIN inherits ENGINEER_ROLE: values visible
USE ROLE analyst_role;
SELECT custkey, acctbal FROM study_db.labs.customers_raw LIMIT 5;   -- NULL for analysts
USE ROLE SYSADMIN;

-- ---------------------------------------------------------------------
-- 4. Row-level security: row access policy (Enterprise+)
-- ---------------------------------------------------------------------
CREATE OR REPLACE ROW ACCESS POLICY rap_segment AS (segment STRING) RETURNS BOOLEAN ->
  IS_ROLE_IN_SESSION('ENGINEER_ROLE') OR segment = 'BUILDING';

ALTER TABLE customers_raw ADD ROW ACCESS POLICY rap_segment ON (mktsegment);

USE ROLE analyst_role;
SELECT mktsegment, COUNT(*) FROM study_db.labs.customers_raw GROUP BY 1;   -- only BUILDING
USE ROLE SYSADMIN;

-- ---------------------------------------------------------------------
-- 5. Object tagging (Enterprise+)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TAG pii_level ALLOWED_VALUES 'low', 'high';
ALTER TABLE customers_raw MODIFY COLUMN name SET TAG pii_level = 'high';
SELECT SYSTEM$GET_TAG('pii_level', 'customers_raw.name', 'COLUMN');

-- ---------------------------------------------------------------------
-- 6. Resource monitors: credit quotas for warehouses (ACCOUNTADMIN only)
-- They do NOT cover serverless features (Snowpipe, auto-clustering, etc.)
-- ---------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE RESOURCE MONITOR rm_lab
  WITH CREDIT_QUOTA = 10
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 75 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND               -- lets running queries finish
    ON 110 PERCENT DO SUSPEND_IMMEDIATE;    -- cancels running queries

ALTER WAREHOUSE wh_xs SET RESOURCE_MONITOR = rm_lab;
SHOW RESOURCE MONITORS;

-- ---------------------------------------------------------------------
-- 7. Network policy (example only, do not activate on your own user without your IP)
-- ---------------------------------------------------------------------
-- CREATE NETWORK POLICY np_office ALLOWED_IP_LIST = ('203.0.113.0/24');
-- ALTER USER lab_analyst SET NETWORK_POLICY = np_office;   -- user-level overrides account-level

-- ---------------------------------------------------------------------
-- 8. Check yourself
-- Q: Which role should create custom roles, and which role should they roll up to?
-- Q: Analysts must see emails masked, but the data team must see them in full. Which feature?
-- Q: A resource monitor reached 100% but Snowpipe keeps consuming credits. Why?
-- ---------------------------------------------------------------------
