-- Change history for one column of EMPLOYEES (phone_number) and one column of CITIES (name).
-- Every update of a tracked column adds a row, so repeated changes of the same
-- value are all kept; table_name + column_name + row_id identify what changed.
CREATE TABLE change_history (
    id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    column_name TEXT NOT NULL,
    row_id INTEGER NOT NULL,
    old_value TEXT,
    new_value TEXT,
    changed_at TIMESTAMP DEFAULT now()
);

-- One generic trigger function for any table: the tracked column name is passed
-- as a trigger argument and read from the row converted to JSONB
CREATE OR REPLACE FUNCTION log_column_changes()
    RETURNS TRIGGER AS
$$
DECLARE
    col_name TEXT := TG_ARGV[0];
    old_val TEXT;
    new_val TEXT;
BEGIN
    old_val := to_jsonb(OLD)->>col_name;
    new_val := to_jsonb(NEW)->>col_name;

    IF old_val IS DISTINCT FROM new_val THEN
        INSERT INTO change_history (
            table_name,
            column_name,
            row_id,
            old_value,
            new_value
        )
        VALUES (
                   TG_TABLE_NAME,
                   col_name,
                   OLD.id,
                   old_val,
                   new_val
               );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_employee_phone_changes
    AFTER UPDATE ON employees
    FOR EACH ROW
EXECUTE FUNCTION log_column_changes('phone_number');

CREATE TRIGGER trg_city_name_changes
    AFTER UPDATE ON cities
    FOR EACH ROW
EXECUTE FUNCTION log_column_changes('name');

-- two phone changes and three name changes of the same rows
UPDATE employees SET phone_number = '123' WHERE id = 1;
UPDATE employees SET phone_number = '456' WHERE id = 1;
UPDATE cities SET name = '123' WHERE id = 1;
UPDATE cities SET name = '456' WHERE id = 1;
UPDATE cities SET name = '789' WHERE id = 1;

SELECT * FROM change_history;
