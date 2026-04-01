-- Recursive views over the manager -> subordinate relation

-- Up the hierarchy: every employee together with all his managers
CREATE OR REPLACE VIEW employee_hierarchy_up AS
WITH RECURSIVE hierarchy AS (
    SELECT
        e.id AS employee_id,
        e.first_name,
        e.last_name,
        e.manager_id,
        1 AS level
    FROM employees e

    UNION ALL

    SELECT
        h.employee_id,
        m.first_name,
        m.last_name,
        m.manager_id,
        h.level + 1
    FROM hierarchy h
             JOIN employees m ON h.manager_id = m.id
)
SELECT * FROM hierarchy;

-- the employee himself (level 1), his manager (level 2), the manager's manager...
SELECT * FROM employee_hierarchy_up
WHERE employee_id = 10;

-- Down the hierarchy: every manager together with all his direct and indirect subordinates
CREATE OR REPLACE VIEW employee_hierarchy_down AS
WITH RECURSIVE hierarchy AS (
    SELECT
        e.id AS manager_id,
        e.id AS employee_id,
        e.first_name,
        e.last_name,
        1 AS level
    FROM employees e

    UNION ALL

    SELECT
        h.manager_id,
        e.id,
        e.first_name,
        e.last_name,
        h.level + 1
    FROM hierarchy h
             JOIN employees e ON e.manager_id = h.employee_id
)
SELECT * FROM hierarchy;

-- all managers above employee 20, with the distance to each of them
SELECT * FROM employee_hierarchy_down
WHERE employee_id = 20;
