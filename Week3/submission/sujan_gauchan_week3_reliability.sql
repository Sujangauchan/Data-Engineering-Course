

-------- Adding indexes on 3 queries and measuring their execution time before vs after indexing --------


----------------------------------            Query 1              --------------------------------------

----------------------------------    Query Plan before indexing   --------------------------------------

EXPLAIN ANALYSE
SELECT 
	d.name AS "driver name",
	p.name AS "passenger name",
	t.completed_at-t.requested_at AS "total trip duration",
	t.*
FROM trips t 
INNER JOIN drivers d ON t.driver_id = d.driver_id
INNER JOIN passengers p ON t.passenger_id = p.passenger_id
WHERE d.driver_id = 3;

--Nested Loop  (cost=0.30..158.21 rows=481 width=519) (actual time=0.091..2.025 rows=481.00 loops=1)
--  Buffers: shared hit=106
--  ->  Nested Loop  (cost=0.15..139.48 rows=481 width=285) (actual time=0.049..1.338 rows=481.00 loops=1)
--        Buffers: shared hit=66
--        ->  Index Scan using drivers_pkey on drivers d  (cost=0.15..8.17 rows=1 width=222) (actual time=0.026..0.030 rows=1.00 loops=1)
--              Index Cond: (driver_id = 3)
--              Index Searches: 1
--              Buffers: shared hit=2
--        ->  Seq Scan on trips t  (cost=0.00..126.50 rows=481 width=67) (actual time=0.018..1.059 rows=481.00 loops=1)
--              Filter: (driver_id = 3)
--              Rows Removed by Filter: 4519
--              Buffers: shared hit=64
--  ->  Memoize  (cost=0.16..0.27 rows=1 width=222) (actual time=0.001..0.001 rows=1.00 loops=481)
--        Cache Key: t.passenger_id
--        Cache Mode: logical
--        Hits: 461  Misses: 20  Evictions: 0  Overflows: 0  Memory Usage: 3kB
--        Buffers: shared hit=40
--        ->  Index Scan using passengers_pkey on passengers p  (cost=0.15..0.26 rows=1 width=222) (actual time=0.003..0.003 rows=1.00 loops=20)
--              Index Cond: (passenger_id = t.passenger_id)
--              Index Searches: 20
--              Buffers: shared hit=40
--Planning Time: 0.296 ms
--Execution Time: 2.149 ms


----------------------------------    Query Plan after indexing   --------------------------------------

create INDEX idx_trip_driver_id
ON trips(driver_id);


EXPLAIN ANALYSE
SELECT 
	d.name AS "driver name",
	p.name AS "passenger name",
	t.completed_at-t.requested_at AS "total trip duration",
	t.*
FROM trips t 
INNER JOIN drivers d ON t.driver_id = d.driver_id
INNER JOIN passengers p ON t.passenger_id = p.passenger_id
WHERE d.driver_id = 3;


--Nested Loop  (cost=8.32..109.73 rows=481 width=519) (actual time=0.085..0.778 rows=481.00 loops=1)
--  Buffers: shared hit=109
--  ->  Nested Loop  (cost=8.16..91.00 rows=481 width=285) (actual time=0.072..0.472 rows=481.00 loops=1)
--        Buffers: shared hit=69
--        ->  Index Scan using drivers_pkey on drivers d  (cost=0.15..8.17 rows=1 width=222) (actual time=0.019..0.020 rows=1.00 loops=1)
--              Index Cond: (driver_id = 3)
--              Index Searches: 1
--              Buffers: shared hit=2
--        ->  Bitmap Heap Scan on trips t  (cost=8.01..78.02 rows=481 width=67) (actual time=0.048..0.276 rows=481.00 loops=1)
--              Recheck Cond: (driver_id = 3)
--              Heap Blocks: exact=64
--              Buffers: shared hit=67
--              ->  Bitmap Index Scan on idx_trip_driver_id  (cost=0.00..7.89 rows=481 width=0) (actual time=0.028..0.028 rows=481.00 loops=1)
--                    Index Cond: (driver_id = 3)
--                    Index Searches: 1
--                    Buffers: shared hit=3
--  ->  Memoize  (cost=0.16..0.27 rows=1 width=222) (actual time=0.000..0.000 rows=1.00 loops=481)
--        Cache Key: t.passenger_id
--        Cache Mode: logical
--        Hits: 461  Misses: 20  Evictions: 0  Overflows: 0  Memory Usage: 3kB
--        Buffers: shared hit=40
--        ->  Index Scan using passengers_pkey on passengers p  (cost=0.15..0.26 rows=1 width=222) (actual time=0.001..0.001 rows=1.00 loops=20)
--              Index Cond: (passenger_id = t.passenger_id)
--              Index Searches: 20
--              Buffers: shared hit=40
--Planning Time: 0.226 ms
--Execution Time: 0.846 ms


