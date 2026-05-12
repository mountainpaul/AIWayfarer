"""
GET /calendar/events — read-only Google Calendar adapter (spec §5).

Replaces the calendar_stub. If Google credentials aren't configured yet,
returns 503 with instructions to run scripts/google_auth.py.
"""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, Query

from ..services import calendar as cal_svc
from ..services import google_auth

router = APIRouter(prefix="/calendar", tags=["calendar"])


def _parse_iso(s: Optional[str]) -> Optional[datetime]:
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"invalid ISO datetime: {s}",
        )


@router.get("/events")
def list_events(
    time_min: Optional[str] = Query(None, alias="from", description="ISO 8601 datetime; defaults to now"),
    time_max: Optional[str] = Query(None, alias="to", description="ISO 8601 datetime; defaults to now + 30 days"),
    calendar_id: str = Query("primary"),
    max_results: int = Query(250, ge=1, le=2500),
):
    try:
        return cal_svc.list_events(
            time_min=_parse_iso(time_min),
            time_max=_parse_iso(time_max),
            calendar_id=calendar_id,
            max_results=max_results,
        )
    except google_auth.GoogleNotConfiguredError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except cal_svc.CalendarApiError as e:
        raise HTTPException(status_code=502, detail=str(e))
