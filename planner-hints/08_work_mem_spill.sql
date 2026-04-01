-- Operations that do not fit into work_mem spill to disk
SET work_mem = '64kB';

-- Sort: external merge on disk
EXPLAIN ANALYZE
SELECT *
FROM employees
ORDER BY last_name;
-- Sort  (cost=19070.62..19320.62 rows=100000 width=72)
--   Sort Key: last_name
--   Sort Method: external merge  Disk: 8448kB
--   ->  Seq Scan on employees  (cost=0.00..3558.00 rows=100000 width=72)
-- Planning Time: 0.053 ms
-- Execution Time: 44.489 ms

-- Hash Join: the hash table is split into batches written to disk
EXPLAIN ANALYZE
SELECT *
FROM employees e
         JOIN cities c ON e.city_id = c.id;
-- Hash Join  (cost=6944.00..14280.50 rows=100000 width=91)
--   Hash Cond: (e.city_id = c.id)
--   ->  Seq Scan on employees e  (cost=0.00..3558.00 rows=100000 width=72)
--   ->  Hash  (cost=3272.00..3272.00 rows=200000 width=19)
--         Buckets: 2048  Batches: 128  Memory Usage: 97kB
--         ->  Seq Scan on cities c  (cost=0.00..3272.00 rows=200000 width=19)
-- Planning Time: 0.112 ms
-- Execution Time: 43.325 ms

RESET work_mem;
