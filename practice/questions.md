# Practice Questions

Scenario questions written for this repo (not official exam questions). Answer first, then open the solution. Log every miss in the error log in [`PROGRESS.md`](../PROGRESS.md).

## Domain 1: Architecture

**1.** A BI dashboard with 60 concurrent users shows queries waiting in queue, but each query is simple. What do you change?

<details><summary>Answer</summary>Make the warehouse multi-cluster (scale out). Queuing is a concurrency problem; a bigger size helps complex queries, not concurrency. Requires Enterprise edition.</details>

**2.** Which layer performs authentication, query optimization and stores the result cache?

<details><summary>Answer</summary>Cloud services layer.</details>

**3.** A warehouse runs a 10-second query after being suspended. How long is billed?

<details><summary>Answer</summary>60 seconds. Per-second billing with a 60-second minimum each time the warehouse resumes.</details>

**4.** An ML team runs Python UDFs that fail with out-of-memory errors on a standard warehouse. What warehouse type fits?

<details><summary>Answer</summary>Snowpark-optimized warehouse (more memory per node).</details>

**5.** A session sets `STATEMENT_TIMEOUT_IN_SECONDS = 300`, the user has 600 and the account has 1800. Which value applies to that session's queries?

<details><summary>Answer</summary>300. The most specific level (session) wins. Note that a warehouse-level timeout also applies, and the lower of session and warehouse is enforced.</details>

## Domain 5.1: Data protection

**6.** A staging table is fully rebuilt every night and storage cost must be minimal. Which table type?

<details><summary>Answer</summary>Transient. No Fail-safe, so no 7 days of extra storage.</details>

**7.** On Standard edition, a permanent table was dropped 3 days ago. Can you `UNDROP` it?

<details><summary>Answer</summary>No. Standard allows at most 1 day of Time Travel. The data is in Fail-safe, recoverable only by Snowflake Support.</details>

**8.** You clone a 2 TB database for a test environment. How much extra storage is consumed right after the clone?

<details><summary>Answer</summary>Essentially none. Zero-copy cloning shares micro-partitions until data in the clone or source changes.</details>

## Domain 3: Loading

**9.** Files arrive in S3 every few minutes and must be loaded automatically with no warehouse to manage. What do you use?

<details><summary>Answer</summary>Snowpipe with auto-ingest (S3 event notifications to the pipe's SQS queue). It is serverless.</details>

**10.** You re-run `COPY INTO` on the same files and 0 rows load. Why?

<details><summary>Answer</summary>Load metadata (kept 64 days) marks those files as already loaded. Use `FORCE = TRUE` to reload, accepting duplicates.</details>

**11.** You want to check a new file for errors without loading any rows. Which option?

<details><summary>Answer</summary>`VALIDATION_MODE = RETURN_ERRORS` (or `RETURN_n_ROWS`).</details>

**12.** IoT devices send individual rows that must be queryable within seconds, without writing files. What fits best?

<details><summary>Answer</summary>Snowpipe Streaming (row-based ingestion, no files).</details>

**13.** A pipeline needs an aggregated table that is never more than 10 minutes stale, defined only by a SELECT. What do you use?

<details><summary>Answer</summary>A Dynamic Table with `TARGET_LAG = '10 minutes'`.</details>

**14.** A task should run only when its source stream has new changes. How?

<details><summary>Answer</summary>Add `WHEN SYSTEM$STREAM_HAS_DATA('<stream>')` to the task. The task is skipped (no compute) when there is no data.</details>

## Domain 4: Performance

**15.** The same query runs in milliseconds the second time and Query Profile shows no warehouse usage. Why?

<details><summary>Answer</summary>Result cache hit (cloud services layer). Valid when the query text is identical and the underlying data has not changed.</details>

**16.** Query Profile shows large "Bytes spilled to remote storage". First fix?

<details><summary>Answer</summary>Use a larger warehouse (more memory and local disk). Reducing the data processed also helps.</details>

**17.** A 5 TB table is filtered by `event_date` in almost every query, and Query Profile shows nearly all partitions scanned. What helps?

<details><summary>Answer</summary>Define a clustering key on `event_date` to improve pruning.</details>

**18.** Many users look up single rows by `customer_id` in a huge table. Clustering or Search Optimization?

<details><summary>Answer</summary>Search Optimization Service, built for selective point lookups (Enterprise+).</details>

**19.** You need query history for a table that was dropped 2 months ago. Where do you look?

<details><summary>Answer</summary>`SNOWFLAKE.ACCOUNT_USAGE` (1 year retention, includes dropped objects). `INFORMATION_SCHEMA` does not include dropped objects.</details>

**20.** How do you extract each element of a JSON array stored in a VARIANT column into rows?

<details><summary>Answer</summary>`LATERAL FLATTEN(INPUT => col:array_path)` and read `value` from the output.</details>

## Domain 2: Governance

**21.** Which role should create custom roles, and where should custom roles roll up?

<details><summary>Answer</summary>USERADMIN (or SECURITYADMIN) creates them; they should be granted to SYSADMIN.</details>

**22.** Analysts must see emails masked while the data team sees them in full, using the same table. Which feature?

<details><summary>Answer</summary>A masking policy on the column with a condition on the role (e.g. `IS_ROLE_IN_SESSION`). Enterprise+.</details>

**23.** Users in each region may only see their own region's rows. Which feature?

<details><summary>Answer</summary>A row access policy.</details>

**24.** A resource monitor hit 100% with action SUSPEND, but a running query kept going. Why?

<details><summary>Answer</summary>SUSPEND lets running queries finish. SUSPEND_IMMEDIATE cancels them.</details>

**25.** An account network policy allows the office IP, but one user has a user-level policy allowing only a VPN IP. Which applies to that user?

<details><summary>Answer</summary>The user-level policy. It overrides the account-level one.</details>

## Domain 5: Collaboration

**26.** A partner without a Snowflake account needs read access to your data. What do you create, and who pays for compute?

<details><summary>Answer</summary>A reader account (managed account). The provider pays its compute.</details>

**27.** You want to share a view that hides the underlying table logic. What kind of view is required?

<details><summary>Answer</summary>A secure view. Standard views cannot be shared.</details>

**28.** Can a consumer update a table received through a share?

<details><summary>Answer</summary>No. Shared objects are read-only. The consumer can copy data into its own tables.</details>

**29.** The consumer account is in a different region from the provider. Is a direct share enough?

<details><summary>Answer</summary>No. Direct shares work within the same region and cloud. Use replication or a listing with Cross-Cloud Auto-Fulfillment.</details>

**30.** In a data share, who pays for storage and who pays for compute?

<details><summary>Answer</summary>Provider pays storage, consumer pays compute (except reader accounts, where the provider pays compute too).</details>
