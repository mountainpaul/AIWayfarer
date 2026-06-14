"""Append-only change log + undo/redo (docs/sync-redesign-v2-change-log.md)."""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _leg_id() -> str:
    return client.get("/legs").json()[0]["id"]


def _make_booking(notes: str = "orig") -> dict:
    r = client.post(
        "/bookings",
        json={
            "leg_id": _leg_id(),
            "type": "other",
            "name": "changelog-subject",
            "status": "pending",
            "notes": notes,
        },
    )
    assert r.status_code == 201
    return r.json()


def _changes_for(entity_id: str) -> list[dict]:
    return client.get("/changes", params={"entity_id": entity_id}).json()


def _cleanup(bid: str):
    client.delete(f"/bookings/{bid}")


# ── Logging ────────────────────────────────────────────────────

def test_every_mutation_is_logged():
    b = _make_booking()
    bid = b["id"]
    client.patch(f"/bookings/{bid}", json={"notes": "edited"})
    client.delete(f"/bookings/{bid}")

    ops = [c["op"] for c in _changes_for(bid)]
    assert ops == ["create", "update", "delete"]


def test_update_change_records_prior_value():
    b = _make_booking(notes="before")
    bid = b["id"]
    client.patch(f"/bookings/{bid}", json={"notes": "after"})
    upd = [c for c in _changes_for(bid) if c["op"] == "update"][-1]
    assert upd["patch"]["new"]["notes"] == "after"
    assert upd["patch"]["old"]["notes"] == "before"
    _cleanup(bid)


# ── Undo / redo ────────────────────────────────────────────────

def test_undo_update_restores_overwritten_value():
    # This is the lost-car-booking scenario: an edit overwrote a value; undo
    # must bring the old value back.
    b = _make_booking(notes="pickup 2pm")
    bid = b["id"]
    client.patch(f"/bookings/{bid}", json={"notes": "WRONG"})
    assert client.get(f"/bookings/{bid}").json()["notes"] == "WRONG"

    upd = [c for c in _changes_for(bid) if c["op"] == "update"][-1]
    r = client.post(f"/changes/{upd['change_id']}/undo")
    assert r.status_code == 200
    assert client.get(f"/bookings/{bid}").json()["notes"] == "pickup 2pm"
    _cleanup(bid)


def test_undo_delete_restores_row():
    b = _make_booking()
    bid = b["id"]
    client.delete(f"/bookings/{bid}")
    assert client.get(f"/bookings/{bid}").status_code == 404

    dele = [c for c in _changes_for(bid) if c["op"] == "delete"][-1]
    client.post(f"/changes/{dele['change_id']}/undo")
    assert client.get(f"/bookings/{bid}").status_code == 200  # back from the dead
    _cleanup(bid)


def test_undo_create_removes_the_row():
    b = _make_booking()
    bid = b["id"]
    crt = [c for c in _changes_for(bid) if c["op"] == "create"][-1]
    client.post(f"/changes/{crt['change_id']}/undo")
    assert client.get(f"/bookings/{bid}").status_code == 404  # already hidden, no cleanup


def test_redo_via_undoing_the_undo():
    b = _make_booking(notes="v1")
    bid = b["id"]
    client.patch(f"/bookings/{bid}", json={"notes": "v2"})
    upd = [c for c in _changes_for(bid) if c["op"] == "update"][-1]

    # Undo: back to v1.
    undo = client.post(f"/changes/{upd['change_id']}/undo").json()
    assert client.get(f"/bookings/{bid}").json()["notes"] == "v1"

    # Redo = undo the undo: forward to v2.
    undo_change_id = _changes_for(bid)[-1]["change_id"]
    client.post(f"/changes/{undo_change_id}/undo")
    assert client.get(f"/bookings/{bid}").json()["notes"] == "v2"
    _cleanup(bid)


def test_undo_unknown_change_is_404():
    assert client.post("/changes/nope-not-a-real-id/undo").status_code == 404


# ── Feed cursor ────────────────────────────────────────────────

def test_since_seq_returns_only_newer_events():
    all_now = client.get("/changes").json()
    cursor = all_now[-1]["seq"] if all_now else 0
    b = _make_booking()
    newer = client.get("/changes", params={"since_seq": cursor}).json()
    assert all(c["seq"] > cursor for c in newer)
    assert any(c["entity_id"] == b["id"] for c in newer)
    _cleanup(b["id"])
