-- 100 000 cities and 100 000 employees
DO $$
BEGIN
    CALL INSERT_VALUES_INTO_CITIES();
    CALL INSERT_VALUES_INTO_EMPLOYEES();
END $$;

-- manager -> subordinates links: every manager gets up to 8 subordinates
DO $$
BEGIN
    CALL UPDATE_MANAGERS(100000, 8);
END $$;
