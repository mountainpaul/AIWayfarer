import sqlite3
from datetime import date as date_cls, datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, Query

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
def snapshot(
    since: Optional[str] = Query(
        None,
        description="ISO timestamp cursor. When set, returns only rows whose "
        "updated_at is strictly greater (a delta), including tombstoned rows "
        "(deleted_at set) so deletes propagate. Omit for a full snapshot.",
    ),
    db: sqlite3.Connection = Depends(get_db),
):
    """
    Offline cache bundle (spec §9, §10). The Flutter client *merges* this into
    its local SQLite by last-write-wins (updated_at), so:

    - We return EVERY row, including past legs / done tasks and tombstones —
      completeness matters; the client decides what to show. (Dropping rows
      here previously caused the client to delete valid local records.)
    - deleted_at rides on every row so soft-deletes propagate.
    - `since` enables cheap delta sync; the client passes back `server_time`.

    Field set must match flutter/lib/services/sync_service.dart.
    """
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    today = date_cls.today().isoformat()

    # COALESCE(updated_at, created_at) guards rows whose updated_at was never set
    # (e.g. legacy journal rows before the timestamp backfill).
    def rows(table: str):
        if since is not None:
            # >= (not >) at the boundary: timestamps are second-granular, so a
            # change made in the same second as the cursor must not be missed.
            # Re-fetching boundary rows is harmless — the client merge is
            # idempotent (last-write-wins).
            return db.execute(
                f"SELECT * FROM {table} "
                f"WHERE COALESCE(updated_at, created_at) >= ? "
                f"ORDER BY COALESCE(updated_at, created_at) ASC",
                (since,),
            ).fetchall()
        return db.execute(f"SELECT * FROM {table}").fetchall()

    # current_leg is a convenience pointer for the home screen — never a tombstone.
    leg_row = db.execute(
        """SELECT * FROM leg
           WHERE deleted_at IS NULL
             AND date(?) BETWEEN date(start_date) AND date(end_date)
           ORDER BY start_date ASC LIMIT 1""",
        (today,),
    ).fetchone()
    current_leg = _row_to_leg(leg_row) if leg_row else None

    return SyncSnapshot(
        generated_at=now,
        server_time=now,
        is_delta=since is not None,
        current_leg=current_leg,
        trips=[Trip(**dict(r)) for r in rows("trip")],
        legs=[_row_to_leg(r) for r in rows("leg")],
        bookings=[_row_to_booking(r) for r in rows("booking")],
        tasks=[_row_to_task(r) for r in rows("task")],
        packing_items=[_row_to_packing(r) for r in rows("packing_item")],
        journal_entries=[JournalEntry(**dict(r)) for r in rows("journal_entry")],
    )
