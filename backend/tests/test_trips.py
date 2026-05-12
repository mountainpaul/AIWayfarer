from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["version"] == "0.5.0"


def test_list_trips_returns_seed_data():
    r = client.get("/trips")
    assert r.status_code == 200
    trips = r.json()
    assert len(trips) >= 1
    assert any(t["name"] == "Europe 2026" for t in trips)


def test_list_legs_count():
    r = client.get("/legs")
    assert r.status_code == 200
    legs = r.json()
    assert len(legs) == 10


def test_list_bookings_count():
    r = client.get("/bookings")
    assert r.status_code == 200
    bookings = r.json()
    assert len(bookings) == 63


def test_grounding_payload_shape():
    r = client.get("/grounding")
    assert r.status_code == 200
    body = r.json()
    assert "now" in body
    assert "todays_bookings" in body
    assert "open_tasks_count" in body
    assert isinstance(body["open_tasks_count"], int)


def test_sync_snapshot():
    r = client.get("/sync/snapshot")
    assert r.status_code == 200
    body = r.json()
    assert "generated_at" in body
    for key in ("trips", "legs", "bookings", "tasks", "packing_items", "journal_entries"):
        assert isinstance(body[key], list), f"{key} should be a list"


def test_gmail_stub_returns_empty_list():
    # Gmail still a stub in v0.5; calendar has been replaced with the real router.
    assert client.get("/gmail/threads").json() == []
