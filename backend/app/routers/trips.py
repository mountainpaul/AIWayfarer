import sqlite3

from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db
from ..models import Trip, TripCreate, TripUpdate
from ..repositories.trip_repository import TripRepository

router = APIRouter(prefix="/trips", tags=["trips"])


@router.get("", response_model=list[Trip])
def list_trips(db: sqlite3.Connection = Depends(get_db)):
    repo = TripRepository(db)
    return [Trip(**r) for r in repo.list(order_by=repo.default_order)]


@router.get("/{trip_id}", response_model=Trip)
def get_trip(trip_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = TripRepository(db).get(trip_id)
    if row is None:
        raise HTTPException(status_code=404, detail="trip not found")
    return Trip(**row)


@router.post("", response_model=Trip, status_code=201)
def create_trip(payload: TripCreate, db: sqlite3.Connection = Depends(get_db)):
    row = TripRepository(db).create(payload.model_dump())
    return Trip(**row)


@router.patch("/{trip_id}", response_model=Trip)
def update_trip(
    trip_id: str, payload: TripUpdate, db: sqlite3.Connection = Depends(get_db)
):
    row = TripRepository(db).update(trip_id, payload.model_dump(exclude_unset=True))
    if row is None:
        raise HTTPException(status_code=404, detail="trip not found")
    return Trip(**row)


@router.delete("/{trip_id}", status_code=204)
def delete_trip(trip_id: str, db: sqlite3.Connection = Depends(get_db)):
    if not TripRepository(db).soft_delete(trip_id):
        raise HTTPException(status_code=404, detail="trip not found")
    return None
