# Azure Synapse to Snowflake (on AWS)

| Concept | Azure Synapse / Azure | Snowflake on AWS |
|---|---|---|
| Compute | Dedicated SQL pool (DWU) | Virtual warehouse (T-shirt sizes, credits) |
| Pause to save cost | Pause the pool manually | Auto-suspend / auto-resume |
| Concurrency | Workload management, resource classes | Multi-cluster warehouses |
| Table distribution | `DISTRIBUTION = HASH/ROUND_ROBIN/REPLICATE` | None. Automatic micro-partitions |
| Indexes | Clustered columnstore index | None. Optional clustering key |
| Storage | ADLS Gen2 | S3 (managed by Snowflake for internal tables) |
| External data | External tables / OPENROWSET | External stages, external tables, Iceberg tables |
| Bulk load | `COPY INTO` / PolyBase | `COPY INTO` from a stage |
| Credentials to storage | Managed identity / service principal | Storage integration with an IAM role |
| Event-driven ingestion | Event Grid + pipelines | Snowpipe auto-ingest (S3 event → SQS) |
| Orchestration | Synapse / ADF pipelines | Tasks, Streams, Dynamic Tables (or Airflow/MWAA) |
| Procedures | T-SQL | Snowflake Scripting, JavaScript, Python, Java, Scala |
| Secrets | Key Vault | Secrets objects / AWS Secrets Manager |
| Private network | Azure Private Link | AWS PrivateLink (Business Critical) |
| Point-in-time restore | Restore points | Time Travel + Fail-safe |
| Dev copies | Copy or restore | Zero-copy clone |

## Migration watch-outs

- Remove `DISTRIBUTION`, `CLUSTERED COLUMNSTORE INDEX` and partition clauses from DDL.
- Rewrite T-SQL procedures. Check the current coverage of Snowflake's SnowConvert tool before relying on it (not verified here).
- Review data types: `DATETIME2`, `NVARCHAR(MAX)`, `UNIQUEIDENTIFIER`, collation differences.
