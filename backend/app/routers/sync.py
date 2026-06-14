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
from ..repositories.sync_repository import SyncRepository

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
        "updated_at is >= it (a delta), including tombstoned rows (deleted_at "
        "set) so deletes propagate. Omit for a full snapshot.",
    ),
    db: sqlite3.Connection = Depends(get_db),
):
    """
    Offline cache bundle (spec §9, §10). The Flutter client *merges* this into
    its local SQLite by last-write-wins (updated_at): we return EVERY row,
    including past legs / done tasks and tombstones, so the client never deletes
    a valid local record and soft-deletes propagate. `since` enables cheap delta
    sync; the client passes back `server_time`.

    Field set must match flutter/lib/services/sync_service.dart.
    """
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    today = date_cls.today().isoformat()

    repo = SyncRepository(db)
    data = repo.snapshot(since)
    leg_row = repo.current_leg_row(today)

    return SyncSnapshot(
        generated_at=now,
        server_time=now,
        is_delta=since is not None,
        current_leg=_row_to_leg(leg_row) if leg_row else None,
        trips=[Trip(**dict(r)) for r in data["trip"]],
        legs=[_row_to_leg(r) for r in data["leg"]],
        bookings=[_row_to_booking(r) for r in data["booking"]],
        tasks=[_row_to_task(r) for r in data["task"]],
        packing_items=[_row_to_packing(r) for r in data["packing_item"]],
        journal_entries=[JournalEntry(**dict(r)) for r in data["journal_entry"]],
    )