DROP INDEX idx_trip_driver;



----------------------------------                 Query 2                --------------------------------------

----------------------------------    Query Plan result before indexing   --------------------------------------


EXPLAIN ANALYSE
SELECT 
	d.name AS "driver name",
	p.name AS "payment method",
	round(t.fare_amount,2) "total collected fare",
	t.*
FROM trips t INNER JOIN drivers d ON t.driver_id = d.driver_id
INNER JOIN payment_methods p ON t.payment_id = p.payment_method_id
WHERE t.status = 'completed'
ORDER BY "total collected fare" desc;



--Sort  (cost=356.99..364.15 rows=2862 width=395) (actual time=9.656..9.834 rows=2862.00 loops=1)
--  Sort Key: (round(t.fare_amount, 2)) DESC
--  Sort Method: quicksort  Memory: 432kB
--  Buffers: shared hit=66
--  ->  Hash Join  (cost=43.85..192.68 rows=2862 width=395) (actual time=0.116..6.648 rows=2862.00 loops=1)
--        Hash Cond: (t.payment_id = p.payment_method_id)
--        Buffers: shared hit=66
--        ->  Hash Join  (cost=17.20..151.31 rows=2862 width=285) (actual time=0.081..4.158 rows=2862.00 loops=1)
--              Hash Cond: (t.driver_id = d.driver_id)
--              Buffers: shared hit=65
--              ->  Seq Scan on trips t  (cost=0.00..126.50 rows=2862 width=67) (actual time=0.036..2.059 rows=2862.00 loops=1)
--                    Filter: ((status)::text = 'completed'::text)
--                    Rows Removed by Filter: 2138
--                    Buffers: shared hit=64
--              ->  Hash  (cost=13.20..13.20 rows=320 width=222) (actual time=0.033..0.034 rows=11.00 loops=1)
--                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
--                    Buffers: shared hit=1
--                    ->  Seq Scan on drivers d  (cost=0.00..13.20 rows=320 width=222) (actual time=0.019..0.023 rows=11.00 loops=1)
--                          Buffers: shared hit=1
--        ->  Hash  (cost=17.40..17.40 rows=740 width=82) (actual time=0.022..0.022 rows=5.00 loops=1)
--              Buckets: 1024  Batches: 1  Memory Usage: 9kB
--              Buffers: shared hit=1
--              ->  Seq Scan on payment_methods p  (cost=0.00..17.40 rows=740 width=82) (actual time=0.015..0.017 rows=5.00 loops=1)
--                    Buffers: shared hit=1
--Planning Time: 0.408 ms
--Execution Time: 10.061 ms



----------------------------------    Query Plan result after indexing   --------------------------------------

CREATE INDEX idx_status_payment_driver
ON trips(status,payment_id,driver_id);


EXPLAIN ANALYSE
SELECT 
	d.name AS "driver name",
	p.name AS "payment method",
	round(t.fare_amount,2) "total collected fare",
	t.*
FROM trips t INNER JOIN drivers d ON t.driver_id = d.driver_id
INNER JOIN payment_methods p ON t.payment_id = p.payment_method_id
WHERE t.status = 'completed'
ORDER BY "total collected fare" desc;


--Sort  (cost=356.99..364.15 rows=2862 width=395) (actual time=6.941..7.219 rows=2862.00 loops=1)
--  Sort Key: (round(t.fare_amount, 2)) DESC
--  Sort Method: quicksort  Memory: 432kB
--  Buffers: shared hit=66
--  ->  Hash Join  (cost=43.85..192.68 rows=2862 width=395) (actual time=0.072..4.425 rows=2862.00 loops=1)
--        Hash Cond: (t.payment_id = p.payment_method_id)
--        Buffers: shared hit=66
--        ->  Hash Join  (cost=17.20..151.31 rows=2862 width=285) (actual time=0.053..2.726 rows=2862.00 loops=1)
--              Hash Cond: (t.driver_id = d.driver_id)
--              Buffers: shared hit=65
--              ->  Seq Scan on trips t  (cost=0.00..126.50 rows=2862 width=67) (actual time=0.019..1.341 rows=2862.00 loops=1)
--                    Filter: ((status)::text = 'completed'::text)
--                    Rows Removed by Filter: 2138
--                    Buffers: shared hit=64
--              ->  Hash  (cost=13.20..13.20 rows=320 width=222) (actual time=0.024..0.025 rows=11.00 loops=1)
--                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
--                    Buffers: shared hit=1
--                    ->  Seq Scan on drivers d  (cost=0.00..13.20 rows=320 width=222) (actual time=0.006..0.008 rows=11.00 loops=1)
--                          Buffers: shared hit=1
--        ->  Hash  (cost=17.40..17.40 rows=740 width=82) (actual time=0.009..0.009 rows=5.00 loops=1)
--              Buckets: 1024  Batches: 1  Memory Usage: 9kB
--              Buffers: shared hit=1
--              ->  Seq Scan on payment_methods p  (cost=0.00..17.40 rows=740 width=82) (actual time=0.004..0.005 rows=5.00 loops=1)
--                    Buffers: shared hit=1
--Planning Time: 0.349 ms
--Execution Time: 7.529 ms


