CREATE OR REPLACE PROCEDURE insert_values_into_cities AS
    TYPE city_list_t IS VARRAY(10) OF VARCHAR2(40);
    city_list city_list_t := city_list_t(
            'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix',
            'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose'
                             );

    v_city VARCHAR2(100);
BEGIN
    FOR i IN 1..100000 LOOP
            v_city := city_list(TRUNC(DBMS_RANDOM.VALUE(1, city_list.COUNT + 1)));

            INSERT INTO CITIES (name)
            VALUES (v_city || ' ' || i);
        END LOOP;

    COMMIT;
END insert_values_into_cities;
/
