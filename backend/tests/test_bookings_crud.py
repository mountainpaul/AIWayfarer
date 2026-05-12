from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _sicily_leg_id() -> str:
    legs = client.get("/legs").json()
    return next(l["id"] for l in legs if l["slug"] == "sicily")


def test_create_booking_round_trip():
    leg_id = _sicily_leg_id()
    payload = {
        "leg_id": leg_id,
        "type": "ferry",
        "name": "Test crossing",
        "status": "researching",
        "start_date": "2026-04-20",
        "cost_cents": 4500,
        "currency": "EUR",
    }
    r = client.post("/bookings", json=payload)
    assert r.status_code == 201
    body = r.json()
    assert body["id"] and len(body["id"]) == 36
    assert body["name"] == "Test crossing"
    assert body["cost_cents"] == 4500
    assert body["currency"] == "EUR"

    fetched = client.get(f"/bookings/{body['id']}")
    assert fetched.status_code == 200
    assert fetched.json()["name"] == "Test crossing"

    deleted = client.delete(f"/bookings/{body['id']}")
    assert deleted.status_code == 204
    assert client.get(f"/bookings/{body['id']}").status_code == 404


def test_create_booking_rejects_unknown_leg():
    r = client.post(
        "/bookings",
        json={
            "leg_id": "00000000-0000-0000-0000-000000000000",
            "type": "hotel",
            "name": "Phantom",
            "status": "researching",
        },
    )
    assert r.status_code == 400
    assert "leg_id" in r.json()["detail"]


def test_create_booking_rejects_invalid_type():
    r = client.post(
        "/bookings",
        json={
            "leg_id": _sicily_leg_id(),
            "type": "spaceship",
            "name": "Nope",
            "status": "researching",
        },
    )
    assert r.status_code == 422


def test_patch_booking_only_changes_specified_fields():
    leg_id = _sicily_leg_id()
    created = client.post("/bookings", json={
        "leg_id": leg_id, "type": "hotel", "name": "Patchable",
        "status": "researching", "cost_cents": 1000,
    }).json()
    try:
        r = client.patch(f"/bookings/{created['id']}", json={"status": "booked"})
        assert r.status_code == 200
        body = r.json()
        assert body["status"] == "booked"
        assert body["name"] == "Patchable"
        assert body["cost_cents"] == 1000
    finally:
        client.delete(f"/bookings/{created['id']}")


def test_patch_booking_404_for_unknown_id():
    r = client.patch("/bookings/does-not-exist", json={"name": "x"})
    assert r.status_code == 404


def test_delete_booking_404_for_unknown_id():
    r = client.delete("/bookings/does-not-exist")
    assert r.status_code == 404


def test_filter_bookings_by_leg_and_type():
    leg_id = _sicily_leg_id()
    r = client.get(f"/bookings?leg_id={leg_id}&type=hotel")
    assert r.status_code == 200
    bookings = r.json()
    assert len(bookings) >= 1
    assert all(b["leg_id"] == leg_id and b["type"] == "hotel" for b in bookings)