DROP INDEX idx_status_payment_driver;


----------------------------------                 Query 3                --------------------------------------

----------------------------------    Query Plan result before indexing   --------------------------------------


EXPLAIN ANALYSE
SELECT 
	*
FROM trips t
WHERE t.fare_amount = 300;



--Seq Scan on trips t  (cost=0.00..126.50 rows=55 width=67) (actual time=0.017..1.670 rows=55.00 loops=1)
--  Filter: (fare_amount = '300'::numeric)
--  Rows Removed by Filter: 4945
--  Buffers: shared hit=64
--Planning:
--  Buffers: shared hit=5
--Planning Time: 0.450 ms
--Execution Time: 1.696 ms

----------------------------------    Query Plan result after indexing   --------------------------------------

CREATE INDEX idx_trip_fare
ON trips(fare_amount);


EXPLAIN ANALYSE
SELECT 
	*
FROM trips t
WHERE t.fare_amount = 300;


--Bitmap Heap Scan on trips t  (cost=4.71..70.06 rows=55 width=67) (actual time=0.058..0.109 rows=55.00 loops=1)
--  Recheck Cond: (fare_amount = '300'::numeric)
--  Heap Blocks: exact=41
--  Buffers: shared hit=41 read=2
--  ->  Bitmap Index Scan on idx_fare  (cost=0.00..4.69 rows=55 width=0) (actual time=0.043..0.043 rows=55.00 loops=1)
--        Index Cond: (fare_amount = '300'::numeric)
--        Index Searches: 1
--        Buffers: shared read=2
--Planning:
--  Buffers: shared hit=15 read=1
--Planning Time: 0.413 ms
--Execution Time: 0.130 ms


DROP INDEX idx_trip_fare;


----------------------------------             KEY TAKEAWAYS             --------------------------------------

--- Execution Time for query 1 lowered by 60.63% from 2.149 ms to 0.846 ms after indexing
--- Execution time for query 2 lowered by 25.16% from 10.061 ms to 7.529 ms
--- Execution Time for query 3 lowered by 92.34% from 1.696 ms to 0.130 ms
--- Query 2 had almost no benefit from indexing due to following reasons:
--- Query 2's filter column (status) had low cardinality (only 3 category values)
--- Also the matched value 'completed' represented more than half of all rows therefore sql just ran a normal sequential scan




----------------------------------- Creating views for completed trips -----------------------------------------


CREATE VIEW completed_trips AS
SELECT
	d.name AS driver_name,
	p.name AS passenger_name,
	pck.city_name AS pickup_location,
	drp.city_name AS dropoff_location,
	t.fare_amount,
	t.distance_km,
	t.status,
	t.requested_at,
	t.completed_at,
	t.rating,
	pm.name AS payment_method
FROM
	trips t
INNER JOIN drivers d 
ON t.driver_id = d.driver_id
INNER JOIN passengers p 
ON t.passenger_id = p.passenger_id
INNER JOIN locations pck
ON t.pickup_id = pck.location_id
INNER JOIN locations drp
ON t.dropoff_id = drp.location_id
LEFT JOIN payment_methods pm 
ON pm.payment_method_id = t.payment_id;



----------------------------------- Creating views for driver summary -----------------------------------------


CREATE VIEW driver_summary AS
SELECT
	d.name AS driver_name,
	count (t.trip_id) AS total_rides,
	count (CASE WHEN t.status = 'completed' THEN 1 ELSE NULL END) AS completed_rides,   --- interchangable with filter
	count (t.trip_id) FILTER (WHERE t.status = 'cancelled') AS cancelled_rides,         --- interchangable with case when
	concat(round((count (CASE WHEN t.status = 'cancelled' THEN t.trip_id ELSE NULL END)* 100.0 / NULLIF(COUNT(t.trip_id), 0)), 2), '%') AS cancellation_rate,
	round(avg (fare_amount), 2) AS avg_fare,
	round(avg (rating), 2) AS avg_rating
FROM
	drivers d
left JOIN  trips t
ON
	t.driver_id = d.driver_id
GROUP BY
	d.driver_id,
	driver_name
