-- PART B 
-- Function that transforms NUMERIC(5,2) prices into VARCHAR categories. 
CREATE
OR REPLACE FUNCTION price_categorizer (amount NUMERIC(5, 2)) RETURNS VARCHAR LANGUAGE plpgsql AS $$
DECLARE
    price_range VARCHAR(15);
   BEGIN
        IF amount BETWEEN 0.00 AND 5.00 THEN 
            price_range = 'cheap';
        ELSEIF amount BETWEEN 5.00 AND 10.00 THEN
            price_range = 'budget';
        ELSE
            price_range = 'expensive';
        END IF;

        RETURN price_range;
    END;
$$;

---------------------------------------------
-- PART C
-- C: Creating empty detailed table.
DROP TABLE IF EXISTS rental_details;

CREATE TABLE IF NOT EXISTS
    rental_details (
        rental_id INTEGER,
        customer_id SMALLINT,
        amount NUMERIC(5, 2)
    );

-- C: Creating empty summary table.
DROP TABLE IF EXISTS rental_summary;

CREATE TABLE IF NOT EXISTS
    rental_summary (
        customer_id SMALLINT,
        cheapest_bought INTEGER,
        budget_bought INTEGER,
        expensive_bought INTEGER
    );

---------------------------------------------
-- PART D 
-- D: Complex query to extract data from rental and payment, into the detailed table 'rental_details'.
INSERT INTO
    rental_details (
        ---- field from 'rental'
        rental_id,
        ---- fields from 'payment'
        customer_id,
        amount
    )
    -- selecting fields to load into detailed table
SELECT
    rnt.rental_id,
    pay.customer_id,
    pay.amount
FROM
    rental AS rnt
    -- extracting data from both 'rental' and 'payment' tables
    INNER JOIN payment AS pay ON rnt.rental_id = pay.rental_id
ORDER BY
    customer_id;

SELECT
    *
FROM
    rental_details;

---------------------------------------------
-- PART E 
-- Creating the trigger function.
CREATE
OR REPLACE FUNCTION refresh_rental_summary_func () RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN 
    CALL rebuild_rental_summary(); -- procedure to refresh summary table
RETURN NULL;
END;
$$;

-- E: The created trigger, it will update any time new data is INSERTED into the detailed table.
CREATE TRIGGER rebuild_rental_summary_trigger
AFTER INSERT ON rental_details FOR EACH STATEMENT
EXECUTE PROCEDURE refresh_rental_summary_func ();

---------------------------------------------
-- PART F
-- Stored Procedures that refresh data in both the detailed and summary tables

-- F: Stored procedure to refresh detailed table 'rental_details'.
CREATE
OR REPLACE PROCEDURE rebuild_rental_details () LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM rental_details;

INSERT INTO rental_details(
    rental_id,
    customer_id,
    amount)

SELECT
rnt.rental_id,
pay.customer_id, pay.amount

FROM rental AS rnt
INNER JOIN payment AS pay
ON rnt.rental_id = pay.rental_id
ORDER BY customer_id;
END;
$$;

-- F: Stored procedure to refresh summary table 'rental_summary'.
CREATE
OR REPLACE PROCEDURE rebuild_rental_summary () LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM rental_summary;

INSERT INTO 
    rental_summary( 
        SELECT 
           customer_id,
           COUNT(case price_categorizer(amount) when 'cheap' then 1 end) as cheapest_bought,
           COUNT(case price_categorizer(amount) when 'budget' then 1 end) as budget_bought,
           COUNT(case price_categorizer(amount) when 'expensive' then 1 end) as expensive_bought
        FROM rental_details
        GROUP BY customer_id
		ORDER BY customer_id
    );
END;
$$;

-- F: Stored Procedure used to rebuild BOTH tables. 
---- In practice this is what can be scheduled with a tool such as
---- pgagent from pgadmin4.
CREATE
OR REPLACE PROCEDURE rebuild_tables () LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM rental_details;
DELETE FROM rental_summary;

CALL rebuild_rental_details();
CALL rebuild_rental_summary();
END;
$$;