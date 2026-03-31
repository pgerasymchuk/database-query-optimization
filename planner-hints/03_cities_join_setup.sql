-- Link EMPLOYEES to CITIES so that the two tables can be joined
alter table CITIES
    add constraint cities_pk primary key (id);

alter table employees
    add column city_id integer;

alter table employees
    add constraint EMP_CITY_FK foreign key (CITY_ID)
        references CITIES (ID);

-- every employee gets a random existing city
UPDATE employees
SET city_id = floor(random() * (SELECT count(*) FROM cities))::int + 1;

CREATE INDEX idx_employees_city_id ON employees(city_id);
