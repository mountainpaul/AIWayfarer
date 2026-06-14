from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_current_leg_mid_sicily():
    r = client.get("/api/v1/legs/current?date=2026-04-15")
    assert r.status_code == 200
    body = r.json()
    assert body is not None
    assert body["slug"] == "sicily"


def test_current_leg_mid_dolomites():
    r = client.get("/api/v1/legs/current?date=2026-06-15")
    assert r.status_code == 200
    body = r.json()
    assert body is not None
    assert body["slug"] == "dolomites"


def test_current_leg_first_day_inclusive():
    # Leg start_date should match (BETWEEN is inclusive).
    r = client.get("/api/v1/legs/current?date=2026-04-12")
    assert r.json()["slug"] == "sicily"


def test_current_leg_last_day_inclusive():
    r = client.get("/api/v1/legs/current?date=2026-04-10")
    assert r.json()["slug"] == "tunisia"


def test_current_leg_overlapping_picks_earlier_start():
    # Sicily ends 2026-04-26; Sardinia starts 2026-04-26. Query is ORDER BY
    # start_date ASC LIMIT 1, so Sicily (earlier start_date) wins.
    r = client.get("/api/v1/legs/current?date=2026-04-26")
    assert r.json()["slug"] == "sicily"


def test_current_leg_returns_null_outside_trip():
    r = client.get("/api/v1/legs/current?date=2030-01-01")
    assert r.status_code == 200
    assert r.json() is None
