-- MVCC, dead tuples and VACUUM on a copy of EMPLOYEES.
-- Run statement by statement: some steps wait for autovacuum, and
-- ALTER SYSTEM needs a superuser and cannot run inside a transaction block.

-- 1. Is autovacuum enabled?
SHOW autovacuum;

-- 2. Test table with the same content as EMPLOYEES
CREATE TABLE TEST_VACUUM AS SELECT * FROM EMPLOYEES;

SELECT COUNT(*) FROM TEST_VACUUM;

-- 3. Dead tuples of a freshly created table (0)
SELECT relname, n_dead_tup, n_live_tup
FROM pg_stat_all_tables
WHERE relname = 'test_vacuum';

-- 4. Mass update: every row gets a new version, the old one becomes dead
UPDATE TEST_VACUUM SET salary = salary + 100;

-- right after the update: n_dead_tup = 100000;
-- a few minutes later autovacuum has cleaned them up: n_dead_tup = 0
SELECT relname, n_dead_tup, n_live_tup
FROM pg_stat_all_tables
WHERE relname = 'test_vacuum';

-- 5. Turn autovacuum off to compare a query before and after a manual VACUUM
ALTER SYSTEM SET autovacuum = 'off';
SELECT pg_reload_conf();

UPDATE TEST_VACUUM SET salary = salary + 100;

EXPLAIN ANALYZE SELECT * FROM TEST_VACUUM WHERE salary > 5000;

-- 6. Manual VACUUM removes the dead tuples
VACUUM TEST_VACUUM;

SELECT relname, n_dead_tup, n_live_tup
FROM pg_stat_all_tables
WHERE relname = 'test_vacuum';

-- 7. VACUUM ANALYZE also refreshes planner statistics
VACUUM ANALYZE TEST_VACUUM;

EXPLAIN ANALYZE SELECT * FROM TEST_VACUUM WHERE salary > 5000;

-- 8. VACUUM FULL rewrites the table and gives the space back to the OS
SELECT pg_size_pretty(pg_total_relation_size('test_vacuum'));

VACUUM FULL TEST_VACUUM;

SELECT pg_size_pretty(pg_total_relation_size('test_vacuum'));

-- 9. Turn autovacuum back on
ALTER SYSTEM SET autovacuum = 'on';
SELECT pg_reload_conf();

-- 10. Many updates and deletes, then check that autovacuum ran by itself
UPDATE TEST_VACUUM SET salary = salary + 500 WHERE department_id = 10;
DELETE FROM TEST_VACUUM WHERE salary > 10000;

-- wait about a minute (autovacuum_naptime) before checking
SELECT now(), last_autovacuum, last_autoanalyze
FROM pg_stat_all_tables
WHERE relname = 'test_vacuum';

-- when autovacuum last processed each user table
SELECT relname, last_autovacuum
FROM pg_stat_user_tables;
