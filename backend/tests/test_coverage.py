"""Accommodation coverage — unit math + endpoint shape."""
from fastapi.testclient import TestClient

from app.main import app
from app.services import coverage

client = TestClient(app)


def _leg(id_, s, e):
    return {"id": id_, "name": "L", "start_date": s, "end_date": e}


def _book(leg_id, s, e, type_="hotel", deleted=False):
    return {"leg_id": leg_id, "type": type_, "start_date": s, "end_date": e,
            "deleted_at": "x" if deleted else None}


# ── calculation ────────────────────────────────────────────────

def test_leg_nights_are_checkout_exclusive():
    # Jan 1..4 leg = nights of 1,2,3 = 3 nights
    c = coverage.leg_coverage(_leg("L1", "2026-01-01", "2026-01-04"), [])
    assert c["total_nights"] == 3
    assert c["booked_nights"] == 0
    assert c["unbooked_nights"] == 3


def test_partial_booking_leaves_gap():
    leg = _leg("L1", "2026-01-01", "2026-01-04")  # nights 1,2,3
    hotel = _book("L1", "2026-01-01", "2026-01-03")  # nights 1,2
    c = coverage.leg_coverage(leg, [hotel])
    assert c["booked_nights"] == 2
    assert c["unbooked_nights"] == 1


def test_only_lodging_types_count():
    leg = _leg("L1", "2026-01-01", "2026-01-03")  # nights 1,2
    # a flight on those dates is not lodging
    c = coverage.leg_coverage(leg, [_book("L1", "2026-01-01", "2026-01-03", "flight")])
    assert c["booked_nights"] == 0
    # rifugio counts
    c2 = coverage.leg_coverage(leg, [_book("L1", "2026-01-01", "2026-01-03", "rifugio")])
    assert c2["booked_nights"] == 2


def test_deleted_and_dateless_bookings_ignored():
    leg = _leg("L1", "2026-01-01", "2026-01-03")
    c = coverage.leg_coverage(leg, [
        _book("L1", "2026-01-01", "2026-01-03", deleted=True),
        {"leg_id": "L1", "type": "hotel", "start_date": None, "end_date": None,
         "deleted_at": None},
    ])
    assert c["booked_nights"] == 0


def test_overlapping_bookings_not_double_counted():
    leg = _leg("L1", "2026-01-01", "2026-01-05")  # nights 1..4 = 4
    c = coverage.leg_coverage(leg, [
        _book("L1", "2026-01-01", "2026-01-04"),  # 1,2,3
        _book("L1", "2026-01-03", "2026-01-05"),  # 3,4
    ])
    assert c["booked_nights"] == 4  # union {1,2,3,4}, not 5
    assert c["unbooked_nights"] == 0


# ── endpoint ───────────────────────────────────────────────────

def test_coverage_endpoint_shape():
    r = client.get("/api/v1/coverage")
    assert r.status_code == 200
    items = r.json()
    assert isinstance(items, list) and items
    for it in items:
        for k in ("leg_id", "leg_name", "total_nights", "booked_nights",
                  "unbooked_nights"):
            assert k in it
        assert it["booked_nights"] + it["unbooked_nights"] == it["total_nights"]
