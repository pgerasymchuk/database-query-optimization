-- Four ways to expose the same derived data: per city - number of employees,
-- average and maximum salary (needs employees.city_id from planner-hints/03_cities_join_setup.sql)

-- 1. Plain view: always up to date, takes no space, but the join and
--    aggregation run on every query
CREATE VIEW city_salary_stats AS
SELECT
    c.name AS city,
    COUNT(e.id) AS employee_count,
    AVG(e.salary) AS avg_salary,
    MAX(e.salary) AS max_salary
FROM employees e
         JOIN cities c ON e.city_id = c.id
GROUP BY c.name;

SELECT * FROM city_salary_stats
WHERE avg_salary > 30000;

-- 2. Materialized view: precomputed and indexable, refreshed on demand
CREATE MATERIALIZED VIEW city_salary_stats_mat AS
SELECT
    c.name AS city,
    COUNT(e.id) AS employee_count,
    AVG(e.salary) AS avg_salary,
    MAX(e.salary) AS max_salary
FROM employees e
         JOIN cities c ON e.city_id = c.id
GROUP BY c.name;

CREATE INDEX idx_city_salary_mat ON city_salary_stats_mat(city);

EXPLAIN
SELECT *
FROM city_salary_stats_mat
WHERE city = 'New York 61051';
-- Index Scan using idx_city_salary_mat on city_salary_stats_mat  (cost=0.42..2.64 rows=1 width=33)
--   Index Cond: ((city)::text = 'New York 61051'::text)

-- 3. CTE: lives only inside one query, keeps complex logic readable
WITH city_stats AS (
    SELECT
        c.name AS city,
        COUNT(e.id) AS employee_count,
        AVG(e.salary) AS avg_salary,
        MAX(e.salary) AS max_salary
    FROM employees e
    JOIN cities c ON e.city_id = c.id
    GROUP BY c.name
)
SELECT *
FROM city_stats
WHERE avg_salary > 30000;

-- 4. Function returning TABLE: reusable and parameterised
CREATE OR REPLACE FUNCTION get_city_salary_stats(min_salary INT)
    RETURNS TABLE (
                      city VARCHAR,
                      avg_salary NUMERIC
                  )
AS $$
BEGIN
    RETURN QUERY
        SELECT
            c.name,
            AVG(e.salary)
        FROM employees e
                 JOIN cities c ON e.city_id = c.id
        GROUP BY c.name
        HAVING AVG(e.salary) > min_salary;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_city_salary_stats(30000);
