# 🐘 Database Query Optimization: Oracle & PostgreSQL

Hands-on experiments with how Oracle and PostgreSQL execute queries and how to influence them. Both databases run in Docker on the same 100,000-row `EMPLOYEES` / `CITIES` data set; on top of it I compared hierarchical queries in both dialects, went through every common scan node in PostgreSQL `EXPLAIN`, watched MVCC and `VACUUM` at work, steered the planner with settings and `pg_hint_plan`, and compared views, materialized views, CTEs and functions. It ends with a generic audit trigger.

🎓 *Optimization and Load Balancing in Databases*, Igor Sikorsky Kyiv Polytechnic Institute (KPI), 4th year, spring semester 2026.

## 🧩 What's inside

**Environment and data** (`setup/`). Oracle Database 21c XE and PostgreSQL in Docker Compose. The schema and generator procedures come from the course starter scripts: `EMPLOYEES` (with PK, unique e-mail, self-referencing `MANAGER_ID` and check constraints), `CITIES`, procedures that insert 100,000 random cities and employees, and `update_managers(n, s)`, which builds a manager tree where every manager has up to 8 subordinates. The Oracle city generator indexed a `VARRAY` with the fractional value of `DBMS_RANDOM.VALUE()`; it now picks the element with `TRUNC(DBMS_RANDOM.VALUE(1, COUNT + 1))`, which gives a valid and uniform index. The PostgreSQL container uses `postgresai/extended-postgres:16`, which ships `pg_hint_plan`.

**Hierarchical queries.** The same manager → subordinates tree written twice: Oracle `START WITH … CONNECT BY NOCYCLE PRIOR`, and PostgreSQL `WITH RECURSIVE` with an anchor row and a recursive join on `manager_id`.

**Execution plans.** One query per scan type, each built so the planner has to pick that node: Seq Scan, Index Scan, Index Only Scan (covering index on `salary, first_name, last_name`), Bitmap Index Scan + `BitmapAnd` + Bitmap Heap Scan (two single-column indexes), TID Scan (`ctid = '(0,1)'`), Subquery Scan (a `ROW_NUMBER()` window keeps the subquery from being inlined), Function Scan (a `RETURNS TABLE` function), Values Scan, CTE Scan (`AS MATERIALIZED`) and WorkTable Scan (recursive CTE). The plan I got is kept as a comment under each query.

**VACUUM and MVCC.** A copy of `EMPLOYEES` gets mass updates while `pg_stat_all_tables` shows dead tuples appearing and autovacuum removing them; with autovacuum switched off the same query is measured before and after `VACUUM` / `VACUUM ANALYZE`, and `VACUUM FULL` shows how much space a rewrite gives back.

**Planner settings and hints.** `enable_seqscan`, `random_page_cost` / `seq_page_cost`, then `pg_hint_plan`: `IndexScan`, `HashJoin` / `NestLoop`, `Leading`, `Rows`, an `IndexOnlyScan` hint that cannot be honoured, index usage from `pg_stat_user_indexes`, an `OR` → `UNION ALL` rewrite and a `work_mem` test that forces sorts and hashes to spill to disk.

**Views and materialized views.** Stored generated columns (`email_domain`, `full_name`), recursive views up and down the management chain, their materialized versions, and one aggregate (employees, average and max salary per city) implemented four ways: view, materialized view with an index, CTE and a `RETURNS TABLE` function.

**Audit trigger.** One trigger function serves any table: the tracked column name comes in as `TG_ARGV[0]`, old and new values are read with `to_jsonb(OLD)->>col_name`, and a row goes to `change_history (table_name, column_name, row_id, old_value, new_value, changed_at)` only when the value really changed. It is attached to `employees.phone_number` and `cities.name`.

## 📊 Results

Data generation (100k cities + 100k employees / manager links):

| | Oracle 21c XE | PostgreSQL |
|---|---|---|
| generate cities and employees | 5.5 s | 1.46 s |
| `update_managers(100000, 8)` | 0.97 s | 1.15 s |

Scan types on 100k employees (estimated cost):

| Query | Plan | Cost |
|---|---|---|
| `salary > 1000`, no index | Seq Scan | 0.00..3807.00 |
| `id = 1` | Index Scan on the PK | 0.42..2.64 |
| `salary = 5000`, covering index | Index Only Scan | 0.42..1.57 |
| `salary < 2000 AND department_id = 10` | 2 × Bitmap Index Scan → BitmapAnd → Bitmap Heap Scan | 34.51..63.24 |
| `ctid = '(0,1)'` | Tid Scan | 0.00..1.11 |
| `MATERIALIZED` CTE, `salary > 2000` | CTE Scan over Seq Scan | 3807.00..5754.58 |

VACUUM on the 100k-row copy:

- one `UPDATE` of all rows → **100,000 dead tuples**; a few minutes later autovacuum had brought it back to **0**
- `EXPLAIN ANALYZE … WHERE salary > 5000` with dead tuples: **10.54 ms**; after `VACUUM` + `VACUUM ANALYZE`: **7.44 ms**
- table size after several full-table updates: **20 MB** → **9,992 kB** after `VACUUM FULL`
- after an `UPDATE` of 978 rows and a `DELETE` of 77,663 rows, autovacuum and autoanalyze processed the table on their own about 80 seconds later

