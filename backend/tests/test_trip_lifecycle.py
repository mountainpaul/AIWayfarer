"""Trip + leg lifecycle CRUD (status, soft-delete, undo)."""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _a_trip_id() -> str:
    return client.get("/api/v1/trips").json()[0]["id"]


def _new_trip() -> dict:
    r = client.post(
        "/api/v1/trips",
        json={"name": "ZZ Test Trip", "start_date": "2030-01-01",
              "end_date": "2030-01-10"},
    )
    assert r.status_code == 201
    return r.json()


# ── Trip ───────────────────────────────────────────────────────

def test_create_trip_defaults_to_planning():
    t = _new_trip()
    assert t["status"] == "planning"
    assert any(x["id"] == t["id"] for x in client.get("/api/v1/trips").json())
    client.delete(f"/api/v1/trips/{t['id']}")


def test_trip_status_transition():
    t = _new_trip()
    r = client.patch(f"/api/v1/trips/{t['id']}", json={"status": "completed"})
    assert r.status_code == 200 and r.json()["status"] == "completed"
    client.delete(f"/api/v1/trips/{t['id']}")


def test_invalid_trip_status_rejected():
    t = _new_trip()
    r = client.patch(f"/api/v1/trips/{t['id']}", json={"status": "bogus"})
    assert r.status_code == 422
    client.delete(f"/api/v1/trips/{t['id']}")


def test_trip_soft_delete_is_recoverable_via_undo():
    t = _new_trip()
    tid = t["id"]
    assert client.delete(f"/api/v1/trips/{tid}").status_code == 204
    assert client.get(f"/api/v1/trips/{tid}").status_code == 404
    assert all(x["id"] != tid for x in client.get("/api/v1/trips").json())

    dele = [c for c in client.get("/api/v1/changes", params={"entity_id": tid}).json()
            if c["op"] == "delete"][-1]
    r = client.post(f"/api/v1/changes/{dele['change_id']}/undo")
    assert r.status_code == 200
    assert client.get(f"/api/v1/trips/{tid}").status_code == 200  # restored
    client.delete(f"/api/v1/trips/{tid}")


def test_double_delete_trip_is_404():
    tid = _new_trip()["id"]
    assert client.delete(f"/api/v1/trips/{tid}").status_code == 204
    assert client.delete(f"/api/v1/trips/{tid}").status_code == 404


# ── Leg ────────────────────────────────────────────────────────

def test_create_leg_requires_existing_trip():
    r = client.post("/api/v1/legs", json={
        "trip_id": "does-not-exist", "slug": "zz-bad", "name": "ZZ",
        "start_date": "2030-01-01", "end_date": "2030-01-05", "sort_order": 99})
    assert r.status_code == 400


def test_leg_crud_and_soft_delete():
    tid = _a_trip_id()
    leg = client.post("/api/v1/legs", json={
        "trip_id": tid, "slug": "zz-test-leg", "name": "ZZ Leg",
        "start_date": "2030-01-01", "end_date": "2030-01-05",
        "is_schengen": True, "sort_order": 99}).json()
    lid = leg["id"]
    assert leg["is_schengen"] is True

    upd = client.patch(f"/api/v1/legs/{lid}", json={"name": "ZZ Renamed"})
    assert upd.status_code == 200 and upd.json()["name"] == "ZZ Renamed"

    assert client.delete(f"/api/v1/legs/{lid}").status_code == 204
    assert all(x["id"] != lid for x in client.get("/api/v1/legs").json())  # hidden
