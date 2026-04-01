-- Materialized copies of the hierarchy views and how they differ from plain views
CREATE MATERIALIZED VIEW memployee_hierarchy_up AS
SELECT * FROM employee_hierarchy_up;

CREATE MATERIALIZED VIEW memployee_hierarchy_down AS
SELECT * FROM employee_hierarchy_down;

-- a new employee appears in the base table
INSERT INTO employees (first_name, last_name, email, hire_date, job_id, salary)
VALUES ('Test', 'User', 'test@test.com', CURRENT_DATE, 'DEV', 1000);

-- plain view: the whole recursive query runs again
EXPLAIN ANALYZE SELECT * FROM employee_hierarchy_up;
-- CTE Scan on hierarchy  (cost=394055.11..596055.11 rows=10100000 width=138) (actual time=59.551..320.453 rows=667895 loops=1)
--   CTE hierarchy
--     ->  Recursive Union  (cost=0.00..394055.11 rows=10100000 width=25) (actual time=59.549..205.938 rows=667895 loops=1)
--           ->  Seq Scan on employees e  (cost=0.00..2664.00 rows=100000 width=25) (actual time=59.544..66.436 rows=100001 loops=1)
--           ->  Hash Join  (cost=3914.00..29039.11 rows=1000000 width=25) (actual time=3.057..11.169 rows=81128 loops=7)
--                 Hash Cond: (h.manager_id = m.id)
--                 ->  WorkTable Scan on hierarchy h  (cost=0.00..20000.00 rows=1000000 width=12)
--                 ->  Hash  (cost=2664.00..2664.00 rows=100000 width=21) (actual time=15.687..15.690 rows=100001 loops=1)
--                       Buckets: 131072  Batches: 1  Memory Usage: 6375kB
--                       ->  Seq Scan on employees m  (cost=0.00..2664.00 rows=100000 width=21)
-- Planning Time: 0.120 ms
-- JIT:
--   Functions: 10
--   Options: Inlining true, Optimization true, Expressions true, Deforming true
--   Timing: Generation 0.514 ms, Inlining 7.622 ms, Optimization 29.743 ms, Emission 22.182 ms, Total 60.062 ms
-- Execution Time: 334.706 ms

-- materialized view: a plain scan of the stored result
EXPLAIN ANALYZE SELECT * FROM memployee_hierarchy_up;
-- Seq Scan on memployee_hierarchy_up  (cost=0.00..11286.94 rows=667894 width=25) (actual time=0.626..70.278 rows=667894 loops=1)
-- Planning Time: 0.079 ms
-- Execution Time: 80.971 ms

-- the new employee is visible through the view (1) but not through the stale materialized view (0)
SELECT COUNT(*)
FROM memployee_hierarchy_up
WHERE first_name = 'Test';

SELECT COUNT(*)
FROM employee_hierarchy_up
WHERE first_name = 'Test';

REFRESH MATERIALIZED VIEW memployee_hierarchy_up;

-- after the refresh: 1
SELECT COUNT(*)
FROM memployee_hierarchy_up
WHERE first_name = 'Test';
