-- Stored generated columns: computed from other columns on every INSERT/UPDATE

-- mail domain taken from the e-mail address
ALTER TABLE employees
    ADD COLUMN email_domain varchar(50)
        GENERATED ALWAYS AS (split_part(email, '@', 2)) STORED;

-- full name of the employee
ALTER TABLE employees
    ADD COLUMN full_name varchar(60)
        GENERATED ALWAYS AS (last_name || ' ' || first_name) STORED;

SELECT * FROM employees;
