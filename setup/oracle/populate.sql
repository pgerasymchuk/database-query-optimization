-- 100 000 cities and 100 000 employees
begin
    INSERT_VALUES_INTO_CITIES();
    INSERT_VALUES_INTO_EMPLOYEES();
end;
/

-- manager -> subordinates links: every manager gets up to 8 subordinates
begin
    UPDATE_MANAGERS(100000, 8);
end;
/
