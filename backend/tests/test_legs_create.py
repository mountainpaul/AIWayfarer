"""Leg creation: server-generated unique slugs + trip validation."""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _trip() -> str:
    r = client.post(
        "/api/v1/trips",
        json={"name": "Leg Test Trip", "start_date": "2026-02-01", "end_date": "2026-02-10"},
    )
    return r.json()["id"]


def test_create_leg_autogenerates_slug_from_name():
    tid = _trip()
    r = client.post(
        "/api/v1/legs",
        json={
            "trip_id": tid,
            "name": "Austria Innsbruck",
            "start_date": "2026-02-01",
            "end_date": "2026-02-02",
            "is_schengen": True,
        },
    )
    assert r.status_code == 201
    body = r.json()
    assert body["slug"] == "austria-innsbruck"
    assert body["is_schengen"] is True


def test_duplicate_name_gets_unique_slug():
    tid = _trip()
    name = "Zzz Unique Place"
    a = client.post("/api/v1/legs", json={
        "trip_id": tid, "name": name, "start_date": "2026-02-02", "end_date": "2026-02-03"}).json()
    b = client.post("/api/v1/legs", json={
        "trip_id": tid, "name": name, "start_date": "2026-02-03", "end_date": "2026-02-04"}).json()
    assert a["slug"] == "zzz-unique-place"
    assert b["slug"] == "zzz-unique-place-2"


def test_explicit_slug_is_honored():
    tid = _trip()
    r = client.post("/api/v1/legs", json={
        "trip_id": tid, "slug": "my-custom-slug", "name": "Whatever",
        "start_date": "2026-02-05", "end_date": "2026-02-06"})
    assert r.status_code == 201
    assert r.json()["slug"] == "my-custom-slug"


def test_create_leg_rejects_unknown_trip():
    r = client.post("/api/v1/legs", json={
        "trip_id": "does-not-exist", "name": "X",
        "start_date": "2026-02-01", "end_date": "2026-02-02"})
    assert r.status_code == 400
