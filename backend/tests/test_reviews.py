"""Post-trip review (Step 3): /api/v1/reviews CRUD, entity-linked items,
one-review-per-trip, and distillation into traveler_profile.profile_summary.
"""
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app
from app.services import claude as claude_svc

client = TestClient(app)


def _make_trip(name="Review Test Trip") -> str:
    r = client.post(
        "/api/v1/trips",
        json={"name": name, "start_date": "2026-01-01", "end_date": "2026-01-07"},
    )
    assert r.status_code == 201
    return r.json()["id"]


def _review_payload(trip_id: str) -> dict:
    return {
        "trip_id": trip_id,
        "overall_rating": 4,
        "pace_feedback": "just_right",
        "highlight": "The rifugio dinners",
        "lowlight": "Too much driving",
        "free_text": "Would do the hut-to-hut again.",
        "items": [
            {
                "subject_type": "stay",
                "subject_label": "Tobler Youth Hostel",
                "rating": 5,
                "liked": "central and quiet",
            },
            {
                "subject_type": "transport",
                "subject_label": "Sixt Fiat Panda",
                "rating": 2,
                "disliked": "cramped on mountain roads",
            },
        ],
    }


# ── CRUD ──────────────────────────────────────────────────────────
def test_create_review_returns_review_with_items():
    trip_id = _make_trip()
    with patch.object(claude_svc, "call_simple", return_value="x"):
        r = client.post("/api/v1/reviews", json=_review_payload(trip_id))
    assert r.status_code == 201
    body = r.json()
    assert body["trip_id"] == trip_id
    assert body["overall_rating"] == 4
    assert len(body["items"]) == 2
    labels = {i["subject_label"] for i in body["items"]}
    assert labels == {"Tobler Youth Hostel", "Sixt Fiat Panda"}
    # Items carry their review_id link.
    assert all(i["review_id"] == body["id"] for i in body["items"])


def test_get_review_by_trip():
    trip_id = _make_trip()
    with patch.object(claude_svc, "call_simple", return_value="x"):
        client.post("/api/v1/reviews", json=_review_payload(trip_id))
    r = client.get(f"/api/v1/reviews/{trip_id}")
    assert r.status_code == 200
    assert r.json()["highlight"] == "The rifugio dinners"


def test_get_review_404_when_absent():
    trip_id = _make_trip()
    assert client.get(f"/api/v1/reviews/{trip_id}").status_code == 404


def test_one_review_per_trip_conflicts():
    trip_id = _make_trip()
    with patch.object(claude_svc, "call_simple", return_value="x"):
        first = client.post("/api/v1/reviews", json=_review_payload(trip_id))
        second = client.post("/api/v1/reviews", json=_review_payload(trip_id))
    assert first.status_code == 201
    assert second.status_code == 409


def test_invalid_subject_type_rejected():
    trip_id = _make_trip()
    payload = _review_payload(trip_id)
    payload["items"][0]["subject_type"] = "spaceship"
    r = client.post("/api/v1/reviews", json=payload)
    assert r.status_code == 422  # Literal validation


def test_list_reviews_includes_new_one():
    trip_id = _make_trip("Listed Trip")
    with patch.object(claude_svc, "call_simple", return_value="x"):
        client.post("/api/v1/reviews", json=_review_payload(trip_id))
    r = client.get("/api/v1/reviews")
    assert r.status_code == 200
    assert any(rv["trip_id"] == trip_id for rv in r.json())


# ── Distillation into the traveler profile ────────────────────────
def test_submitting_review_distills_profile_summary():
    trip_id = _make_trip()
    new_summary = "Paul favors central, quiet stays and dislikes long drives in small cars."
    with patch.object(claude_svc, "call_simple", return_value=new_summary) as m:
        r = client.post("/api/v1/reviews", json=_review_payload(trip_id))
    assert r.status_code == 201
    m.assert_called_once()
    # The distilled summary landed on the singleton profile.
    profile = client.get("/api/v1/profile").json()
    assert profile["profile_summary"] == new_summary


def test_review_still_saved_when_claude_unavailable():
    trip_id = _make_trip()
    # Capture the summary before, so we can assert it's unchanged.
    before = client.get("/api/v1/profile").json()["profile_summary"]

    def _raise(*a, **kw):
        raise claude_svc.ClaudeUnavailableError("no key")

    with patch.object(claude_svc, "call_simple", side_effect=_raise):
        r = client.post("/api/v1/reviews", json=_review_payload(trip_id))
    assert r.status_code == 201, "review must persist even if distillation fails"
    after = client.get("/api/v1/profile").json()["profile_summary"]
    assert after == before  # summary left untouched on Claude outage
