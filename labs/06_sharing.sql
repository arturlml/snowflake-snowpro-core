-- =====================================================================
-- Lab 06: Secure Data Sharing, reader accounts, replication
-- Domain 5 (5.2, 5.3) | Day 5
-- =====================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE wh_xs;

-- ---------------------------------------------------------------------
-- 1. Key facts
--   * Sharing copies NO data: consumers query the provider's storage
--   * Consumer pays for compute, provider pays for storage
--   * Shared objects are read-only for the consumer
--   * Only secure views (not standard views) can be shared
--   * Direct shares work within the same region and cloud. Cross-region needs
--     replication or listings with Cross-Cloud Auto-Fulfillment
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- 2. Create a share
-- ---------------------------------------------------------------------
CREATE OR REPLACE SECURE VIEW study_db.labs.sv_segment_summary AS
SELECT c_mktsegment AS segment, COUNT(*) AS customers
FROM snowflake_sample_data.tpch_sf1.customer
GROUP BY c_mktsegment;

CREATE OR REPLACE TABLE study_db.labs.segment_summary AS
SELECT * FROM study_db.labs.sv_segment_summary;

CREATE OR REPLACE SHARE sh_study;
GRANT USAGE ON DATABASE study_db TO SHARE sh_study;
GRANT USAGE ON SCHEMA study_db.labs TO SHARE sh_study;
GRANT SELECT ON TABLE study_db.labs.segment_summary TO SHARE sh_study;

SHOW SHARES;
SHOW GRANTS TO SHARE sh_study;

-- To share with another account in the same region:
-- ALTER SHARE sh_study ADD ACCOUNTS = <org_name>.<account_name>;

-- ---------------------------------------------------------------------
-- 3. Reader account: for consumers without a Snowflake account
-- The PROVIDER pays for the reader account's compute. Read-only.
-- ---------------------------------------------------------------------
-- CREATE MANAGED ACCOUNT reader_demo
--   ADMIN_NAME = 'reader_admin', ADMIN_PASSWORD = '<strong_password>', TYPE = READER;
-- SHOW MANAGED ACCOUNTS;

-- ---------------------------------------------------------------------
-- 4. Consumer side (run in the consumer account)
-- ---------------------------------------------------------------------
-- SHOW SHARES;   -- kind = INBOUND
-- CREATE DATABASE shared_study FROM SHARE <provider_org>.<provider_account>.sh_study;

-- ---------------------------------------------------------------------
-- 5. Inbound share you already have: the Marketplace sample data
-- ---------------------------------------------------------------------
SHOW SHARES LIKE '%SAMPLE%';

-- ---------------------------------------------------------------------
-- 6. Replication (Business Critical for failover; database replication available in all editions)
-- ---------------------------------------------------------------------
-- ALTER DATABASE study_db ENABLE REPLICATION TO ACCOUNTS <org>.<secondary_account>;
-- In the secondary: CREATE DATABASE study_db AS REPLICA OF <org>.<primary_account>.study_db;
--                   ALTER DATABASE study_db REFRESH;

-- ---------------------------------------------------------------------
-- 7. Check yourself
-- Q: A partner without a Snowflake account needs read access to your data. What do you create and who pays compute?
-- Q: Can a consumer insert rows into a shared table?
-- Q: You need to share data with an account in another region. Is a direct share enough?
-- ---------------------------------------------------------------------

-- Cleanup
DROP SHARE IF EXISTS sh_study;
