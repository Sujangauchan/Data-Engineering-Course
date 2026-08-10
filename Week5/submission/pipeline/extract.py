import os
import logging
from dotenv import load_dotenv
import psycopg2
from psycopg2 import sql
from psycopg2.extras import RealDictCursor

logger = logging.getLogger(__name__)

load_dotenv()

SOURCE_DB_CONFIG = dict(
    host=    os.getenv("SRC_DB_HOST"),
    port =   os.getenv("SRC_DB_PORT"),
    dbname = os.getenv("SRC_DB_NAME"),
    user=    os.getenv("SRC_DB_USER"),
    password=os.getenv("SRC_DB_PASSWORD")
)

DEST_DB_CONFIG = dict(
    host=    os.getenv("DEST_DB_HOST"),
    port =   os.getenv("DEST_DB_PORT"),
    dbname = os.getenv("DEST_DB_NAME"),
    user=    os.getenv("DEST_DB_USER"),
    password=os.getenv("DEST_DB_PASSWORD") 
)


def extract(conn, sql, params=None):
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as curr:
            curr.execute(sql, params)
            rows = curr.fetchall()
            logger.info(f"Extracted {len(rows)} rows")
        return rows
    except Exception as e:
        logger.error(str(e))
        raise


def extract_watermark(conn, table_name, date_column):
    query = f"""
        SELECT COALESCE(
            MAX({date_column}),
            '2000-01-01'::TIMESTAMP
        ) AS watermark
        FROM {table_name}
    """
    watermark = extract(conn, query)
    value = watermark[0]["watermark"] if watermark and watermark[0]["watermark"] is not None else None
    logger.info("Watermark for %s.%s: %s", table_name, date_column, value)
    return value


def extract_driver(conn, watermark=None):
    watermark_clause = ""
    params = None
    if watermark is not None:
        watermark_clause = " WHERE d.joined_at > %(watermark)s"
        params = {"watermark": watermark}

    extract_driver_sql = f"""
    SELECT
        driver_id ,
        name,
        status,
        joined_at,
        CASE
            WHEN joined_at >= NOW() - INTERVAL '6 months'  THEN '0-6 months'
            WHEN joined_at >= NOW() - INTERVAL '1 year'    THEN '6-12 months'
            WHEN joined_at >= NOW() - INTERVAL '2 years'   THEN '1-2 years'
        ELSE '2+ years'
        END  AS tenure_bucket
    FROM
        drivers d{watermark_clause};
    """
    return extract(conn, extract_driver_sql, params)


def extract_passenger(conn, watermark=None):
    watermark_clause = ""
    params = None
    if watermark is not None:
        watermark_clause = " WHERE p.created_at > %(watermark)s"
        params = {"watermark": watermark}

    extract_passenger_sql = f"""
    select
        passenger_id,
        name,
        status,
        created_at,
        TO_CHAR(created_at, 'YYYY-MM') AS cohort_month
    FROM
        passengers p{watermark_clause};
    """
    return extract(conn, extract_passenger_sql, params)


def extract_vehicle(conn):
    extract_vehicle_sql = """
    SELECT
        vehicle_id,
        plate_number,
        make,
        model,
        year,
        color,
        category,
        is_active
    FROM
        vehicles v;
    """
    return extract(conn, extract_vehicle_sql)


def extract_location(conn):
    extract_location_sql = """
    SELECT
        location_id,
        city_name,
        state_province,
        country,
        latitude,
        longitude,
        CASE
            WHEN country <> 'USA' THEN 'International'
            WHEN state_province IN (
                'Connecticut','Maine','Massachusetts','New Hampshire','New Jersey',
                'New York','Pennsylvania','Rhode Island','Vermont'
            ) THEN 'Northeast'
            WHEN state_province IN (
                'Illinois','Indiana','Iowa','Kansas','Michigan','Minnesota',
                'Missouri','Nebraska','North Dakota','Ohio','South Dakota','Wisconsin'
            ) THEN 'Midwest'
            WHEN state_province IN (
                'Alabama','Arkansas','Delaware','Florida','Georgia','Kentucky',
                'Louisiana','Maryland','Mississippi','North Carolina','Oklahoma',
                'South Carolina','Tennessee','Texas','Virginia','West Virginia'
            ) THEN 'South'
            WHEN state_province IN (
                'Alaska','Arizona','California','Colorado','Hawaii','Idaho',
                'Montana','Nevada','New Mexico','Oregon','Utah','Washington','Wyoming'
            ) THEN 'West'
            ELSE 'International'
        END AS region
    FROM
        locations l;
    """
    return extract(conn, extract_location_sql)


def extract_payment_method(conn):
    extract_payment_method_sql = """
    SELECT
        payment_method_id,
        name,
        type,
        is_active
    FROM
        payment_methods pm;
    """
    return extract(conn, extract_payment_method_sql)


def extract_promo_code(conn):
    extract_promo_code_sql = """
    SELECT
        promo_code_id,
        code,
        discount_type,
        discount_value,
        is_active
    FROM
        promo_codes pc;
    """
    return extract(conn, extract_promo_code_sql)


def extract_trips(conn, watermark):
    watermark_clause = ""
    params = None
    if watermark is not None:
        watermark_clause = " WHERE t.requested_at > %(watermark)s"
        params = {"watermark": watermark}

    extract_trip_sql = f"""
      SELECT
        t.trip_id,
        t.driver_id,
        t.vehicle_id,
        t.passenger_id,
        t.pickup_location_id,
        t.dropoff_location_id,
        t.payment_method_id,
        t.promo_code_id,
        t.base_fare,
        t.tip_amount,
        t.discount_amount,
        t.surge_multiplier,
        t.distance_km,
        t.status,
        t.requested_at,
        t.completed_at,
        t.driver_rating,
        t.passenger_rating,
        tc.cancelled_by
    FROM  trips t
    LEFT JOIN trip_cancellations tc ON t.trip_id = tc.trip_id{watermark_clause}
    ORDER BY t.requested_at
        """
    return extract(conn, extract_trip_sql, params)
