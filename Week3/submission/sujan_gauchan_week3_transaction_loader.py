"""
transactional_loader.py
-----------------------
Week 3 Assignment — Q5

Complete the load_batch() function below.

Requirements:
  - Load a list of trip dicts into the trips table
  - All rows must load inside a SINGLE transaction
  - If ANY row fails, roll back the entire batch (no partial commits)
  - Log what went wrong (which row, what error)
  - Return the number of rows loaded (0 on failure)
  - Never silently swallow errors — re-raise after rollback

The connection boilerplate and INSERT SQL are provided.
You write the body of load_batch() and main().

Test your function with:
  1. A clean batch of 5 rows — should commit and return 5
  2. A batch where row 3 has rating=99 — should roll back and return 0
     Verify: the DB row count is unchanged after the failed load.
"""

import psycopg2
import logging
import os
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s"
)

logger = logging.getLogger(__name__)

DB_CONFIG = dict(
    host=os.getenv("DB_HOST"),
    port = os.getenv("DB_PORT"),
    dbname = os.getenv("DB_NAME"),
    user= os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD")
)

INSERT_SQL = """
    INSERT INTO trips (
        driver_id, passenger_id,
        pickup_id, dropoff_id,
        fare_amount, distance_km, status,
        requested_at, completed_at, rating, payment_id
    ) VALUES (
        %(driver_id)s, %(passenger_id)s,
        %(pickup_id)s, %(dropoff_id)s,
        %(fare_amount)s, %(distance_km)s, %(status)s,
        %(requested_at)s, %(completed_at)s,
        %(rating)s, %(payment_id)s
    )
"""


def load_batch(conn, rows: list) -> int:

    if conn.autocommit:
        conn.autocommit = False

    try:
        with conn.cursor() as cur:
            for row_number, row in enumerate (rows, start = 1):
                cur.execute(INSERT_SQL, row)

        conn.commit() 
        logger.info
        return len(rows)
    

    except Exception as e:
        # rollback the transaction if any error occurs
        conn.rollback()
        logger.error(f"Error loading row {row_number}: {e}")
        raise

    # TODO: implement this function
    #
    # Steps:
    #   1. Set conn.autocommit = False  (explicit transaction control)
    #   2. Open a cursor
    #   3. Loop through rows, executing INSERT_SQL for each
    #      - track which row number you're on (for error logging)
    #   4. If all succeed: conn.commit(), return len(rows)
    #   5. If any fail:
    #      - conn.rollback()
    #      - log the error and which row caused it
    #      - raise the exception so the caller sees the failure
    #
    # Hint: use a try / except / else pattern, or try / except with raise





def get_test_batches():
    """
    Returns two test batches:
      - good_batch: 5 valid trips (should commit)
      - bad_batch:  5 trips where row 3 has an invalid rating (should roll back)
    """
    base = dict(
        driver_id=1, passenger_id=1,
        pickup_id=1, dropoff_id=2,
        fare_amount=250.00, distance_km=8.5,
        status="completed",
        requested_at="2025-01-15 09:00:00",
        completed_at="2025-01-15 09:35:00",
        rating=4.5,
        payment_id=1
    )

    good_batch = [{**base, "fare_amount": 100 * (i + 1)} for i in range(5)]

    bad_batch = []
    for i in range(5):
        row = {**base, "fare_amount": 100 * (i + 1)}
        if i == 2:
            row["rating"] = 99  # violates CHECK (rating BETWEEN 1.0 AND 5.0)
        bad_batch.append(row)

    return good_batch, bad_batch


def main():
    conn = psycopg2.connect(**DB_CONFIG)
    good_batch, bad_batch = get_test_batches()

    count_before = None
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM trips")
        count_before = cur.fetchone()[0]
    logger.info(f"Trips before any load: {count_before:,}")

    # ── Test 1: good batch ────────────────────────────────────────
    logger.info("--- Test 1: loading good batch (expect success) ---")
    try:
        loaded = load_batch(conn, good_batch)
        logger.info(f"Test 1 passed: {loaded} rows loaded")
    except Exception as e:
        logger.error(f"Test 1 failed unexpectedly: {e}")

    # ── Test 2: bad batch ─────────────────────────────────────────
    logger.info("--- Test 2: loading bad batch (expect rollback) ---")
    try:
        loaded = load_batch(conn, bad_batch)
        logger.warning(f"Test 2: loaded {loaded} rows — was rollback triggered?")
    except Exception:
        logger.info("Test 2 passed: exception raised after rollback")

    # ── Verify final count ────────────────────────────────────────
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM trips")
        count_after = cur.fetchone()[0]

    logger.info(f"Trips after both tests: {count_after:,}")
    logger.info(f"Net rows added: {count_after - count_before}")
    # Expected: +5 (good batch committed, bad batch rolled back)

    conn.close()


if __name__ == "__main__":
    main()




# Result

# [Running] python3 -u "/Users/sujangauchan/Desktop/Python/transaction_loader.py"
# 2026-07-04 02:24:24,346  INFO  Trips before any load: 5,000
# 2026-07-04 02:24:24,346  INFO  --- Test 1: loading good batch (expect success) ---
# 2026-07-04 02:24:24,357  INFO  Test 1 passed: 5 rows loaded
# 2026-07-04 02:24:24,357  INFO  --- Test 2: loading bad batch (expect rollback) ---
# 2026-07-04 02:24:24,359  ERROR  Error loading row 3: numeric field overflow
# DETAIL:  A field with precision 2, scale 1 must round to an absolute value less than 10^1.

# 2026-07-04 02:24:24,359  INFO  Test 2 passed: exception raised after rollback
# 2026-07-04 02:24:24,359  INFO  Trips after both tests: 5,005
# 2026-07-04 02:24:24,359  INFO  Net rows added: 5

