-- Join order (Leading) and row-count correction (Rows) hints
LOAD 'pg_hint_plan';

-- Without a hint the filtered cities side is already built first
EXPLAIN ANALYZE
SELECT *
FROM employees e
         JOIN cities c ON e.city_id = c.id
WHERE c.id < 5;
-- Hash Join  (cost=6.03..3826.53 rows=2 width=91)
--   Hash Cond: (e.city_id = c.id)
--   ->  Seq Scan on employees e  (cost=0.00..3558.00 rows=100000 width=72)
--   ->  Hash  (cost=5.98..5.98 rows=4 width=19)
--         Buckets: 1024  Batches: 1  Memory Usage: 9kB
--         ->  Bitmap Heap Scan on cities c  (cost=1.55..5.98 rows=4 width=19)
--               Recheck Cond: (id < 5)
--               ->  Bitmap Index Scan on cities_pk  (cost=0.00..1.55 rows=4 width=0)
--                     Index Cond: (id < 5)
-- Planning Time: 0.113 ms
-- Execution Time: 8.443 ms

/*+ Leading((c e)) */
EXPLAIN ANALYZE
SELECT *
FROM employees e
         JOIN cities c ON e.city_id = c.id
WHERE c.id < 5;
-- same Hash Join plan
-- Planning Time: 0.115 ms
-- Execution Time: 8.175 ms

-- Join with a set-returning function: the planner expects 1000 rows from generate_series
EXPLAIN ANALYZE
SELECT *
FROM employees e
         JOIN generate_series(1, 1000) gs(id)
              ON e.id = gs.id;
-- Nested Loop  (cost=1.01..2125.25 rows=1000 width=76)
--   ->  Function Scan on generate_series gs  (cost=0.00..10.00 rows=1000 width=4)
--   ->  Bitmap Heap Scan on employees e  (cost=1.00..2.12 rows=1 width=72)
--         Recheck Cond: (id = gs.id)
--         Heap Blocks: exact=1000
--         ->  Bitmap Index Scan on emp_emp_id_pk  (cost=0.00..1.00 rows=1 width=0)
--               Index Cond: (id = gs.id)
-- Planning Time: 0.113 ms
-- Execution Time: 1.192 ms

-- Rows overrides the estimated size of the e-gs join (#100 = exactly 100 rows),
-- which switches the plan to a Hash Join over the whole table
/*+ Rows(e gs #100) */
EXPLAIN ANALYZE
SELECT *
FROM employees e
         JOIN generate_series(1, 1000) gs(id)
              ON e.id = gs.id;
-- Hash Join  (cost=4808.00..4820.63 rows=1000 width=76) (actual time=9.812..10.082 rows=1000 loops=1)
--   Hash Cond: (gs.id = e.id)
--   ->  Function Scan on generate_series gs  (cost=0.00..10.00 rows=1000 width=4)
--   ->  Hash  (cost=3558.00..3558.00 rows=100000 width=72)
--         Buckets: 131072  Batches: 1  Memory Usage: 11547kB
--         ->  Seq Scan on employees e  (cost=0.00..3558.00 rows=100000 width=72)
-- Planning Time: 0.081 ms
