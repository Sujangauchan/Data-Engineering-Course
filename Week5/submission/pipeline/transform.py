import logging

logger = logging.getLogger(__name__)


def load_lookup_dim(conn):
    logger.info("Loading lookup table into memory")
    lookup = {}

    with conn.cursor() as curr:
        curr.execute("SELECT driver_id, driver_key FROM dim_driver")
        lookup["driver"] = {r[0]: r[1] for r in curr.fetchall()}

        curr.execute("SELECT passenger_id, passenger_key FROM dim_passenger")
        lookup["passenger"] = {r[0]: r[1] for r in curr.fetchall()}

        curr.execute("SELECT location_id, location_key FROM dim_location")
        lookup["location"] = {r[0]: r[1] for r in curr.fetchall()}

        curr.execute("SELECT payment_method_id, payment_method_key FROM dim_payment_method")
        lookup["payment_method"] = {r[0]: r[1] for r in curr.fetchall()}

        curr.execute("SELECT vehicle_id, vehicle_key FROM dim_vehicle")
        lookup["vehicle"] = {r[0]: r[1] for r in curr.fetchall()}

        curr.execute("SELECT promo_code_id, promo_code_key FROM dim_promo_code")
        lookup["promo_code"] = {r[0]: r[1] for r in curr.fetchall()}

        curr.execute("SELECT time_key FROM dim_time")
        lookup["time"] = {r[0]: True for r in curr.fetchall()}

        curr.execute("SELECT date_key FROM dim_date")
        lookup["date"] = {r[0]: True for r in curr.fetchall()}

    return lookup


def transform(oltp_rows, lookups):
    fact_rows = []
    skipped = 0

    for row in oltp_rows:
        trip_id = row["trip_id"]

        date_key = int(row["requested_at"].strftime("%Y%m%d"))
        if date_key not in lookups["date"]:
            logger.warning(f"trip {trip_id}: date_key {date_key} outside of dim_date range — skipped")
            skipped += 1
            continue

        time_key = (row["requested_at"].hour * 100) + (row["requested_at"].minute // 15) * 15
        if time_key not in lookups["time"]:
            logger.warning(f"trip {trip_id}: time_key {time_key} outside of dim_time range — skipped")
            skipped += 1
            continue

        driver_key = lookups["driver"].get(row["driver_id"])
        if driver_key is None:
            logger.warning(f"trip {trip_id}: driver_id {row['driver_id']} not in dim_driver — skipped")
            skipped += 1
            continue

        passenger_key = lookups["passenger"].get(row["passenger_id"])
        if passenger_key is None:
            logger.warning(f"trip {trip_id}: passenger_id {row['passenger_id']} not in dim_passenger — skipped")
            skipped += 1
            continue

        vehicle_key = lookups["vehicle"].get(row["vehicle_id"])
        if vehicle_key is None:
            logger.warning(f"trip {trip_id}: vehicle_id {row['vehicle_id']} not in dim_vehicle — skipped")
            skipped += 1
            continue

        pickup_location_key = lookups["location"].get(row["pickup_location_id"])
        if pickup_location_key is None:
            logger.warning(f"trip {trip_id}: pickup_location_id {row['pickup_location_id']} not in dim_location — skipped")
            skipped += 1
            continue

        dropoff_location_key = lookups["location"].get(row["dropoff_location_id"])
        if dropoff_location_key is None:
            logger.warning(f"trip {trip_id}: dropoff_location_id {row['dropoff_location_id']} not in dim_location — skipped")
            skipped += 1
            continue

        payment_method_key = None
        if row["payment_method_id"] is not None:
            payment_method_key = lookups["payment_method"].get(row["payment_method_id"])
            if payment_method_key is None:
                logger.warning(f"trip {trip_id}: payment_method_id {row['payment_method_id']} not in dim_payment_method — skipped")
                skipped += 1
                continue

        promo_code_key = None
        if row["promo_code_id"] is not None:
            promo_code_key = lookups["promo_code"].get(row["promo_code_id"])
            if promo_code_key is None:
                logger.warning(f"trip {trip_id}: promo_code_id {row['promo_code_id']} not in dim_promo_code — skipped")
                skipped += 1
                continue

        base_fare = row['base_fare'] or 0
        tip_amount = row["tip_amount"] or 0
        surge_multiplier = row["surge_multiplier"] or 0
        discount_amount = row["discount_amount"] or 0
        fare_amount = round(base_fare * surge_multiplier + tip_amount - discount_amount, 2)

        duration_minutes = None
        if row["status"] == "completed" and row["completed_at"]:
            delta = row["completed_at"] - row["requested_at"]
            duration_minutes = round(delta.total_seconds() / 60, 1)

        fact_rows.append({
            "source_trip_id":       trip_id,
            "date_key":             date_key,
            "time_key":             time_key,
            "driver_key":           driver_key,
            "passenger_key":        passenger_key,
            "vehicle_key":          vehicle_key,
            "pickup_location_key":  pickup_location_key,
            "dropoff_location_key": dropoff_location_key,
            "payment_method_key":   payment_method_key,
            "promo_code_key":       promo_code_key,
            "base_fare":            base_fare,
            "tip_amount":           tip_amount,
            "discount_amount":      discount_amount,
            "fare_amount":          fare_amount,
            "distance_km":          row["distance_km"],
            "status":               row["status"],
            "duration_minutes":     duration_minutes,
            "driver_rating":        row["driver_rating"],
            "passenger_rating":     row["passenger_rating"],
            "surge_multiplier":     surge_multiplier,
            "requested_at":         row["requested_at"],
        })

    logger.info(f"Transformed {len(fact_rows)} rows, skipped {skipped}")
    return fact_rows
