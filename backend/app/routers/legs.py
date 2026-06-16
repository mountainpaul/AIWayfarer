import sqlite3
from datetime import date as date_cls
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import get_db
from ..models import Leg, LegCreate, LegUpdate
from ..repositories.leg_repository import LegRepository
from ..repositories.trip_repository import TripRepository

router = APIRouter(prefix="/legs", tags=["legs"])


@router.get("", response_model=list[Leg])
def list_legs(
    trip_id: Optional[str] = None,
    db: sqlite3.Connection = Depends(get_db),
):
    filters = {"trip_id": trip_id} if trip_id else {}
    repo = LegRepository(db)
    return [Leg(**r) for r in repo.list(filters, order_by=repo.default_order)]


@router.get("/current", response_model=Optional[Leg])
def current_leg(
    date: Optional[str] = Query(
        None, description="ISO date YYYY-MM-DD; defaults to today UTC"
    ),
    db: sqlite3.Connection = Depends(get_db),
):
    day = date or date_cls.today().isoformat()
    row = LegRepository(db).current(day)
    return Leg(**row) if row else None


@router.get("/{leg_id}", response_model=Leg)
def get_leg(leg_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = LegRepository(db).get(leg_id)
    if row is None:
        raise HTTPException(status_code=404, detail="leg not found")
    return Leg(**row)


@router.post("", response_model=Leg, status_code=201)
def create_leg(payload: LegCreate, db: sqlite3.Connection = Depends(get_db)):
    if TripRepository(db).get(payload.trip_id) is None:
        raise HTTPException(status_code=400, detail="trip_id does not exist")
    repo = LegRepository(db)
    data = payload.model_dump()
    if not data.get("slug"):
        data["slug"] = repo.unique_slug(data["name"])
    row = repo.create(data)
    return Leg(**row)


@router.patch("/{leg_id}", response_model=Leg)
def update_leg(leg_id: str, payload: LegUpdate, db: sqlite3.Connection = Depends(get_db)):
    row = LegRepository(db).update(leg_id, payload.model_dump(exclude_unset=True))
    if row is None:
        raise HTTPException(status_code=404, detail="leg not found")
    return Leg(**row)


@router.delete("/{leg_id}", status_code=204)
def delete_leg(leg_id: str, db: sqlite3.Connection = Depends(get_db)):
    if not LegRepository(db).soft_delete(leg_id):
        raise HTTPException(status_code=404, detail="leg not found")
    return None
