# SnowPro Core Cheat Sheet

Read every morning. Facts are from the Snowflake documentation; confirm anything that looks off against [docs.snowflake.com](https://docs.snowflake.com/).

## Architecture (D1)

| Layer | What it does |
|---|---|
| Database storage | Compressed, columnar micro-partitions (50 to 500 MB uncompressed) in cloud object storage. Immutable |
| Query processing | Virtual warehouses (independent compute clusters) |
| Cloud services | Authentication, metadata, query parsing and optimization, access control, result cache |

- Hybrid of shared-disk (central storage) and shared-nothing (MPP compute).
- Cloud services credits are billed only above 10% of daily warehouse usage.

## Editions

| Edition | Adds |
|---|---|
| Standard | Core features, Time Travel up to 1 day |
| Enterprise | Multi-cluster warehouses, Time Travel up to 90 days, materialized views, masking and row access policies, search optimization, clustering |
| Business Critical | Tri-Secret Secure, PrivateLink, failover/failback, HIPAA/PCI support |
| Virtual Private Snowflake (VPS) | Fully isolated environment |

## Warehouses

- Sizes: XS = 1 credit/h, then doubles each size (S 2, M 4, L 8, XL 16 ...).
- Per-second billing, **60-second minimum** on each resume.
- **Scale up** (bigger size) = complex queries, spilling. **Scale out** (multi-cluster) = concurrency, queuing.
- Multi-cluster modes: **maximized** (MIN = MAX) and **auto-scale** (MIN < MAX). Scaling policy STANDARD (start clusters fast) or ECONOMY (save credits).
- Gen2 is the default for new standard warehouses where available. Snowpark-optimized = more memory per node for ML/large UDFs.

## Data protection (D5.1)

| Table type | Time Travel | Fail-safe |
|---|---|---|
| Permanent | 0 to 1 day (Standard), 0 to 90 days (Enterprise+) | 7 days |
| Transient | 0 or 1 day | None |
| Temporary | 0 or 1 day, dropped at session end | None |

- Fail-safe is **not user accessible**, recovery only via Snowflake Support.
- `AT` / `BEFORE` with `TIMESTAMP`, `OFFSET` (seconds) or `STATEMENT` (query ID).
- `UNDROP` works for tables, schemas and databases within Time Travel.
- **Zero-copy clone**: metadata only, no extra storage until data diverges. Internal named stages are cloned only with `INCLUDE INTERNAL STAGES`, and pipes that reference internal stages are not cloned.

## Loading (D3)

- Stages: user `@~`, table `@%t`, named internal `@s`, external (S3, Azure, GCS).
- Load metadata is kept **64 days**: COPY skips already loaded files. `FORCE = TRUE` reloads.
- `ON_ERROR`: `ABORT_STATEMENT` (default for COPY), `CONTINUE`, `SKIP_FILE`. Snowpipe default is `SKIP_FILE`.
- `VALIDATION_MODE = RETURN_ERRORS` validates without loading.
- Recommended file size: roughly 100 to 250 MB compressed.
- **Snowpipe**: serverless, file-based, auto-ingest via cloud events (S3 → SQS). **Snowpipe Streaming**: row-based, low latency via SDK/Kafka connector, no files.
- **Streams** = CDC offset on a table. **Tasks** = scheduled SQL (warehouse or serverless), DAGs of tasks. **Dynamic Tables** = declarative pipeline with `TARGET_LAG`.

## Performance (D4)

| Cache | Where | Notes |
|---|---|---|
| Result cache | Cloud services | 24h, reset on each reuse up to 31 days. Needs identical query and unchanged data. No warehouse needed |
| Warehouse (local disk) cache | Warehouse SSD | Lost when the warehouse suspends |
| Metadata cache | Cloud services | COUNT, MIN, MAX without scanning |

- Query Profile warning signs: **spilling** (local then remote) → bigger warehouse; **poor pruning** → clustering/filters; **exploding joins** → fix join condition; **queuing** → multi-cluster.
- **Clustering keys**: for very large tables with selective filters. Automatic Clustering uses serverless credits.
- **Search Optimization Service**: selective point lookups. **Query Acceleration Service**: offloads parts of large scans/outlier queries.
- Materialized views: single table only, maintained automatically, Enterprise+.
- `ACCOUNT_USAGE`: 1 year retention, latency up to hours, includes dropped objects. `INFORMATION_SCHEMA`: real time, shorter retention, no dropped objects.

## Governance (D2)

- Model = **RBAC** (privileges to roles, roles to users) + **DAC** (owner controls the object).
- ACCOUNTADMIN > SECURITYADMIN > USERADMIN, and ACCOUNTADMIN > SYSADMIN. PUBLIC goes to everyone.
- Custom roles should roll up to SYSADMIN.
- Resource monitors: warehouses only, created by ACCOUNTADMIN, actions NOTIFY / SUSPEND / SUSPEND_IMMEDIATE.
- Network policy at user level overrides account level.
- Masking (column), row access (row), tag-based masking, all Enterprise+.

## Collaboration (D5)

- Shares copy no data. Provider pays storage, consumer pays compute. Read-only for consumers.
- Only **secure** views can be shared.
- **Reader account**: for consumers without Snowflake. Provider pays its compute.
- Cross-region or cross-cloud sharing needs replication or listings with auto-fulfillment.
