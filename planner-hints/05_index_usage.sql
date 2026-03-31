-- How often each index of EMPLOYEES has been used
SELECT * FROM pg_stat_user_indexes WHERE relname = 'employees';
-- indexrelname          | idx_scan | last_idx_scan                 | idx_tup_read | idx_tup_fetch
-- emp_emp_id_pk         |   199997 | 2026-03-31 20:25:40.819255+00 |       299973 |        199997
-- emp_email_uk          |        0 |                               |            0 |             0
-- idx_employees_salary  |        2 | 2026-03-31 20:39:03.552230+00 |       200000 |             0
-- idx_employees_city_id |        0 |                               |            0 |             0

-- A hint that cannot be applied: an index-only scan needs every selected column
-- in the index, but idx_employees_salary holds only salary and the query wants *
LOAD 'pg_hint_plan';

/*+ IndexOnlyScan(employees idx_employees_salary) */
EXPLAIN
SELECT * FROM employees ORDER BY salary;
-- Index Scan using idx_employees_salary on employees  (cost=0.29..4728.79 rows=100000 width=72)
