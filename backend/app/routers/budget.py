import sqlite3
from typing import Optional

from fastapi import APIRouter, Depends

from ..db import get_db
from ..models import BudgetReport
from ..repositories.booking_repository import BookingRepository
from ..repositories.leg_repository import LegRepository
from ..services import budget as budget_svc

router = APIRouter(prefix="/budget", tags=["budget"])


@router.get("", response_model=BudgetReport)
def budget_rollup(
    trip_id: Optional[str] = None,
    db: sqlite3.Connection = Depends(get_db),
):
    """Planned (leg budgets) vs actual (booking costs), grouped by currency."""
    leg_filters = {"trip_id": trip_id} if trip_id else {}
    legs = LegRepository(db).list(leg_filters)
    bookings = BookingRepository(db).list()
    return budget_svc.report(legs, bookings)
