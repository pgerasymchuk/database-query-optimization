-- Choosing the join method with pg_hint_plan
LOAD 'pg_hint_plan';

-- Default: Nested Loop over a Memoize node and the cities primary key
EXPLAIN
SELECT *
FROM employees e
         JOIN cities c ON c.id = e.city_id
WHERE e.salary > 10000;
-- Nested Loop  (cost=0.43..5742.20 rows=77331 width=91)
--   ->  Seq Scan on employees e  (cost=0.00..3808.00 rows=77331 width=72)
--         Filter: (salary > 10000)
--   ->  Memoize  (cost=0.43..0.47 rows=1 width=19)
--         Cache Key: e.city_id
--         Cache Mode: logical
--         ->  Index Scan using cities_pk on cities c  (cost=0.42..0.46 rows=1 width=19)
--               Index Cond: (id = e.city_id)

-- HashJoin hint: both tables are read sequentially, cities go into a hash table
EXPLAIN
/*+ HashJoin(e c) */
SELECT *
FROM employees e
         JOIN cities c ON c.id = e.city_id
WHERE e.salary > 10000;
-- Hash Join  (cost=5772.00..9782.99 rows=77331 width=91)
--   Hash Cond: (e.city_id = c.id)
--   ->  Seq Scan on employees e  (cost=0.00..3808.00 rows=77331 width=72)
--         Filter: (salary > 10000)
--   ->  Hash  (cost=3272.00..3272.00 rows=200000 width=19)
--         ->  Seq Scan on cities c  (cost=0.00..3272.00 rows=200000 width=19)

-- NestLoop hint: same plan as the default one
EXPLAIN
/*+ NestLoop(e c) */
SELECT *
FROM employees e
         JOIN cities c ON c.id = e.city_id
WHERE e.salary > 10000;
