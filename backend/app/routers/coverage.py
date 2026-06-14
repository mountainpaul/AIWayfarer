import sqlite3
from typing import Optional

from fastapi import APIRouter, Depends

from ..db import get_db
from ..models import CoverageItem
from ..repositories.booking_repository import BookingRepository
from ..repositories.leg_repository import LegRepository
from ..services import coverage as coverage_svc

router = APIRouter(prefix="/coverage", tags=["coverage"])


@router.get("", response_model=list[CoverageItem])
def accommodation_coverage(
    trip_id: Optional[str] = None,
    db: sqlite3.Connection = Depends(get_db),
):
    """Per-leg lodging coverage: total nights, booked nights, unbooked nights."""
    leg_filters = {"trip_id": trip_id} if trip_id else {}
    legs = LegRepository(db).list(leg_filters, order_by="sort_order ASC")
    bookings = BookingRepository(db).list()  # active accommodation among them
    return coverage_svc.report(legs, bookings)
