-- Steering the planner without extensions: enable_* switches and cost constants.
-- Needs an index on salary (created in execution-plans/scan_types.sql).
CREATE INDEX IF NOT EXISTS idx_emp_salary ON employees(salary);

-- Default plan: ~77% of the rows match, so a sequential scan is cheapest
EXPLAIN
SELECT * FROM employees WHERE salary > 10000;
-- Seq Scan on employees  (cost=0.00..3807.00 rows=77064 width=68)
--   Filter: (salary > 10000)

-- enable_seqscan = off does not forbid Seq Scan, it makes it prohibitively expensive
SET enable_seqscan = off;

EXPLAIN
SELECT * FROM employees WHERE salary > 10000;
-- Bitmap Heap Scan on employees  (cost=759.24..4279.54 rows=77064 width=68)
--   Recheck Cond: (salary > 10000)
--   ->  Bitmap Index Scan on idx_emp_salary  (cost=0.00..739.97 rows=77064 width=0)
--         Index Cond: (salary > 10000)

RESET enable_seqscan;

-- Random reads made cheap (default 4.0) and sequential reads expensive (default 1.0)
SET random_page_cost = 1.0;
SET seq_page_cost = 10.0;

EXPLAIN
SELECT * FROM employees WHERE salary > 10000;
-- Index Scan using idx_emp_salary on employees  (cost=0.29..4053.02 rows=77064 width=68)
--   Index Cond: (salary > 10000)

RESET random_page_cost;
RESET seq_page_cost;
