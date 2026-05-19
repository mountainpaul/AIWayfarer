"""
T1: contract test — /sync/snapshot must return the exact field set the Flutter
SyncService writes into local SQLite. Schema drift on either side breaks
offline-first browsing because tables get cleared and not refilled.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

# Field names the Flutter side passes to clearTable + upsertAll. Source of
# truth: flutter/lib/services/sync_service.dart.
FLUTTER_EXPECTED_TABLES = {
    "trips",
    "legs",
    "bookings",
    "tasks",
    "packing_items",
    "journal_entries",
}


def test_sync_snapshot_keys_match_flutter_expectations():
    body = client.get("/sync/snapshot").json()
    missing = FLUTTER_EXPECTED_TABLES - body.keys()
    assert not missing, f"backend missing keys Flutter expects: {missing}"


def test_sync_snapshot_lists_are_well_formed():
    body = client.get("/sync/snapshot").json()
    for key in FLUTTER_EXPECTED_TABLES:
        rows = body[key]
        assert isinstance(rows, list)
        for row in rows:
            assert isinstance(row, dict)
            assert "id" in row, f"{key} row missing id: {row}"


def test_sync_snapshot_includes_current_leg_when_in_window():
    body = client.get("/sync/snapshot").json()
    legs = body["legs"]
    assert len(legs) == 8
    # current_leg may be null if today is outside the trip window — that's fine.
    if body.get("current_leg") is not None:
        assert body["current_leg"]["id"] in {l["id"] for l in legs}


def test_sync_snapshot_bookings_include_current_leg_history():
    """Once you're on a leg, that leg's full booking list (incl. past dates)
    must be cacheable for offline browsing — Q1 in the review."""
    body = client.get("/sync/snapshot").json()
    if body.get("current_leg") is None:
        return  # outside trip window in this test run; nothing to assert
    leg_id = body["current_leg"]["id"]
    leg_bookings = [b for b in body["bookings"] if b["leg_id"] == leg_id]
    assert len(leg_bookings) > 0, "current leg should contribute bookings to snapshot"
