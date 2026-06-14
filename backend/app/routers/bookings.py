import sqlite3
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db
from ..models import Booking, BookingCreate, BookingUpdate
from ..repositories.booking_repository import BookingRepository
from ..repositories.leg_repository import LegRepository

router = APIRouter(prefix="/bookings", tags=["bookings"])


@router.get("", response_model=list[Booking])
def list_bookings(
    leg_id: Optional[str] = None,
    type: Optional[str] = None,
    status: Optional[str] = None,
    db: sqlite3.Connection = Depends(get_db),
):
    filters = {
        k: v for k, v in {"leg_id": leg_id, "type": type, "status": status}.items()
        if v is not None
    }
    repo = BookingRepository(db)
    rows = repo.list(filters, order_by=repo.default_order)
    return [Booking(**r) for r in rows]


@router.get("/{booking_id}", response_model=Booking)
def get_booking(booking_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = BookingRepository(db).get(booking_id)
    if row is None:
        raise HTTPException(status_code=404, detail="booking not found")
    return Booking(**row)


@router.post("", response_model=Booking, status_code=201)
def create_booking(payload: BookingCreate, db: sqlite3.Connection = Depends(get_db)):
    if LegRepository(db).get(payload.leg_id) is None:
        raise HTTPException(status_code=400, detail="leg_id does not exist")
    row = BookingRepository(db).create(payload.model_dump())
    return Booking(**row)


@router.patch("/{booking_id}", response_model=Booking)
def update_booking(
    booking_id: str, payload: BookingUpdate, db: sqlite3.Connection = Depends(get_db)
):
    row = BookingRepository(db).update(
        booking_id, payload.model_dump(exclude_unset=True)
    )
    if row is None:
        raise HTTPException(status_code=404, detail="booking not found")
    return Booking(**row)


@router.delete("/{booking_id}", status_code=204)
def delete_booking(booking_id: str, db: sqlite3.Connection = Depends(get_db)):
    if not BookingRepository(db).soft_delete(booking_id):
        raise HTTPException(status_code=404, detail="booking not found")
    return None
