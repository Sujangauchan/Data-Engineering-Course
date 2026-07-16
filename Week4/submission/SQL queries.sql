-- TASK 3
-- Query to calculate total revenue grouped by pickup city and month on warehouse and production databases

-- 3.1 Warehouse database query

SELECT
	l.city_name "Pickup city",
	d.month_name "Month",
	sum(t.fare_amount) "Total revenue"
FROM
	fact_trips t
INNER JOIN dim_location l ON
	t.pickup_location_key = l.location_key
INNER JOIN dim_date d ON
	t.date_key = d.date_key
GROUP BY
	"Pickup city",
	"Month",
	d.month
ORDER BY
	"Pickup city",d.month ASC;

-- 3.2 Production/transactional database query

SELECT
	l.city_name AS "pickup city",
	TO_CHAR(requested_at, 'Month') AS "month",
	ROUND(SUM((t.base_fare * t.surge_multiplier) + t.tip_amount - t.discount_amount), 2) AS "Total revenue"
FROM
	trips t
INNER JOIN locations l ON
	t.pickup_location_id = l.location_id
GROUP BY
	"pickup city",
	"month",
	EXTRACT (MONTH FROM t.requested_at) --- month in number for month wise sorting
ORDER BY
	"pickup city",
	EXTRACT (MONTH FROM t.requested_at) ;

-- The query on the warehouse uses join with three tables fact_trips, dim_location and dim_date.
-- The query on the production database uses join with two tables trips and locations.
-- The warehouse query is more efficient as it uses pre-aggregated data in fact_trips and dimension tables, while the production query has to calculate revenue on the fly from raw data in trips table.


-- TASK 4

-- Query to calculate total revenue per payment method as well as average fare per trip, per payment method, per month.


-- 4.1 Total revenue per payment method (Warehouse database query)

SELECT
	pm.name AS "Payment method",
	sum(t.fare_amount)AS "Total revenue"
FROM
	fact_trips t
INNER JOIN dim_payment_method pm ON
	t.payment_method_key = pm.payment_method_key
GROUP BY
	"Payment method"
ORDER BY
	"Total revenue" DESC;


-- 4.2 Average fare per trip, per payment method, per month (Warehouse database query)

SELECT
	pm.name AS "Payment method",
	d.month_name AS "Month",
	AVG(t.fare_amount)AS "Avg fare per trip"
FROM
	fact_trips t
INNER JOIN dim_payment_method pm ON
	t.payment_method_key = pm.payment_method_key
INNER JOIN dim_date d ON
	t.date_key = d.date_key
GROUP BY
	"Payment method" ,
	MONTH,  --- month in number for month wise sorting
	"Month"
ORDER BY
	"Payment method",
	MONTH ASC;


-- 5 Busiest hour of day (Warehouse database query)

SELECT 
    EXTRACT(HOUR FROM requested_at) AS hour_of_day,
    COUNT(*) AS trip_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage_of_all_trips
FROM 
    fact_trips
GROUP BY 
    1
ORDER BY 
    hour_of_day;
