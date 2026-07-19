
-- For the pipeline log tests we will load bad data into the trips table to test the pipeline's ability to handle invalid records.

-- removing the check constraint to load faulty trip records

ALTER TABLE trips
DROP CONSTRAINT trips_status_check;

--Inserting trips that fail check constraint into the prod db trip table

INSERT INTO trips (
    driver_id, passenger_id, vehicle_id, pickup_location_id, 
    dropoff_location_id, payment_method_id, promo_code_id, base_fare, 
    tip_amount, discount_amount, surge_multiplier, distance_km, status, 
    requested_at, completed_at, driver_rating, passenger_rating
) VALUES
(5, 28, 6, 15, 24, 7, NULL, 25.50, 0.00, 0.00, 1.25, 12.75, 'Complete', '2026-07-15 10:30:00.000', '2026-07-15 11:15:00.000', 4.0, 4.5),
(8, 30, 19, 9, 16, 1, NULL, 45.20, 5.00, 0.00, 1.75, 35.80, 'completedd', '2026-07-14 14:20:00.000', '2026-07-14 16:00:00.000', 3.5, 4.0),
(7, 6, 8, 1, 18, 5, NULL, 32.00, 2.50, 0.00, 1.00, 20.15, 'comp', '2026-07-13 08:45:00.000', '2026-07-13 09:30:00.000', 4.0, 5.0),
(16, 36, 17, 19, 12, 6, NULL, 18.75, 0.00, 0.00, 1.00, 12.30, 'Cancelled', '2026-07-12 22:10:00.000', NULL, NULL, NULL),
(2, 11, 26, 5, 3, 7, NULL, 67.80, 8.00, 0.00, 2.00, 48.50, 'no show', '2026-07-11 17:30:00.000', NULL, NULL, NULL),
(4, 14, 21, 20, 25, 1, NULL, 52.40, 3.75, 0.00, 1.50, 32.90, '', '2026-07-10 12:15:00.000', '2026-07-10 14:00:00.000', 4.5, 4.0),
(3, 44, 8, 23, 15, 3, NULL, 15.30, 0.00, 0.00, 1.00, 8.75, 'complete', '2026-07-09 06:50:00.000', '2026-07-09 07:20:00.000', 3.0, 4.0),
(24, 21, 20, 2, 15, 5, NULL, 88.60, 10.25, 0.00, 1.00, 62.40, 'COMPLETED', '2026-07-08 19:05:00.000', '2026-07-08 21:45:00.000', 5.0, 4.5),
(13, 28, 21, 9, 6, 4, 5, 41.00, 6.00, 5.00, 1.75, 28.30, 'no_showw', '2026-07-07 11:20:00.000', NULL, NULL, NULL),
(25, 4, 7, 21, 15, 4, 9, 29.50, 4.25, 10.00, 1.75, 18.90, 'cancel', '2026-07-06 16:40:00.000', NULL, NULL, NULL);

-- Checking the new records

SELECT * FROM trips ORDER BY trip_id DESC;


-- Clean up and remove test data

DELETE FROM trips WHERE trip_id > 10000;


-- Verifying no invalid statuses remain

SELECT COUNT(*) FROM trips 
WHERE status NOT IN ('completed', 'cancelled', 'no_show');


-- Re-adding the constraint

ALTER TABLE trips 
ADD CONSTRAINT trips_status_check 
CHECK (status IN ('completed', 'cancelled', 'no_show'));


-- Now adding valid rows

INSERT INTO trips (
    driver_id, passenger_id, vehicle_id, pickup_location_id, 
    dropoff_location_id, payment_method_id, promo_code_id, base_fare, 
    tip_amount, discount_amount, surge_multiplier, distance_km, status, 
    requested_at, completed_at, driver_rating, passenger_rating
) VALUES
(1, 28, 6, 15, 24, 7, NULL, 25.50, 3.00, 0.00, 1.25, 12.75, 'completed', '2026-07-15 10:30:00.000', '2026-07-15 11:15:00.000', 4.5, 4.5),
(2, 30, 19, 9, 16, 1, NULL, 45.20, 5.00, 0.00, 1.75, 35.80, 'completed', '2026-07-14 14:20:00.000', '2026-07-14 16:00:00.000', 4.0, 4.0),
(3, 6, 8, 1, 18, 5, NULL, 32.00, 2.50, 0.00, 1.00, 20.15, 'completed', '2026-07-13 08:45:00.000', '2026-07-13 09:30:00.000', 4.0, 5.0),
(4, 36, 17, 19, 12, 6, NULL, 18.75, 0.00, 0.00, 1.00, 12.30, 'cancelled', '2026-07-12 22:10:00.000', NULL, NULL, NULL),
(5, 11, 26, 5, 3, 7, NULL, 67.80, 8.00, 0.00, 2.00, 48.50, 'no_show', '2026-07-11 17:30:00.000', NULL, NULL, NULL),
(6, 14, 21, 20, 25, 1, NULL, 52.40, 3.75, 0.00, 1.50, 32.90, 'completed', '2026-07-10 12:15:00.000', '2026-07-10 14:00:00.000', 4.5, 4.0),
(7, 44, 8, 23, 15, 3, NULL, 15.30, 0.00, 0.00, 1.00, 8.75, 'completed', '2026-07-09 06:50:00.000', '2026-07-09 07:20:00.000', 3.5, 4.0),
(8, 21, 20, 2, 15, 5, NULL, 88.60, 10.25, 0.00, 1.00, 62.40, 'completed', '2026-07-08 19:05:00.000', '2026-07-08 21:45:00.000', 5.0, 4.5),
(9, 28, 21, 9, 6, 4, 5, 41.00, 6.00, 5.00, 1.75, 28.30, 'completed', '2026-07-07 11:20:00.000', '2026-07-07 13:00:00.000', 4.5, 5.0),
(10, 4, 7, 21, 15, 4, 9, 29.50, 4.25, 10.00, 1.75, 18.90, 'completed', '2026-07-06 16:40:00.000', '2026-07-06 18:15:00.000', 4.0, 5.0);



SELECT * FROM trips ORDER BY trip_id DESC;