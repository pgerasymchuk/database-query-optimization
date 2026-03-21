-- Manager -> subordinates tree in Oracle.
-- START WITH picks the root (employee 1), CONNECT BY PRIOR walks from a manager
-- to the rows whose MANAGER_ID points at him, NOCYCLE stops on loops.
SELECT LPAD(' ', (LEVEL-1) * 2) || FIRST_NAME || ' ' || LAST_NAME AS EMPLOYEE_NAME, level
from EMPLOYEES
start with id = 1
connect by nocycle PRIOR id = MANAGER_ID;
