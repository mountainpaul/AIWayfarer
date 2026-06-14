import sqlite3
from datetime import date as date_cls
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import get_db
from ..models import Leg, LegUpdate

router = APIRouter(prefix="/legs", tags=["legs"])


def _row_to_leg(row: sqlite3.Row) -> Leg:
    d = dict(row)
    d["is_schengen"] = bool(d["is_schengen"])
    return Leg(**d)


@router.get("", response_model=list[Leg])
def list_legs(
    trip_id: Optional[str] = None,
    db: sqlite3.Connection = Depends(get_db),
):
    if trip_id:
        rows = db.execute("SELECT * FROM leg WHERE trip_id = ? ORDER BY sort_order ASC", (trip_id,)).fetchall()
    else:
        rows = db.execute("SELECT * FROM leg ORDER BY sort_order ASC").fetchall()
    return [_row_to_leg(r) for r in rows]


@router.get("/current", response_model=Optional[Leg])
def current_leg(
    date: Optional[str] = Query(None, description="ISO date YYYY-MM-DD; defaults to today UTC"),
    db: sqlite3.Connection = Depends(get_db),
):
    day = date or date_cls.today().isoformat()
    row = db.execute(
        """SELECT * FROM leg WHERE date(?) BETWEEN date(start_date) AND date(end_date)
           ORDER BY start_date ASC LIMIT 1""",
        (day,),
    ).fetchone()
    return _row_to_leg(row) if row else None


@router.get("/{leg_id}", response_model=Leg)
def get_leg(leg_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = db.execute("SELECT * FROM leg WHERE id = ?", (leg_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="leg not found")
    return _row_to_leg(row)


@router.patch("/{leg_id}", response_model=Leg)
def update_leg(leg_id: str, payload: LegUpdate, db: sqlite3.Connection = Depends(get_db)):
    existing = db.execute("SELECT * FROM leg WHERE id = ?", (leg_id,)).fetchone()
    if not existing:
        raise HTTPException(status_code=404, detail="leg not found")

    fields = payload.model_dump(exclude_unset=True)
    if not fields:
        return _row_to_leg(existing)

    if "is_schengen" in fields:
        fields["is_schengen"] = 1 if fields["is_schengen"] else 0

    set_clause = ", ".join(f"{k} = ?" for k in fields)
    params = list(fields.values()) + [leg_id]
    db.execute(
        f"UPDATE leg SET {set_clause}, updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?",
        params,
    )
    row = db.execute("SELECT * FROM leg WHERE id = ?", (leg_id,)).fetchone()
    return _row_to_leg(row)
