-- B Function that transforms ___ identified in A4.
-- Transformation 3: Aggregation of total number of rentals bought within each price range
CREATE OR REPLACE FUNCTION price_aggregator(
    amount NUMERIC(5,2), 
    price_range_start NUMERIC(5,2), 
    price_range_end NUMERIC(5,2))
RETURNS INTEGER
LANGUAGE 'plpgsql'
AS
$$
DECLARE
    price_count INT;
   BEGIN
        IF amount != NULL
        THEN 
            SELECT COUNT(amount) AS price_count
            FROM rental_details
            WHERE amount BETWEEN price_range_start AND price_range_end;
		ELSE price_count = 0;
		RETURN price_count;
		
		END IF;
    
END;
$$;

--/////////////////////////////////////////////////////////////////////////////--
-- C Creating empty detailed table.
DROP TABLE IF EXISTS rental_details;
CREATE TABLE IF NOT EXISTS rental_details(
    rental_id INTEGER,
    rental_date TIMESTAMP,
    return_date TIMESTAMP,
    customer_id SMALLINT,
    amount NUMERIC(5,2),
	payment_date TIMESTAMP
); 
-- C Creating empty summary table.
DROP TABLE IF EXISTS rental_summary;
CREATE TABLE IF NOT EXISTS rental_summary(
    cheapest_bought INTEGER,
    budget_bought INTEGER,
    expensive_bought INTEGER
);
--/////////////////////////////////////////////////////////////////////////////--
-- D Complex query to extract data, for the detailed table 'rental_details'.
    INSERT INTO rental_details(
---- fields or columns from 'rental'----
    rental_id,
    rental_date,
    return_date,
---- fields or columns from 'payment' ----
    customer_id,
    amount,
    payment_date
)

---- selecting fields to load into detailed table ----
SELECT 
rnt.rental_id, rnt.rental_date, rnt.return_date,
pay.customer_id, pay.amount, pay.payment_date

FROM rental AS rnt

---- extracting data from both 'rental' and 'payment' tables ----
INNER JOIN payment AS pay 
ON rnt.customer_id = pay.customer_id
ORDER BY rental_id;

---- displaying table ----
SELECT *
FROM rental_details;


--/////////////////////////////////////////////////////////////////////////////--
-- E Trigger created to continually update summary table 'rental_summary'.

---- creating function to call with trigger ----
CREATE OR REPLACE FUNCTION refresh_rental_summary_func() 
    RETURNS TRIGGER AS
$$

BEGIN 
---- calls function from section F to rebuild summary table ----
    CALL rebuild_rental_summary();
RETURN NULL;
END;
$$
LANGUAGE 'plpgsql';

---- creating trigger, it will activate any time the INSERT transaction is used ----
CREATE TRIGGER rebuild_rental_summary_trigger
    AFTER INSERT
    ON "rental_summary"
    FOR EACH ROW
    EXECUTE PROCEDURE refresh_rental_summary_func();


--/////////////////////////////////////////////////////////////////////////////--
-- F Stored Procedures that refresh data in both the detailed and summary tables

---- refreshing detailed table 'rental_details' ----
CREATE OR REPLACE PROCEDURE rebuild_rental_details()
LANGUAGE SQL
AS $$

DELETE FROM rental_details; -- clears old data from table

---- extracting new data from both 'rental' and 'payment' tables to update detailed table ----
INSERT INTO rental_details(
    rental_id,
    rental_date,
    return_date,
    customer_id,
    amount,
    payment_date)

SELECT
rnt.rental_id, rnt.rental_date, rnt.return_date,
pay.customer_id, pay.amount, pay.payment_date

FROM rental AS rnt
INNER JOIN payment AS pay
ON rnt.customer_id = pay.customer_id
ORDER BY rental_id;
$$;

---- refreshing summary table 'rental_summary' ----
CREATE OR REPLACE PROCEDURE rebuild_rental_summary()
LANGUAGE SQL
AS $$

DELETE FROM rental_summary; -- clears all old data from table

---- extracting new data from 'rental_details' table ----
INSERT INTO rental_summary( 
    cheapest_bought,
    budget_bought,
    expensive_bought)


SELECT price_aggregator(amount, 0.00, 5.00) AS cheapest_sold,
price_aggregator(amount, 5.00, 20.00) AS budget_sold,
price_aggregator(amount, 10.00, 25.00) AS expensive_sold
FROM rental_details;
$$;

---- F rebuilding BOTH tables ----
CREATE OR REPLACE PROCEDURE rebuild_tables()
LANGUAGE SQL
AS
$$

DELETE FROM rental_details;
DELETE FROM rental_summary;

CALL rebuild_rental_details();
CALL rebuild_rental_summary();
$$;
