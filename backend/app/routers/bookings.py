import sqlite3
import uuid
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import get_db
from ..models import Booking, BookingCreate, BookingUpdate
from ..services import changelog

router = APIRouter(prefix="/bookings", tags=["bookings"])


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _row_to_booking(row: sqlite3.Row) -> Booking:
    return Booking(**dict(row))


@router.get("", response_model=list[Booking])
def list_bookings(
    leg_id: Optional[str] = None,
    type: Optional[str] = None,
    status: Optional[str] = None,
    db: sqlite3.Connection = Depends(get_db),
):
    sql = "SELECT * FROM bookings"
    where = ["deleted_at IS NULL"]
    params: list = []
    if leg_id:
        where.append("leg_id = ?"); params.append(leg_id)
    if type:
        where.append("type = ?"); params.append(type)
    if status:
        where.append("status = ?"); params.append(status)
    if where:
        sql += " WHERE " + " AND ".join(where)
    # SQLite has no NULLS LAST — fold NULLs to the end via COALESCE.
    sql += " ORDER BY COALESCE(start_date, '9999') ASC, name ASC"
    rows = db.execute(sql, params).fetchall()
    return [_row_to_booking(r) for r in rows]


@router.get("/{booking_id}", response_model=Booking)
def get_booking(booking_id: str, db: sqlite3.Connection = Depends(get_db)):
    row = db.execute(
        "SELECT * FROM bookings WHERE id = ? AND deleted_at IS NULL", (booking_id,)
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="booking not found")
    return _row_to_booking(row)


@router.post("", response_model=Booking, status_code=201)
def create_booking(payload: BookingCreate, db: sqlite3.Connection = Depends(get_db)):
    leg = db.execute("SELECT id FROM legs WHERE id = ?", (payload.leg_id,)).fetchone()
    if not leg:
        raise HTTPException(status_code=400, detail="leg_id does not exist")

    new_id = str(uuid.uuid4())
    db.execute(
        """INSERT INTO bookings
           (id, leg_id, type, name, status, start_date, end_date, confirmation,
            cost_cents, currency, location_name, location_lat, location_lon, notes)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            new_id, payload.leg_id, payload.type, payload.name, payload.status,
            payload.start_date, payload.end_date, payload.confirmation,
            payload.cost_cents, payload.currency,
            payload.location_name, payload.location_lat, payload.location_lon,
            payload.notes,
        ),
    )
    row = db.execute("SELECT * FROM bookings WHERE id = ?", (new_id,)).fetchone()
    changelog.append(db, entity="booking", entity_id=new_id, op="create",
                     new=dict(row))
    return _row_to_booking(row)


@router.patch("/{booking_id}", response_model=Booking)
def update_booking(booking_id: str, payload: BookingUpdate, db: sqlite3.Connection = Depends(get_db)):
    existing = db.execute(
        "SELECT * FROM bookings WHERE id = ? AND deleted_at IS NULL", (booking_id,)
    ).fetchone()
    if not existing:
        raise HTTPException(status_code=404, detail="booking not found")
    fields = payload.model_dump(exclude_unset=True)
    if not fields:
        return _row_to_booking(existing)
    # Capture prior values of the fields being changed, so the change is undoable.
    old = {k: existing[k] for k in fields}
    set_clause = ", ".join(f"{k} = ?" for k in fields)
    params = list(fields.values()) + [booking_id]
    db.execute(
        f"UPDATE bookings SET {set_clause}, updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?",
        params,
    )
    changelog.append(db, entity="booking", entity_id=booking_id, op="update",
                     new=fields, old=old)
    row = db.execute("SELECT * FROM bookings WHERE id = ?", (booking_id,)).fetchone()
    return _row_to_booking(row)


@router.delete("/{booking_id}", status_code=204)
def delete_booking(booking_id: str, db: sqlite3.Connection = Depends(get_db)):
    # Soft delete: tombstone the row (set deleted_at) so it's recoverable and the
    # delete propagates to clients via sync. Never physically remove the row.
    now = _now()
    cur = db.execute(
        "UPDATE bookings SET deleted_at = ?, updated_at = ? "
        "WHERE id = ? AND deleted_at IS NULL",
        (now, now, booking_id),
    )
    if cur.rowcount == 0:
        raise HTTPException(status_code=404, detail="booking not found")
    changelog.append(db, entity="booking", entity_id=booking_id, op="delete")
    return None
