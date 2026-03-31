-- Rewriting OR as UNION ALL so that each branch can use its own access path

-- OR across two columns: one sequential scan with a combined filter
EXPLAIN ANALYZE
SELECT *
FROM employees
WHERE salary > 90000
   OR first_name = 'Daniel';
-- Seq Scan on employees  (cost=0.00..4058.00 rows=4753 width=72)
--   Filter: ((salary > 90000) OR ((first_name)::text = 'Daniel'::text))
--   Rows Removed by Filter: 95058
-- Planning Time: 0.099 ms
-- Execution Time: 6.217 ms

-- UNION ALL: Index Scan on salary for the first branch, Seq Scan for the second
EXPLAIN ANALYZE
SELECT *
FROM employees
WHERE salary > 90000

UNION ALL

SELECT *
FROM employees
WHERE first_name = 'Daniel';
-- Append  (cost=0.29..3834.28 rows=4754 width=72)
--   ->  Index Scan using idx_employees_salary on employees  (cost=0.29..2.51 rows=1 width=72)
--         Index Cond: (salary > 90000)
--   ->  Seq Scan on employees employees_1  (cost=0.00..3808.00 rows=4753 width=72)
--         Filter: ((first_name)::text = 'Daniel'::text)
--         Rows Removed by Filter: 95058
-- Planning Time: 0.134 ms
-- Execution Time: 5.220 ms
