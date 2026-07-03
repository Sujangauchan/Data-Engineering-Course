
-- Normalizing the original rides table into seperate tables (drivers, locations, passengers, payment_methods and trips)


-- Dropping all tables excluding the original rides table


DROP TABLE IF EXISTS trips;

DROP TABLE IF EXISTS drivers;

DROP TABLE IF EXISTS passengers;

DROP TABLE IF EXISTS locations;

DROP TABLE IF EXISTS payment_methods ;



-- First creating raw tables which will be later populated based on data/values in rides table


-- Locations

CREATE TABLE locations (
    location_id SERIAL PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL UNIQUE
);


-- Drivers

CREATE TABLE drivers (
    driver_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);


-- Passengers

CREATE TABLE passengers (
    passenger_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);


-- Payment methods

CREATE TABLE payment_methods (
	payment_method_id SERIAL PRIMARY KEY,
	name VARCHAR(30) NOT NULL UNIQUE 
);


-- Trips

CREATE TABLE  trips (
	trip_id serial PRIMARY KEY,
	driver_id integer NOT NULL REFERENCES drivers(driver_id),
	passenger_id integer NOT NULL REFERENCES passengers(passenger_id),
	pickup_id integer NOT NULL REFERENCES locations(location_id),
	dropoff_id integer NOT NULL REFERENCES locations(location_id),
	fare_amount NUMERIC (10,2) NOT NULL CHECK (fare_amount > 0),
	distance_km  NUMERIC (10,2) NOT NULL CHECK (distance_km > 0),
	status varchar(50) CHECK (status IN ('no_show', 'cancelled', 'completed')),
	requested_at timestamp NOT NULL,
	completed_at timestamp,                                                     -- NULL if ride was not completed
	rating numeric(2,1) CHECK (rating BETWEEN 1.0 AND 5.0),                     -- NULL if rider did not rate
	payment_id integer REFERENCES payment_methods(payment_method_id)            -- NULL for some cancelled rides
);


---------------------------------- Table Creation Completed -------------------------------------------------

-- Insertion steps

-- Insert into drivers table

INSERT
	INTO
	drivers(name)
SELECT
	DISTINCT initcap(trim(regexp_replace(r.driver_name, '\s+', ' ', 'g')))
FROM
	rides r ;


-- Insert into passengers table

INSERT
	INTO
	passengers(name)
SELECT
	DISTINCT initcap(trim(regexp_replace(r.passenger_name , '\s+', ' ', 'g')))
FROM
	rides r ;


-- Insert into locations table

INSERT
	INTO
	locations(city_name)
SELECT
	DISTINCT initcap(trim(regexp_replace(r.pickup_city , '\s+', ' ', 'g')))
FROM
	rides r
UNION                                                      ---- UNION used instead of UNION ALL to avoid duplicate values
SELECT
	DISTINCT initcap(trim(regexp_replace(r.dropoff_city , '\s+', ' ', 'g')))
FROM
	rides r ;


-- Insert into payment_methods table

INSERT
	INTO
	payment_methods(name)
SELECT
	DISTINCT INITCAP(TRIM(REGEXP_REPLACE(payment_method, '\s+', ' ', 'g')))
FROM
	rides
WHERE
	payment_method IS NOT NULL
	AND payment_method <> '' ;


-- Insert into trips table

INSERT
	INTO
	trips(
	driver_id,
	passenger_id,
	pickup_id,
	dropoff_id,
	fare_amount,
	distance_km,
	status,
	requested_at,
	completed_at,
	rating,
	payment_id
)
SELECT
	d.driver_id,
	p.passenger_id,
	pl.location_id AS pickup_id,
	dl.location_id AS dropoff_id,
	r.fare_amount,
	r.ride_distance_km ,
	r.ride_status,
	r.requested_at,
	r.completed_at ,
	r.rating,
	pm.payment_method_id
FROM
	rides r
INNER JOIN drivers d ON
	d.name = INITCAP(TRIM(REGEXP_REPLACE(r.driver_name, '\s+', ' ', 'g')))
INNER JOIN passengers p ON
	p.name = INITCAP(TRIM(REGEXP_REPLACE(r.passenger_name, '\s+', ' ', 'g')))
INNER JOIN locations pl ON
	pl.city_name = INITCAP(TRIM(REGEXP_REPLACE(r.pickup_city, '\s+', ' ', 'g')))
LEFT JOIN locations dl ON
	dl.city_name = INITCAP(TRIM(REGEXP_REPLACE(r.dropoff_city, '\s+', ' ', 'g')))
LEFT JOIN payment_methods pm ON
	pm.name = INITCAP(TRIM(REGEXP_REPLACE(r.payment_method, '\s+', ' ', 'g')))
ORDER BY
	r.ride_id;

---------------------------------- Data Insertion Completed -------------------------------------------------


-- Final validation

SELECT count(*) FROM rides;

SELECT count(*) FROM trips;

SELECT * FROM rides;

SELECT * FROM trips;

