import sqlite3
from datetime import datetime, timezone

from app import config
from app.models import GPS
from app.services import grounding as grounding_svc


def _conn() -> sqlite3.Connection:
    c = sqlite3.connect(config.DB_PATH)
    c.row_factory = sqlite3.Row
    return c


def test_find_current_leg_in_sicily_window():
    leg = grounding_svc.find_current_leg(_conn(), "2026-04-15")
    assert leg is not None
    assert leg["slug"] == "sicily"


def test_find_current_leg_returns_none_outside_trip():
    leg = grounding_svc.find_current_leg(_conn(), "2030-01-01")
    assert leg is None


def test_todays_bookings_includes_start_date_match():
    # gc01 (CUN→SEA) starts on 2026-03-11 per the seed.
    bks = grounding_svc.todays_bookings(_conn(), "2026-03-11")
    assert any("CUN" in b.get("name", "") or "SEA" in b.get("name", "") for b in bks)


def test_todays_bookings_includes_span_match():
    # Wedgewood Resort: 2026-03-12 → 2026-03-19. 2026-03-15 is in-window.
    bks = grounding_svc.todays_bookings(_conn(), "2026-03-15")
    assert any("Wedgewood" in b.get("name", "") for b in bks)


def test_open_tasks_count_is_positive_in_seed():
    n = grounding_svc.open_tasks_count(_conn())
    assert n > 0


def test_next_booking_after_returns_chronologically_first_future():
    nb = grounding_svc.next_booking_after(_conn(), "2026-04-26")
    assert nb is not None
    # The next booking on or after 2026-04-26 should not be earlier than that.
    assert nb["start_date"] >= "2026-04-26"


def test_build_grounding_context_assembles_payload():
    now = datetime(2026, 4, 15, 12, 0, tzinfo=timezone.utc)
    payload = grounding_svc.build_grounding_context(
        _conn(), gps=GPS(lat=37.06, lon=15.29), now=now
    )
    assert payload.now.startswith("2026-04-15")
    assert payload.gps and payload.gps.lat == 37.06
    assert payload.current_leg is not None
    assert payload.current_leg["slug"] == "sicily"
    assert payload.open_tasks_count >= 0


def test_grounding_to_text_renders_known_fields():
    now = datetime(2026, 4, 15, 12, 0, tzinfo=timezone.utc)
    payload = grounding_svc.build_grounding_context(
        _conn(), gps=GPS(lat=37.06, lon=15.29), now=now
    )
    text = grounding_svc.grounding_to_text(payload)
    assert "Now:" in text
    assert "GPS: 37.0600, 15.2900" in text
    assert "Sicily" in text
    assert "Open tasks:" in text


def test_grounding_to_text_handles_no_gps_no_leg():
    now = datetime(2030, 1, 1, 0, 0, tzinfo=timezone.utc)
    payload = grounding_svc.build_grounding_context(_conn(), gps=None, now=now)
    text = grounding_svc.grounding_to_text(payload)
    assert "GPS: (not provided)" in text
    assert "Current leg: (none" in text
