import sqlite3
from datetime import date as date_cls
from typing import Optional

from fastapi import APIRouter, Depends, Query

from ..db import get_db
from ..models import SchengenReport
from ..repositories.leg_repository import LegRepository
from ..services import schengen as schengen_svc

router = APIRouter(prefix="/schengen", tags=["schengen"])


@router.get("", response_model=SchengenReport)
def schengen_status(
    as_of: Optional[str] = Query(
        None, description="ISO date YYYY-MM-DD; defaults to today UTC"
    ),
    trip_id: Optional[str] = Query(
        None, description="Limit to one trip's legs; omit for all legs"
    ),
    db: sqlite3.Connection = Depends(get_db),
):
    """Schengen 90/180 usage for a reference date, plus worst-case peak."""
    day = date_cls.fromisoformat(as_of) if as_of else date_cls.today()
    filters = {"trip_id": trip_id} if trip_id else {}
    legs = LegRepository(db).list(filters)
    return schengen_svc.report(legs, day)
