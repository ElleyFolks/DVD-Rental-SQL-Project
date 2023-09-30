-- B Function that transforms ___ identified in A4.
-- Transformation 3: Aggregation of total number of rentals bought within each price range
CREATE
OR REPLACE FUNCTION price_aggregator (amount NUMERIC(5, 2)) RETURNS VARCHAR LANGUAGE plpgsql AS $$
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

--/////////////////////////////////////////////////////////////////////////////--
-- C Creating empty detailed table.
DROP TABLE IF EXISTS rental_details;

CREATE TABLE IF NOT EXISTS
    rental_details (
        rental_id INTEGER,
        customer_id SMALLINT,
        amount NUMERIC(5, 2)
    );

-- C Creating empty summary table.
DROP TABLE IF EXISTS rental_summary;

CREATE TABLE IF NOT EXISTS
    rental_summary (
        customer_id SMALLINT,
        cheapest_bought INTEGER,
        budget_bought INTEGER,
        expensive_bought INTEGER
    );

--/////////////////////////////////////////////////////////////////////////////--
-- D Complex query to extract data, for the detailed table 'rental_details'.
INSERT INTO
    rental_details (
        ---- fields or columns from 'rental'----
        rental_id,
        ---- fields or columns from 'payment' ----
        customer_id,
        amount
    )
    ---- selecting fields to load into detailed table ----
SELECT
    rnt.rental_id,
    pay.customer_id,
    pay.amount
FROM
    rental AS rnt
    ---- extracting data from both 'rental' and 'payment' tables ----
    INNER JOIN payment AS pay ON rnt.rental_id = pay.rental_id
ORDER BY
    customer_id;

SELECT
    *
FROM
    rental_details;

--/////////////////////////////////////////////////////////////////////////////--
-- E Trigger created to continually update summary table 'rental_summary'.
---- creating function to call with trigger ----
CREATE
OR REPLACE FUNCTION refresh_rental_summary_func () RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN 
---- calls function from section F to rebuild summary table ----
    CALL rebuild_rental_summary();
RETURN NULL;
END;
$$;

---- creating trigger, it will activate any time the INSERT transaction is used ----
CREATE TRIGGER rebuild_rental_summary_trigger
AFTER INSERT ON rental_details FOR EACH STATEMENT
EXECUTE PROCEDURE refresh_rental_summary_func ();

--/////////////////////////////////////////////////////////////////////////////--
-- F Stored Procedures that refresh data in both the detailed and summary tables
---- refreshing detailed table 'rental_details' ----
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

---- refreshing summary table 'rental_summary' ----
CREATE
OR REPLACE PROCEDURE rebuild_rental_summary () LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM rental_summary;

INSERT INTO 
    rental_summary( 
        SELECT 
           customer_id,
           COUNT(case price_aggregator(amount) when 'cheap' then 1 end) as cheapest_bought,
           COUNT(case price_aggregator(amount) when 'budget' then 1 end) as budget_bought,
           COUNT(case price_aggregator(amount) when 'expensive' then 1 end) as expensive_bought
        FROM rental_details
        GROUP BY customer_id
		ORDER BY customer_id
    );
END;
$$;

---- F rebuilding BOTH tables ----
CREATE
OR REPLACE PROCEDURE rebuild_tables () LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM rental_details;
DELETE FROM rental_summary;

CALL rebuild_rental_details();
CALL rebuild_rental_summary();
END;
$$;