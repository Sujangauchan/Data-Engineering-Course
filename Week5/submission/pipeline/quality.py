import logging

logger = logging.getLogger(__name__)


class DataQualityError(Exception):
    """Raised when a transformed fact row fails a required quality check."""


def check_row_count(rows, min_rows=1):
    count = len(rows)
    passed = count >= min_rows
    return {
        "check": "row_count",
        "passed": passed,
        "detail": f"{count} rows (min: {min_rows})",
    }


def check_no_negative_fares(rows):
    bad = [r for r in rows if r.get("fare_amount") is None or r["fare_amount"] < 0]
    return {
        "check": "no_negative_fares",
        "passed": len(bad) == 0,
        "detail": f"{len(bad)} rows with fare_amount < 0 or NULL",
    }


def check_no_null_driver_keys(rows):
    bad = [r for r in rows if r.get("driver_key") is None]
    return {
        "check": "no_null_driver_keys",
        "passed": len(bad) == 0,
        "detail": f"{len(bad)} rows with NULL driver_key",
    }


def check_completed_have_duration(rows):
    bad = [r for r in rows if r.get("status") == "completed" and r.get("duration_minutes") is None]
    return {
        "check": "completed_have_duration",
        "passed": len(bad) == 0,
        "detail": f"{len(bad)} completed trips with NULL duration_minutes",
    }


def check_valid_status(rows):
    valid = {"completed", "cancelled", "no_show"}
    bad = [r for r in rows if r.get("status") not in valid]
    return {
        "check": "valid_status",
        "passed": len(bad) == 0,
        "detail": f"{len(bad)} rows with invalid status",
    }


def run_quality_checks(rows):
    checks = [
        check_row_count(rows),
        check_no_negative_fares(rows),
        check_no_null_driver_keys(rows),
        check_completed_have_duration(rows),
        check_valid_status(rows),
    ]

    failed = [c for c in checks if not c["passed"]]
    if failed:
        first = failed[0]
        raise DataQualityError(f"Quality check failed: {first['check']} — {first['detail']}")

    logger.info("Quality gate passed: %s rows, %s checks", len(rows), len(checks))
    return {"passed": True, "checks": checks, "row_count": len(rows)}


def validate_fact_rows(fact_rows):
    """Backward-compatible wrapper that returns True/False for the pipeline."""
    try:
        run_quality_checks(fact_rows)
        return True
    except DataQualityError:
        return False
