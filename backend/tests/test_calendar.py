"""
Calendar router tests with mocked Google client. The real OAuth flow can't be
exercised without user credentials — these tests cover the contract paths
(503 when not configured, 502 on API error, response shape on success).
"""

from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from app.main import app
from app.services import calendar as cal_svc
from app.services import google_auth

client = TestClient(app)


def test_returns_503_when_google_not_configured():
    def _raise(*a, **kw):
        raise google_auth.GoogleNotConfiguredError("Google token not found at /tmp/x")

    with patch.object(cal_svc, "list_events", side_effect=_raise):
        r = client.get("/calendar/events")
    assert r.status_code == 503
    assert "Google token not found" in r.json()["detail"]


def test_returns_502_on_calendar_api_error():
    def _raise(*a, **kw):
        raise cal_svc.CalendarApiError("upstream 500")

    with patch.object(cal_svc, "list_events", side_effect=_raise):
        r = client.get("/calendar/events")
    assert r.status_code == 502
    assert "upstream 500" in r.json()["detail"]


def test_happy_path_returns_normalized_events():
    fake_events = [
        {
            "id": "evt1",
            "summary": "Hotel checkout",
            "description": "Wedgewood",
            "location": "Fairbanks",
            "start": {"dateTime": "2026-03-19T11:00:00Z"},
            "end": {"dateTime": "2026-03-19T12:00:00Z"},
            "htmlLink": "https://example.com/evt1",
            "status": "confirmed",
        },
        {
            "id": "evt2",
            "summary": "Train day",
            "start": {"date": "2026-04-15"},
            "end": {"date": "2026-04-16"},
            "status": "confirmed",
        },
    ]

    fake_service = MagicMock()
    fake_service.events.return_value.list.return_value.execute.return_value = {
        "items": fake_events
    }

    with patch.object(google_auth, "get_credentials", return_value=MagicMock()), \
         patch("app.services.calendar.build", return_value=fake_service):
        r = client.get("/calendar/events?from=2026-03-01T00:00:00Z&to=2026-04-30T00:00:00Z")

    assert r.status_code == 200
    body = r.json()
    assert len(body) == 2

    assert body[0]["id"] == "evt1"
    assert body[0]["summary"] == "Hotel checkout"
    assert body[0]["start"] == "2026-03-19T11:00:00Z"
    assert body[0]["all_day"] is False

    assert body[1]["all_day"] is True
    assert body[1]["start"] == "2026-04-15"


def test_rejects_invalid_iso_datetime():
    r = client.get("/calendar/events?from=not-a-date")
    assert r.status_code == 400
    assert "invalid ISO datetime" in r.json()["detail"]


def test_default_time_window_used_when_no_params():
    fake_service = MagicMock()
    fake_service.events.return_value.list.return_value.execute.return_value = {"items": []}

    with patch.object(google_auth, "get_credentials", return_value=MagicMock()), \
         patch("app.services.calendar.build", return_value=fake_service):
        r = client.get("/calendar/events")

    assert r.status_code == 200
    assert r.json() == []
    # Confirm the API was called with both timeMin and timeMax populated.
    call_kwargs = fake_service.events.return_value.list.call_args.kwargs
    assert "timeMin" in call_kwargs
    assert "timeMax" in call_kwargs


def test_summary_falls_back_when_missing():
    fake_service = MagicMock()
    fake_service.events.return_value.list.return_value.execute.return_value = {
        "items": [{"id": "x", "start": {"date": "2026-04-15"}, "end": {"date": "2026-04-16"}}]
    }

    with patch.object(google_auth, "get_credentials", return_value=MagicMock()), \
         patch("app.services.calendar.build", return_value=fake_service):
        r = client.get("/calendar/events")

    assert r.status_code == 200
    assert r.json()[0]["summary"] == "(no title)"
