import sqlite3
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, Query

from ..db import get_db
from ..models import GPS, GroundingPayload
from ..services import grounding as grounding_svc

router = APIRouter(prefix="/grounding", tags=["grounding"])


@router.get("", response_model=GroundingPayload)
def get_grounding(
    lat: Optional[float] = Query(None),
    lon: Optional[float] = Query(None),
    now: Optional[str] = Query(None, description="ISO 8601 datetime; defaults to UTC now"),
    db: sqlite3.Connection = Depends(get_db),
):
    when: datetime
    if now:
        try:
            when = datetime.fromisoformat(now.replace("Z", "+00:00"))
        except ValueError:
            when = datetime.now(timezone.utc)
    else:
        when = datetime.now(timezone.utc)

    gps = GPS(lat=lat, lon=lon) if (lat is not None and lon is not None) else None
    return grounding_svc.build_grounding_context(db, gps=gps, now=when)
