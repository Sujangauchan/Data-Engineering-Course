import argparse
import logging
import sys
import time
from pathlib import Path
from dotenv import load_dotenv
import psycopg2
import load as loader
import transform
import quality

# Re-export package modules when imported from the package
__all__ = [
    "extract",
    "transform",
    "load",
    "quality",
    "pipeline",
]

# Ensure local package modules import correctly when running as a script
HERE = Path(__file__).parent.resolve()
sys.path.insert(0, str(HERE))

from extract import (
    SOURCE_DB_CONFIG,
    DEST_DB_CONFIG,
    extract_driver,
    extract_passenger,
    extract_vehicle,
    extract_location,
    extract_payment_method,
    extract_promo_code,
    extract_trips,
    extract_watermark,
)



log_dir = HERE.parent / "logs"
log_dir.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    handlers=[
        logging.FileHandler(log_dir / "pipeline.log"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)

load_dotenv()


def parse_args():
    parser = argparse.ArgumentParser(description="Rides ETL pipeline")
    parser.add_argument(
        "--full-reload",
        action="store_true",
        help="Truncate warehouse and reload all data (default: incremental)",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    mode = "FULL" if args.full_reload else "INCREMENTAL"
    logger.info("Starting %s pipeline run", mode)

    src_conn = psycopg2.connect(**SOURCE_DB_CONFIG)
    dst_conn = psycopg2.connect(**DEST_DB_CONFIG)
    try:
        time0 = time.time()
        driver_watermark = None if mode == "FULL" else extract_watermark(dst_conn, "dim_driver", "joined_at")
        passenger_watermark = None if mode == "FULL" else extract_watermark(dst_conn, "dim_passenger", "created_at")

        driver_data = extract_driver(src_conn, driver_watermark)
        loader.load_dim_driver(dst_conn, driver_data)

        passenger_data = extract_passenger(src_conn, passenger_watermark)
        loader.load_dim_passenger(dst_conn, passenger_data)

        vehicle_data = extract_vehicle(src_conn)
        loader.load_dim_vehicle(dst_conn, vehicle_data)

        location_data = extract_location(src_conn)
        loader.load_dim_location(dst_conn, location_data)

        payment_method_data = extract_payment_method(src_conn)
        loader.load_dim_payment_method(dst_conn, payment_method_data)

        promo_code_data = extract_promo_code(src_conn)
        loader.load_dim_promo_code(dst_conn, promo_code_data)
        logger.info("Dimension table load completed in %.2fs", time.time() - time0)

        time0 = time.time()
        lookups = transform.load_lookup_dim(dst_conn)
        logger.info("Lookup table extraction completed in %.2fs", time.time() - time0)

        time0 = time.time()
        trip_watermark = None if mode == "FULL" else extract_watermark(dst_conn, "fact_trips", "requested_at")
        rows = extract_trips(src_conn, trip_watermark)
        logger.info("Trip extraction completed in %.2fs", time.time() - time0)

        time0 = time.time()
        fact_rows = transform.transform(rows, lookups)
        logger.info("Transformation completed in %.2fs", time.time() - time0)

        time0 = time.time()
        try:
            quality.run_quality_checks(fact_rows)
        except quality.DataQualityError as exc:
            logger.error("Data quality checks failed — aborting load: %s", exc)
            raise
        logger.info("Quality check completed in %.2fs", time.time() - time0)

        time0 = time.time()
        loader.load_fact_trips(dst_conn, fact_rows)
        logger.info("Trip table load completed in %.2fs", time.time() - time0)

    finally:
        src_conn.close()
        dst_conn.close()


if __name__ == "__main__":
    main()
