from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _trip_id() -> str:
    return client.get("/api/v1/trips").json()[0]["id"]


def test_create_packing_item_defaults_to_unpacked():
    created = client.post("/api/v1/packing", json={
        "trip_id": _trip_id(), "category": "gear", "name": "Compass",
    }).json()
    try:
        assert created["is_packed"] is False
        assert created["category"] == "gear"
    finally:
        client.delete(f"/api/v1/packing/{created['id']}")


def test_create_packing_item_rejects_unknown_trip():
    r = client.post("/api/v1/packing", json={
        "trip_id": "00000000-0000-0000-0000-000000000000",
        "category": "gear", "name": "Phantom",
    })
    assert r.status_code == 400


def test_create_packing_item_rejects_invalid_category():
    r = client.post("/api/v1/packing", json={
        "trip_id": _trip_id(), "category": "weapons", "name": "Nope",
    })
    assert r.status_code == 422


def test_toggle_packed_flips_value():
    created = client.post("/api/v1/packing", json={
        "trip_id": _trip_id(), "category": "misc", "name": "Toggle item",
    }).json()
    try:
        first = client.patch(f"/api/v1/packing/{created['id']}/packed").json()
        assert first["is_packed"] is True
        second = client.patch(f"/api/v1/packing/{created['id']}/packed").json()
        assert second["is_packed"] is False
    finally:
        client.delete(f"/api/v1/packing/{created['id']}")


def test_filter_packing_by_category():
    items = client.get("/api/v1/packing?category=footwear").json()
    assert len(items) >= 1
    assert all(i["category"] == "footwear" for i in items)