ORDER BY total_rides desc;                     --- group by driver_id to avoid merging drivers having same name

	
	
----------------------------------- Ensuring atomicity during data insertion  -----------------------------------------	


-- Inserting data into tables with valid values that doesnot violate any database constraint


BEGIN;


-- Inserting a new driver 


INSERT INTO drivers (name)
VALUES('Bishal Rijal');


-- Inserting values in trip from the new driver 


INSERT INTO trips (driver_id, passenger_id, pickup_id,
                     dropoff_id, fare_amount, distance_km,
                     status, requested_at, rating)                  
VALUES ((SELECT driver_id FROM drivers WHERE name = 'Bishal Rijal'), 4, 3, 2, 167.00, 6, 'completed', '2024-01-04 01:03:53.000', 3);



INSERT INTO trips (driver_id, passenger_id, pickup_id,
                     dropoff_id, fare_amount, distance_km,
                     status, requested_at, rating) 
VALUES ((SELECT driver_id FROM drivers WHERE name = 'Bishal Rijal'), 3, 2, 1, 311.00, 12, 'completed', '2024-12-24 19:52:17.000', 1);



INSERT INTO trips (driver_id, passenger_id, pickup_id,
                     dropoff_id, fare_amount, distance_km,
                     status, requested_at, rating) 
VALUES ((SELECT driver_id FROM drivers WHERE name = 'Bishal Rijal'), 7, 2, 2, 211.00, 5, 'cancelled', '2024-06-04 10:13:02.000', 2);


  
SELECT count(*) FROM trips t;
  

COMMIT;


--- New driver and 3 valid trips added successfully with 5003 total trip counts


--- Dropping the new rows and values and retrying with multiple rows where a row value violates table field constraint


DELETE FROM drivers WHERE name = 'Bishal Rijal';

DELETE FROM TRIPS WHERE trip_id > 5000;


-- Inserting again with 1 additional row containing invalid value (rating of 99)


BEGIN;


-- Inserting a new driver 


INSERT INTO drivers (name)
VALUES('Bishal Rijal');



-- Inserting values in trip from the new driver 


INSERT INTO trips (driver_id, passenger_id, pickup_id,
                     dropoff_id, fare_amount, distance_km,
                     status, requested_at, rating)                  
VALUES ((SELECT driver_id FROM drivers WHERE name = 'Bishal Rijal'), 4, 3, 2, 167.00, 6, 'completed', '2024-01-04 01:03:53.000', 3);



INSERT INTO trips (driver_id, passenger_id, pickup_id,
                     dropoff_id, fare_amount, distance_km,
                     status, requested_at, rating) 
VALUES ((SELECT driver_id FROM drivers WHERE name = 'Bishal Rijal'), 3, 2, 1, 311.00, 12, 'completed', '2024-12-24 19:52:17.000', 1);



INSERT INTO trips (driver_id, passenger_id, pickup_id,
                     dropoff_id, fare_amount, distance_km,
                     status, requested_at, rating) 
VALUES ((SELECT driver_id FROM drivers WHERE name = 'Bishal Rijal'), 7, 2, 2, 211.00, 5, 'cancelled', '2024-06-04 10:13:02.000', 2);


INSERT INTO trips (driver_id, passenger_id, pickup_id,
                     dropoff_id, fare_amount, distance_km,
                     status, requested_at, rating) 
VALUES ((SELECT driver_id FROM drivers WHERE name = 'Bishal Rijal'), 5, 1, 2, 234.00, 5, 'completed', '2024-06-04 10:13:02.000', 99);

  
SELECT count(*) FROM trips t;
  

COMMIT;




--- Verification query


SELECT count(*) FROM trips t WHERE t.trip_id > 5000;           -- 0 count, not a single row from the 4 rows were inserted

SELECT count(*) FROM drivers d  WHERE name = 'Bishal Rijal';   -- 0 Count, driver was not added


--- Attempt in adding a row with rating of 99 gives the error: (SQL Error [22003]: ERROR: numeric field overflow
    -- Detail: A field with precision 2, scale 1 must round to an absolute value less than 10^1.)



	
--------------    Completed trips running total calculation per drivers using window function   ----------------


SELECT
	t.trip_id,
	d.name AS driver_name ,
	t.fare_amount,
	SUM(CASE WHEN t.status = 'completed' THEN t.fare_amount ELSE 0 END) OVER (PARTITION BY t.driver_id ORDER BY
	requested_at) AS running_total,
	status,
	requested_at,
	pm.name AS payment_method
FROM
	trips t
INNER JOIN drivers d 
ON
	t.driver_id = d.driver_id
LEFT JOIN payment_methods pm
ON
	t.payment_id = pm.payment_method_id;



