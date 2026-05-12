import sqlite3
from datetime import date as date_cls, datetime, timezone
from fastapi import APIRouter, Depends

from ..db import get_db
from ..models import (
    Booking,
    JournalEntry,
    Leg,
    PackingItem,
    SyncSnapshot,
    Task,
    Trip,
)

router = APIRouter(prefix="/sync", tags=["sync"])


def _row_to_leg(row: sqlite3.Row) -> Leg:
    d = dict(row); d["is_schengen"] = bool(d["is_schengen"])
    return Leg(**d)


def _row_to_booking(row: sqlite3.Row) -> Booking:
    return Booking(**dict(row))


def _row_to_task(row: sqlite3.Row) -> Task:
    d = dict(row); d["is_done"] = bool(d["is_done"])
    return Task(**d)


def _row_to_packing(row: sqlite3.Row) -> PackingItem:
    d = dict(row); d["is_packed"] = bool(d["is_packed"])
    return PackingItem(**d)


@router.get("/snapshot", response_model=SyncSnapshot)
def snapshot(db: sqlite3.Connection = Depends(get_db)):
    """
    Offline cache bundle (spec §9, §10). Returns the full Trip HQ shape so the
    Flutter local SQLite cache can mirror the backend. Field set must match
    flutter/lib/services/sync_service.dart.
    """
    today = date_cls.today().isoformat()

    leg_row = db.execute(
        """SELECT * FROM legs WHERE date(?) BETWEEN date(start_date) AND date(end_date)
           ORDER BY start_date ASC LIMIT 1""",
        (today,),
    ).fetchone()
    current_leg = _row_to_leg(leg_row) if leg_row else None

    trip_rows = db.execute("SELECT * FROM trips ORDER BY start_date ASC").fetchall()
    leg_rows = db.execute("SELECT * FROM legs ORDER BY sort_order ASC").fetchall()

    # Bookings: include all of the current leg's history plus everything
    # current/future across the trip. Past legs are dropped to keep payload small.
    if current_leg:
        booking_rows = db.execute(
            """SELECT * FROM bookings
               WHERE leg_id = ?
                  OR end_date IS NULL
                  OR date(end_date) >= date(?)
               ORDER BY COALESCE(start_date, '9999') ASC""",
            (current_leg.id, today),
        ).fetchall()
    else:
        booking_rows = db.execute(
            """SELECT * FROM bookings
               WHERE end_date IS NULL OR date(end_date) >= date(?)
               ORDER BY COALESCE(start_date, '9999') ASC""",
            (today,),
        ).fetchall()

    # Tasks: open OR due today/later. Closed-and-overdue tasks dropped.
    task_rows = db.execute(
        """SELECT * FROM tasks
           WHERE is_done = 0 OR (due_date IS NOT NULL AND date(due_date) >= date(?))
           ORDER BY CASE priority
               WHEN 'critical' THEN 0 WHEN 'high' THEN 1
               WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END,
               COALESCE(due_date, '9999') ASC""",
        (today,),
    ).fetchall()

    packing_rows = db.execute(
        "SELECT * FROM packing_items ORDER BY sort_order ASC"
    ).fetchall()

    # Journal: most recent 200 entries.
    journal_rows = db.execute(
        "SELECT * FROM journal_entries ORDER BY created_at DESC LIMIT 200"
    ).fetchall()

    return SyncSnapshot(
        generated_at=datetime.now(timezone.utc).isoformat(timespec="seconds"),
        current_leg=current_leg,
        trips=[Trip(**dict(r)) for r in trip_rows],
        legs=[_row_to_leg(r) for r in leg_rows],
        bookings=[_row_to_booking(r) for r in booking_rows],
        tasks=[_row_to_task(r) for r in task_rows],
        packing_items=[_row_to_packing(r) for r in packing_rows],
        journal_entries=[JournalEntry(**dict(r)) for r in journal_rows],
    )
