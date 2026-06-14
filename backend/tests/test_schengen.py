"""Schengen 90/180 tracker — unit math + endpoint shape."""
from datetime import date

from fastapi.testclient import TestClient

from app.main import app
from app.services import schengen

client = TestClient(app)


def _leg(s: str, e: str, sch: bool = True) -> dict:
    return {"start_date": s, "end_date": e,
            "is_schengen": 1 if sch else 0, "deleted_at": None}


# ── calculation ────────────────────────────────────────────────

def test_inclusive_day_count():
    # entry and exit both count: Jan 1..5 = 5 days
    assert len(schengen.schengen_days([_leg("2026-01-01", "2026-01-05")])) == 5


def test_non_schengen_legs_excluded():
    assert schengen.schengen_days([_leg("2026-01-01", "2026-01-10", sch=False)]) == set()


def test_overlapping_legs_deduped():
    days = schengen.schengen_days(
        [_leg("2026-01-01", "2026-01-05"), _leg("2026-01-04", "2026-01-08")])
    assert len(days) == 8  # Jan 1..8, the overlap counted once


def test_usage_and_remaining():
    r = schengen.report([_leg("2026-01-01", "2026-02-19")], date(2026, 2, 19))  # 50 days
    assert r["days_used"] == 50
    assert r["days_remaining"] == 40
    assert r["status"] == "ok"


def test_warning_band():
    r = schengen.report([_leg("2026-01-01", "2026-03-22")], date(2026, 3, 22))  # 81 days
    assert r["days_used"] == 81
    assert r["status"] == "warning"  # remaining 9 <= 10


def test_exceeded_and_peak():
    r = schengen.report([_leg("2026-01-01", "2026-04-30")], date(2026, 4, 30))  # 120 days
    assert r["status"] == "exceeded"
    assert r["ever_exceeds"] is True
    assert r["peak_days"] > 90


def test_window_rolls_off_old_days():
    # An old 60-day stay far in the past doesn't count toward today's window.
    r = schengen.report([_leg("2024-01-01", "2024-03-01")], date(2026, 6, 14))
    assert r["days_used"] == 0
    assert r["status"] == "ok"


# ── endpoint ───────────────────────────────────────────────────

def test_schengen_endpoint_shape():
    r = client.get("/api/v1/schengen", params={"as_of": "2026-06-14"})
    assert r.status_code == 200
    body = r.json()
    assert body["limit_days"] == 90 and body["window_days"] == 180
    for k in ("days_used", "days_remaining", "status", "peak_days", "ever_exceeds"):
        assert k in body
