import sqlite3
from fastapi import APIRouter, Depends, HTTPException

from ..db import get_db
from ..models import Trip

router = APIRouter(prefix="/trips", tags=["trips"])


@router.get("", response_model=list[Trip])
def list_trips(db: sqlite3.Connection = Depends(get_db)):
    rows = db.execute("SELECT * FROM trips ORDER BY start_date ASC").fetchall()
    return [Trip(**dict(r)) for r in rows]


@router.get("/{trip_id}", response_model=Trip)
def get_trip(trip_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = db.execute("SELECT * FROM trips WHERE id = ?", (trip_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="trip not found")
    return Trip(**dict(row))
