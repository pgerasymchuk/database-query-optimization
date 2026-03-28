-- Scan operations in PostgreSQL execution plans.
-- Each query is built so that the planner picks one specific scan type;
-- the plan observed on the 100 000-row EMPLOYEES table is kept below it.

-- ---------------------------------------------------------------------------
-- Seq Scan: there is no index on salary, so the whole table is read.
-- ---------------------------------------------------------------------------
EXPLAIN
SELECT *
FROM employees
WHERE salary > 1000;
-- Seq Scan on employees  (cost=0.00..3807.00 rows=99990 width=68)
--   Filter: (salary > 1000)

-- ---------------------------------------------------------------------------
-- Index Scan: id is the PRIMARY KEY, its index emp_emp_id_pk is created automatically.
-- ---------------------------------------------------------------------------
EXPLAIN
SELECT *
FROM employees
WHERE id = 1;
-- Index Scan using emp_emp_id_pk on employees  (cost=0.42..2.64 rows=1 width=68)
--   Index Cond: (id = 1)

-- ---------------------------------------------------------------------------
-- Index Only Scan: a covering index holds every column the query needs,
-- so the heap is not touched.
-- ---------------------------------------------------------------------------
CREATE INDEX idx_emp_salary_cover
    ON employees
        (salary, first_name, last_name);

EXPLAIN
SELECT salary, first_name, last_name
FROM employees
WHERE salary = 5000;
-- Index Only Scan using idx_emp_salary_cover on employees  (cost=0.42..1.57 rows=3 width=17)
--   Index Cond: (salary = 5000)

-- ---------------------------------------------------------------------------
-- Bitmap Index Scan + BitmapAnd + Bitmap Heap Scan: two separate indexes are
-- scanned, their bitmaps are intersected and only then the heap pages are read.
-- ---------------------------------------------------------------------------
CREATE INDEX idx_emp_salary ON employees(salary);
CREATE INDEX idx_emp_dept ON employees(department_id);

EXPLAIN
SELECT *
FROM employees
WHERE salary < 2000 AND department_id = 10;
-- Bitmap Heap Scan on employees  (cost=34.51..63.24 rows=26 width=68)
--   Recheck Cond: ((department_id = 10) AND (salary < 2000))
--   ->  BitmapAnd  (cost=34.51..34.51 rows=26 width=0)
--         ->  Bitmap Index Scan on idx_emp_dept  (cost=0.00..8.82 rows=990 width=0)
--               Index Cond: (department_id = 10)
--         ->  Bitmap Index Scan on idx_emp_salary  (cost=0.00..25.43 rows=2618 width=0)
--               Index Cond: (salary < 2000)

-- ---------------------------------------------------------------------------
-- TID Scan: the physical row address (ctid) is given explicitly.
-- ---------------------------------------------------------------------------
EXPLAIN
SELECT *
FROM employees
WHERE ctid = '(0,1)';
-- Tid Scan on employees  (cost=0.00..1.11 rows=1 width=68)
--   TID Cond: (ctid = '(0,1)'::tid)

-- ---------------------------------------------------------------------------
-- Subquery Scan: the window function keeps the planner from inlining the subquery.
-- ---------------------------------------------------------------------------
EXPLAIN
SELECT *
FROM (
     SELECT id, first_name, salary,
            ROW_NUMBER() OVER (ORDER BY salary) AS rn
     FROM employees
) sub
WHERE rn <= 10;
-- Subquery Scan on sub  (cost=0.29..7271.99 rows=33333 width=22)
--   Filter: (sub.rn <= 10)
--   ->  WindowAgg  (cost=0.29..6021.99 rows=100000 width=22)
--         ->  Index Scan using idx_emp_salary on employees  (cost=0.29..4521.99 rows=100000 width=14)
-- (PostgreSQL 15+ turns "rn <= 10" into a Run Condition of the WindowAgg, stops the
--  window early and no longer needs the Subquery Scan node on top of it)

-- ---------------------------------------------------------------------------
-- Function Scan: rows come from a set-returning function.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_high_paid(min_salary INT)
    RETURNS TABLE(id INT, first_name TEXT, salary INT)
AS $$
BEGIN
    RETURN QUERY
        SELECT e.id, e.first_name::TEXT, e.salary
        FROM employees e
        WHERE e.salary > min_salary;
END;
$$ LANGUAGE plpgsql;

EXPLAIN
SELECT *
FROM get_high_paid(3000);
-- Function Scan on get_high_paid  (cost=0.25..10.25 rows=1000 width=40)

-- ---------------------------------------------------------------------------
-- Values Scan: rows come from an inline VALUES list.
-- ---------------------------------------------------------------------------
EXPLAIN
SELECT *
FROM (VALUES (1, 'A'), (2, 'B'), (3, 'C')) AS t(id, name);
-- Values Scan on "*VALUES*"  (cost=0.00..0.04 rows=3 width=36)

-- ---------------------------------------------------------------------------
-- CTE Scan: MATERIALIZED forces the CTE to be computed once and then scanned.
-- ---------------------------------------------------------------------------
EXPLAIN
WITH emp_cte AS MATERIALIZED (
    SELECT id, first_name, salary
    FROM employees
    WHERE salary > 2000
)
SELECT *
FROM emp_cte;
-- CTE Scan on emp_cte  (cost=3807.00..5754.58 rows=97379 width=66)
--   CTE emp_cte
--     ->  Seq Scan on employees  (cost=0.00..3807.00 rows=97379 width=14)
--           Filter: (salary > 2000)

-- ---------------------------------------------------------------------------
-- WorkTable Scan: a recursive CTE keeps the rows of the previous iteration
-- in a work table that the recursive part reads.
-- ---------------------------------------------------------------------------
EXPLAIN
WITH RECURSIVE employee_tree AS (
    SELECT id, first_name, last_name, manager_id, 1 AS level
    FROM employees
    WHERE id = 1

    UNION ALL

    SELECT e.id, e.first_name, e.last_name, e.manager_id, et.level + 1
    FROM employees e
             JOIN employee_tree et ON e.manager_id = et.id
)
SELECT LPAD(' ', (level - 1) * 2) || first_name || ' ' || last_name AS employee_name, level
FROM employee_tree;
-- CTE Scan on employee_tree  (cost=39351.90..39379.94 rows=801 width=36)
--   CTE employee_tree
--     ->  Recursive Union  (cost=0.42..39351.90 rows=801 width=25)
--           ->  Index Scan using emp_emp_id_pk on employees  (cost=0.42..2.64 rows=1 width=25)
--                 Index Cond: (id = 1)
--           ->  Hash Join  (cost=0.33..3933.32 rows=80 width=25)
--                 Hash Cond: (e.manager_id = et.id)
--                 ->  Seq Scan on employees e  (cost=0.00..3557.00 rows=100000 width=21)
--                 ->  Hash  (cost=0.20..0.20 rows=10 width=8)
--                       ->  WorkTable Scan on employee_tree et  (cost=0.00..0.20 rows=10 width=8)
