"""Tests for /gmail/scan-offers and the offer normalizer."""

from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app
from app.services import gmail_scanner, google_auth

client = TestClient(app)


def test_scan_offers_returns_normalized_offers_and_validates_leg_ids():
    legs = client.get("/api/v1/legs").json()
    real_leg_id = legs[0]["id"]
    fake_offers = [
        {"program": "United MileagePlus", "kind": "flight",
         "title": "30% transfer bonus", "summary": "Bonus on transfers.",
         "expires": "2026-07-01", "promo_code": None, "leg_id": real_leg_id},
        {"program": None, "kind": "spaceship", "title": None, "summary": None,
         "expires": "soon", "promo_code": 123, "leg_id": "no-such-leg"},
    ]
    with patch.object(gmail_scanner, "scan_offers", return_value=[
        gmail_scanner._normalize_offer(dict(o)) for o in fake_offers
    ]):
        r = client.post("/api/v1/gmail/scan-offers")
    assert r.status_code == 200
    body = r.json()
    assert body["offer_count"] == 2
    first, second = body["offers"]
    assert first["leg_id"] == real_leg_id
    assert first["expires"] == "2026-07-01"
    # Garbage row was coerced, not dropped or 500'd.
    assert second["kind"] == "other"
    assert second["expires"] is None
    assert second["program"] == "Unknown program"
    assert second["promo_code"] == "123"
    assert second["leg_id"] is None  # unknown leg id nulled by the router


def test_scan_offers_error_mapping():
    with patch.object(
        gmail_scanner, "scan_offers",
        side_effect=gmail_scanner.GmailApiError("quota"),
    ):
        assert client.post("/api/v1/gmail/scan-offers").status_code == 502
    with patch.object(
        gmail_scanner, "scan_offers",
        side_effect=google_auth.GoogleNotConfiguredError("no token"),
    ):
        assert client.post("/api/v1/gmail/scan-offers").status_code == 503


def test_parse_offers_with_claude_handles_garbage():
    email = [{"subject": "s", "sender": "f", "date": "d", "snippet": "x", "body": "b"}]
    with patch.object(gmail_scanner, "call_chat", return_value="no json here"):
        assert gmail_scanner.parse_offers_with_claude(email, [], "2026-06-10") == []
    with patch.object(
        gmail_scanner, "call_chat",
        return_value='Sure:\n[{"kind": "hotel", "title": "2x points"}]',
    ):
        out = gmail_scanner.parse_offers_with_claude(email, [], "2026-06-10")
        assert out[0]["kind"] == "hotel"
        assert out[0]["title"] == "2x points"
