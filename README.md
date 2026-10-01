<div align="center">

# SnowPro Core (COF-C03) in 7 Days

<img src="https://img.shields.io/badge/Snowflake-SnowPro%20Core%20COF--C03-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white" />
<img src="https://img.shields.io/badge/Cloud-AWS-232F3E?style=for-the-badge&logo=amazonwebservices&logoColor=white" />

<!-- PROGRESS:START -->
![Progress](https://img.shields.io/badge/progress-0%25-lightgrey?style=for-the-badge)

**0 / 49 tasks done**
<!-- PROGRESS:END -->

Accelerated one-week study plan, hands-on labs and progress tracking for the **SnowPro Core Certification (COF-C03)**, coming from an Azure Synapse background.

</div>

---

## The exam

| Item | Value |
|---|---|
| Exam | SnowPro Core Certification, version **COF-C03** (replaced COF-C02 in Feb 2026) |
| Format | 100 questions, 115 minutes, passing score 750/1000 * |
| Question style | Scenario-based ("the requirement changed, what do you change?") |
| Official page | [learn.snowflake.com/en/certifications/snowpro-core-c03](https://learn.snowflake.com/en/certifications/snowpro-core-c03/) |

\* Format taken from third-party prep guides. Confirm on the official page before booking.

## Domains (official exam guide)

| # | Domain | Weight | Day |
|---|---|---|---|
| 1 | AI Data Cloud Features & Architecture | 31% | 1, 2 |
| 2 | Account Management & Data Governance | 20% | 5 |
| 3 | Data Loading, Unloading & Connectivity (incl. Streams, Tasks, Dynamic Tables) | 18% | 3 |
| 4 | Performance, Querying & Transformation | 21% | 4 |
| 5 | Data Collaboration (incl. Time Travel, Fail-safe, Cloning, Sharing) | 10% | 2, 5 |

Not tested until GA: default warehouse for Notebooks, Openflow.

## 7-day plan

| Day | Date | Focus | Lab | Est. hours |
|---|---|---|---|---|
| 1 | Thu Oct 1 | Trial setup. **D1 (1.1 to 1.4)**: architecture, editions, interfaces, object hierarchy, parameters, warehouses | [01](labs/01_setup_and_warehouses.sql) | 3 |
| 2 | Fri Oct 2 | **D1 (1.5, 1.6)**: micro-partitions, table and view types, Snowpark, Cortex, Streamlit, ML. **D5.1**: Time Travel, Fail-safe, Cloning | [02](labs/02_tables_time_travel_cloning.sql) | 3 |
| 3 | Sat Oct 3 | **D3**: stages, file formats, COPY INTO and error handling, unloading, Snowpipe, directory tables, integrations, Streams, Tasks, Dynamic Tables | [03](labs/03_loading_and_pipelines.sql) | 5 |
| 4 | Sun Oct 4 | **D4**: Query Profile, caching, clustering, QAS, Search Optimization, materialized views, semi-structured, ACCOUNT_USAGE | [04](labs/04_performance_and_querying.sql) | 5 |
| 5 | Mon Oct 5 | **D2**: RBAC, DAC, roles, authentication, policies, resource monitors. **D5.2, 5.3**: sharing, Marketplace, listings, replication | [05](labs/05_governance.sql), [06](labs/06_sharing.sql) | 3 |
| 6 | Tue Oct 6 | Official practice exam + full mock. Review every error by domain | | 3 |
| 7 | Wed Oct 7 | Second mock in the morning. **Take the exam if scoring 85%+**, otherwise reschedule | | 2 + exam |

> The 85% threshold is a personal target, not a Snowflake rule. Snowflake recommends 6+ months of hands-on experience, so this plan compensates with daily labs.

## How to use this repo

1. Do the day's reading, then run the lab in a Snowflake worksheet.
2. Tick the boxes in [`PROGRESS.md`](PROGRESS.md) and log mock scores and mistakes there.
3. Run `python scripts/update_progress.py` (or push and let the GitHub Action do it) to refresh the progress badge above.
4. Review [`notes/cheatsheet.md`](notes/cheatsheet.md) every morning and [`practice/questions.md`](practice/questions.md) every night.

## Repo map

```
labs/        Hands-on SQL for each day (run in a Snowflake trial on AWS)
notes/       Cheat sheet and Synapse to Snowflake mapping
practice/    Scenario questions with answers
PROGRESS.md  Daily checklist, mock exam scores, error log
scripts/     Progress badge updater
```

## Official resources

- [Exam page and exam guide](https://learn.snowflake.com/en/certifications/snowpro-core-c03/)
- [Snowflake University](https://learn.snowflake.com/) (free courses and Hands-On Essentials badges)
- [Snowflake documentation](https://docs.snowflake.com/)
- [30-day free trial](https://signup.snowflake.com/) (choose **AWS**, Enterprise edition)
