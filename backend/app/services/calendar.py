"""
Google Calendar read-only adapter (spec §5, §6).

Thin wrapper around googleapiclient.discovery — list events on a date range
and map Google's event shape into something the frontend can consume directly.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

from . import google_auth


class CalendarApiError(RuntimeError):
    pass


def _service():
    creds = google_auth.get_credentials()
    return build("calendar", "v3", credentials=creds, cache_discovery=False)


def _to_iso(dt: datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.isoformat()


def _event_time(node: dict) -> Optional[str]:
    """Google returns either {dateTime: ..., timeZone: ...} or {date: ...} (all-day)."""
    if not node:
        return None
    return node.get("dateTime") or node.get("date")


def _normalize(event: dict) -> dict:
    """Map Google's event shape to a stable internal one."""
    return {
        "id": event.get("id"),
        "summary": event.get("summary") or "(no title)",
        "description": event.get("description"),
        "location": event.get("location"),
        "start": _event_time(event.get("start")),
        "end": _event_time(event.get("end")),
        "all_day": "date" in (event.get("start") or {}),
        "html_link": event.get("htmlLink"),
        "status": event.get("status"),
    }


def list_events(
    *,
    time_min: Optional[datetime] = None,
    time_max: Optional[datetime] = None,
    calendar_id: str = "primary",
    max_results: int = 250,
) -> list[dict]:
    """
    Return events from `calendar_id` between `time_min` and `time_max`.
    Defaults: now → +30 days. Sorted by start time ascending.
    """
    now = datetime.now(timezone.utc)
    time_min = time_min or now
    time_max = time_max or (now + timedelta(days=30))

    try:
        resp = (
            _service()
            .events()
            .list(
                calendarId=calendar_id,
                timeMin=_to_iso(time_min),
                timeMax=_to_iso(time_max),
                singleEvents=True,
                orderBy="startTime",
                maxResults=max_results,
            )
            .execute()
        )
    except HttpError as e:
        raise CalendarApiError(f"Google Calendar API error: {e}") from e

    return [_normalize(e) for e in resp.get("items", [])]
