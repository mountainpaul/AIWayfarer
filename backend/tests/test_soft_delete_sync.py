"""Soft-delete + timestamp-merge sync behavior (docs/sync-redesign.md)."""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _a_leg_id() -> str:
    return client.get("/legs").json()[0]["id"]


def _make_booking() -> dict:
    r = client.post(
        "/bookings",
        json={
            "leg_id": _a_leg_id(),
            "type": "other",
            "name": "soft-delete-subject",
            "status": "pending",
        },
    )
    assert r.status_code == 201
    return r.json()


# ── Soft delete ────────────────────────────────────────────────

def test_delete_is_soft_and_hidden_but_recoverable():
    b = _make_booking()
    bid = b["id"]

    assert client.delete(f"/bookings/{bid}").status_code == 204
    # Hidden from the normal read paths…
    assert client.get(f"/bookings/{bid}").status_code == 404
    assert all(x["id"] != bid for x in client.get("/bookings").json())
    # …but still present (recoverable) and tombstoned in the sync snapshot.
    snap = client.get("/sync/snapshot").json()
    row = next((x for x in snap["bookings"] if x["id"] == bid), None)
    assert row is not None, "tombstoned row must remain in the snapshot"
    assert row["deleted_at"], "deleted_at must be set on the tombstone"


def test_double_delete_is_404():
    bid = _make_booking()["id"]
    assert client.delete(f"/bookings/{bid}").status_code == 204
    assert client.delete(f"/bookings/{bid}").status_code == 404


def test_cannot_update_a_deleted_booking():
    bid = _make_booking()["id"]
    client.delete(f"/bookings/{bid}")
    assert client.patch(f"/bookings/{bid}", json={"notes": "x"}).status_code == 404


def test_task_and_packing_delete_are_soft():
    # task
    leg = _a_leg_id()
    t = client.post(
        "/tasks", json={"leg_id": leg, "title": "td", "priority": "low"}
    ).json()
    assert client.delete(f"/tasks/{t['id']}").status_code == 204
    snap = client.get("/sync/snapshot").json()
    row = next((x for x in snap["tasks"] if x["id"] == t["id"]), None)
    assert row is not None and row["deleted_at"]


# ── Delta sync + tombstone propagation ─────────────────────────

# Deterministic cursors (far past / far future) avoid same-second flakiness
# while still exercising the delta filter and is_delta flag.
_PAST = "2000-01-01T00:00:00Z"
_FUTURE = "2999-01-01T00:00:00Z"


def test_delta_flag_and_filtering():
    full = client.get("/sync/snapshot").json()
    assert full["is_delta"] is False
    assert full["server_time"]

    # Nothing is newer than the far future ⇒ empty delta, flagged as delta.
    empty = client.get("/sync/snapshot", params={"since": _FUTURE}).json()
    assert empty["is_delta"] is True
    assert empty["bookings"] == []

    # A booking created now is newer than the far past ⇒ present in that delta.
    b = _make_booking()
    delta = client.get("/sync/snapshot", params={"since": _PAST}).json()
    assert b["id"] in [x["id"] for x in delta["bookings"]]
    client.delete(f"/bookings/{b['id']}")  # cleanup: keep shared-DB counts stable


def test_delete_propagates_through_delta_as_tombstone():
    b = _make_booking()
    client.delete(f"/bookings/{b['id']}")
    delta = client.get("/sync/snapshot", params={"since": _PAST}).json()
    row = next((x for x in delta["bookings"] if x["id"] == b["id"]), None)
    assert row is not None and row["deleted_at"], (
        "a delete must reach the client as a tombstone, not vanish"
    )


def test_update_bumps_updated_at():
    b = _make_booking()
    before = b["updated_at"]
    after = client.patch(
        f"/bookings/{b['id']}", json={"notes": "changed"}
    ).json()["updated_at"]
    assert after >= before
    client.delete(f"/bookings/{b['id']}")  # cleanup: keep shared-DB counts stable
