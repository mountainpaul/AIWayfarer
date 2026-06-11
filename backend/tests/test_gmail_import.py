"""Tests for /gmail/import-bookings — the write boundary for LLM-origin data.
Pure DB logic, no Gmail/Claude mocking needed. Also covers the scan endpoint's
error mapping and the scanner's parsing helpers."""

from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app
from app.services import gmail_scanner

client = TestClient(app)


def _sicily_leg_id() -> str:
    legs = client.get("/legs").json()
    return next(l["id"] for l in legs if l["slug"] == "sicily")


def _cleanup(ids: list[str]) -> None:
    for booking_id in ids:
        client.delete(f"/bookings/{booking_id}")


def test_import_sanitizes_llm_origin_fields():
    leg_id = _sicily_leg_id()
    r = client.post("/gmail/import-bookings", json=[
        {
            "leg_id": leg_id,
            "type": "bus",              # not a valid enum -> "other"
            "name": None,               # JSON null -> "Unknown", not a 500
            "status": "CONFIRMED!!",    # invalid -> "booked"
            "start_date": "tomorrow",   # not ISO -> dropped
            "cost_cents": "EUR 23.50",  # string -> dropped, not stored raw
            "currency": None,           # -> "EUR"
            "confirmation": "IMPTEST1",
        },
    ])
    assert r.status_code == 200
    body = r.json()
    assert body["imported"] == 1
    ids = body["ids"]
    try:
        fetched = client.get(f"/bookings/{ids[0]}")
        # The strict Pydantic read model must accept what import wrote.
        assert fetched.status_code == 200
        b = fetched.json()
        assert b["type"] == "other"
        assert b["name"] == "Unknown"
        assert b["status"] == "booked"
        assert b["start_date"] is None
        assert b["cost_cents"] is None
        assert b["currency"] == "EUR"
        # And the whole list still serializes.
        assert client.get("/bookings").status_code == 200
    finally:
        _cleanup(ids)


def test_import_skips_unknown_leg_and_duplicates():
    leg_id = _sicily_leg_id()
    batch = [
        {"leg_id": "no-such-leg", "type": "hotel", "name": "Phantom"},
        {"leg_id": leg_id, "type": "hotel", "name": "Dup Inn",
         "start_date": "2026-04-21", "confirmation": "DUPTEST1"},
        # Same confirmation within the batch -> skipped.
        {"leg_id": leg_id, "type": "hotel", "name": "Dup Inn Again",
         "start_date": "2026-04-22", "confirmation": "DUPTEST1"},
        # No confirmation, same composite key as the first -> skipped.
        {"leg_id": leg_id, "type": "hotel", "name": "Dup Inn",
         "start_date": "2026-04-21"},
    ]
    r = client.post("/gmail/import-bookings", json=batch)
    assert r.status_code == 200
    body = r.json()
    try:
        assert body["imported"] == 1
        assert body["skipped"] == 3
        # Re-importing the same batch creates nothing.
        r2 = client.post("/gmail/import-bookings", json=batch)
        assert r2.json()["imported"] == 0
    finally:
        _cleanup(body["ids"])


def test_scan_maps_gmail_errors_to_502_and_unconfigured_to_503():
    with patch.object(
        gmail_scanner, "scan_and_parse",
        side_effect=gmail_scanner.GmailApiError("quota"),
    ):
        assert client.post("/gmail/scan-bookings").status_code == 502

    from app.services import google_auth
    with patch.object(
        gmail_scanner, "scan_and_parse",
        side_effect=google_auth.GoogleNotConfiguredError("no token"),
    ):
        assert client.post("/gmail/scan-bookings").status_code == 503


def test_scan_flags_existing_bookings():
    leg_id = _sicily_leg_id()
    created = client.post("/bookings", json={
        "leg_id": leg_id, "type": "train", "name": "Known Train",
        "status": "booked", "start_date": "2026-04-23",
        "confirmation": "SCANTEST1",
    }).json()
    candidates = [
        {"leg_id": leg_id, "type": "train", "name": "Known Train",
         "start_date": "2026-04-23", "confirmation": "SCANTEST1"},
        {"leg_id": leg_id, "type": "ferry", "name": "New Ferry",
         "start_date": "2026-04-24"},
    ]
    try:
        with patch.object(gmail_scanner, "scan_and_parse", return_value=candidates):
            r = client.post("/gmail/scan-bookings")
        assert r.status_code == 200
        out = {c["name"]: c["already_exists"] for c in r.json()["candidates"]}
        assert out["Known Train"] is True
        assert out["New Ferry"] is False
    finally:
        _cleanup([created["id"]])


def test_parse_bookings_handles_fences_and_preamble():
    fenced = '```json\n[{"type": "train", "name": "T1"}]\n```'
    preamble = 'Here are the bookings:\n[{"type": "spaceship", "name": "T2"}]\nDone.'
    garbage = "I could not find any bookings."

    with patch.object(gmail_scanner, "call_chat", return_value=fenced):
        out = gmail_scanner.parse_bookings_with_claude([{"subject": "s", "sender": "f",
            "date": "d", "snippet": "x", "body": "b"}], [])
        assert out[0]["name"] == "T1"

    with patch.object(gmail_scanner, "call_chat", return_value=preamble):
        out = gmail_scanner.parse_bookings_with_claude([{"subject": "s", "sender": "f",
            "date": "d", "snippet": "x", "body": "b"}], [])
        assert out[0]["name"] == "T2"
        assert out[0]["type"] == "other"  # enum coerced

    with patch.object(gmail_scanner, "call_chat", return_value=garbage):
        assert gmail_scanner.parse_bookings_with_claude([{"subject": "s", "sender": "f",
            "date": "d", "snippet": "x", "body": "b"}], []) == []


def test_html_to_text_strips_scripts_and_tags():
    html_body = (
        "<html><head><style>p{color:red}</style></head>"
        "<body><p>Booking <b>ABC123</b> confirmed</p>"
        "<script>alert('x')</script></body></html>"
    )
    text = gmail_scanner._html_to_text(html_body)
    assert "ABC123" in text and "confirmed" in text
    assert "alert" not in text and "color:red" not in text
