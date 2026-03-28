-- The same manager -> subordinates tree in PostgreSQL.
-- The anchor part selects the root (employee 1), the recursive part after
-- UNION ALL joins employees whose manager_id is an already found employee.
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
