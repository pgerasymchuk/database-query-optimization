-- Direct hints with the pg_hint_plan extension
-- (bundled in the postgresai/extended-postgres image from setup/postgresql).
CREATE EXTENSION IF NOT EXISTS pg_hint_plan;  -- creates the hint_plan.hints table
LOAD 'pg_hint_plan';
SET pg_hint_plan.enable_hint TO on;        -- process /*+ ... */ hints in queries
SET pg_hint_plan.enable_hint_table TO ON;  -- also allow hints from the hint_plan.hints table
SET pg_hint_plan.debug_print = on;         -- log which hints were used

CREATE INDEX idx_employees_salary ON employees(salary);

-- Without a hint the planner prefers a sequential scan
EXPLAIN
SELECT * FROM employees WHERE salary > 10000;
-- Seq Scan on employees  (cost=0.00..3807.00 rows=76564 width=68)
--   Filter: (salary > 10000)

-- IndexScan hint forces the index
EXPLAIN
/*+ IndexScan(employees idx_employees_salary) */
SELECT * FROM employees WHERE salary > 10000;
-- Index Scan using idx_employees_salary on employees  (cost=0.29..4313.36 rows=76564 width=68)
--   Index Cond: (salary > 10000)
