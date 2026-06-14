import sqlite3
import uuid
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import get_db
from ..models import JournalEntry, JournalEntryCreate

router = APIRouter(prefix="/journal", tags=["journal"])


@router.get("", response_model=list[JournalEntry])
def list_entries(
    leg_id: Optional[str] = None,
    entry_type: Optional[str] = None,
    limit: int = Query(100, ge=1, le=1000),
    db: sqlite3.Connection = Depends(get_db),
):
    sql = "SELECT * FROM journal_entry"
    where: list[str] = []
    params: list = []
    if leg_id:
        where.append("leg_id = ?"); params.append(leg_id)
    if entry_type:
        where.append("entry_type = ?"); params.append(entry_type)
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " ORDER BY created_at DESC LIMIT ?"
    params.append(limit)
    rows = db.execute(sql, params).fetchall()
    return [JournalEntry(**dict(r)) for r in rows]


@router.post("", response_model=JournalEntry, status_code=201)
def create_entry(payload: JournalEntryCreate, db: sqlite3.Connection = Depends(get_db)):
    """Append-only. Per spec §6, journal entries are autonomous (no approval gate)."""
    if payload.leg_id:
        leg = db.execute("SELECT id FROM leg WHERE id = ?", (payload.leg_id,)).fetchone()
        if not leg:
            raise HTTPException(status_code=400, detail="leg_id does not exist")
    new_id = str(uuid.uuid4())
    db.execute(
        """INSERT INTO journal_entry
           (id, leg_id, content, entry_type, location_name, location_lat, location_lon)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        (new_id, payload.leg_id, payload.content, payload.entry_type,
         payload.location_name, payload.location_lat, payload.location_lon),
    )
    row = db.execute("SELECT * FROM journal_entry WHERE id = ?", (new_id,)).fetchone()
    return JournalEntry(**dict(row))