Planner settings and hints (`salary > 10000`, ~77% of the rows):

| Change | Plan | Cost |
|---|---|---|
| default | Seq Scan | 0.00..3807.00 |
| `enable_seqscan = off` | Bitmap Heap Scan | 759.24..4279.54 |
| `random_page_cost = 1`, `seq_page_cost = 10` | Index Scan | 0.29..4053.02 |
| `/*+ IndexScan(employees idx_employees_salary) */` | Index Scan | 0.29..4313.36 |

- **Join method**: `employees ⋈ cities` defaulted to Nested Loop + Memoize over `cities_pk` (cost 5742.20); `HashJoin(e c)` produced a hash join costed at 9782.99, `NestLoop(e c)` reproduced the default.
- **OR → UNION ALL**: `salary > 90000 OR first_name = 'Daniel'` ran as one Seq Scan in **6.22 ms**; as `UNION ALL` the salary branch uses the index and the query took **5.22 ms**.
- **Leading((c e))** returned the same Hash Join as the default plan (8.44 vs 8.18 ms): the planner already builds the hash on the filtered `cities` side.
- **Rows(e gs #100)** on a join with `generate_series(1, 1000)` replaced the Nested Loop over the PK (1.19 ms) with a Hash Join over the whole table (~10 ms), a good illustration of how much the plan depends on row estimates.
- **IndexOnlyScan** on a salary-only index with `SELECT *` falls back to a regular Index Scan.
- **pg_stat_user_indexes** after the experiments: the PK had 199,997 scans, the salary index 2, `emp_email_uk` and the `city_id` index none.
- **work_mem = 64kB**: `ORDER BY last_name` switched to an external merge sort (8,448 kB on disk, 44.5 ms), and the employees–cities hash join split into 128 batches (97 kB in memory, 43.3 ms).

Views vs materialized views:

- recursive view `employee_hierarchy_up` (667,895 rows): **334.7 ms**, 60 ms of it JIT compilation; the same data from the materialized view: **81.0 ms**, a single Seq Scan
- a newly inserted employee shows up in the view immediately and in the materialized view after `REFRESH MATERIALIZED VIEW` (635 ms)
- the indexed `city_salary_stats_mat` answers a lookup by city name with an Index Scan costed at 0.42..2.64

## 🖥️ Running it

PostgreSQL (Docker, port 6432):

```bash
git clone https://github.com/pgerasymchuk/database-query-optimization.git
cd database-query-optimization/setup/postgresql
docker compose up -d

export PGHOST=localhost PGPORT=6432 PGUSER=optimization PGPASSWORD=optimization PGDATABASE=optimization
for f in EMPLOYEES CITIES generate_random_phone_number insert_values_into_cities \
         insert_values_into_employees update_managers populate; do
  psql -v ON_ERROR_STOP=1 -f $f.sql
done

cd ../..
psql -f hierarchical-queries/postgresql_with_recursive.sql
psql -f execution-plans/scan_types.sql
```

The other folders run the same way; inside `planner-hints/` and `views-and-materialized-views/` the files are numbered in the order they build on each other (`04_city_salary_stats.sql` uses the `city_id` column added in `planner-hints/03_cities_join_setup.sql`). `vacuum-mvcc/vacuum_experiment.sql` is best run step by step, since parts of it wait for autovacuum. Exact costs and timings depend on the random data and on when statistics were last collected.

Oracle (Docker, port 1526; the `SYSTEM` password comes from `ORACLE_PWD`):

```bash
cd setup/oracle
docker compose up -d
for f in EMPLOYEES CITIES generate_random_phone_number insert_values_into_cities \
         insert_values_into_employees update_managers populate; do
  docker compose exec -T oracle sqlplus -s system/oracle@//localhost:1521/XE < $f.sql
done
docker compose exec -T oracle sqlplus -s system/oracle@//localhost:1521/XE < ../../hierarchical-queries/oracle_connect_by.sql
```

## 🗂 Project structure

```
database-query-optimization/
├── setup/                         # docker-compose, schema, data generators (oracle/, postgresql/)
├── hierarchical-queries/          # CONNECT BY vs WITH RECURSIVE
├── execution-plans/               # EXPLAIN walkthrough of scan types
├── vacuum-mvcc/                   # dead tuples, VACUUM, VACUUM FULL, autovacuum
├── planner-hints/                 # planner settings, pg_hint_plan, OR rewrite, work_mem
├── views-and-materialized-views/  # generated columns, views, matviews, CTE, functions
└── audit-trigger/                 # generic JSONB-based change history trigger
```

## 🛠️ Tech stack

- PostgreSQL 13 / 16, SQL, PL/pgSQL, `pg_hint_plan`
- Oracle Database 21c Express Edition, PL/SQL
- Docker Compose
- IntelliJ IDEA database tools
