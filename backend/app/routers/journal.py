import sqlite3
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import get_db
from ..models import JournalEntry, JournalEntryCreate
from ..repositories.journal_repository import JournalRepository
from ..repositories.leg_repository import LegRepository

router = APIRouter(prefix="/journal", tags=["journal"])


@router.get("", response_model=list[JournalEntry])
def list_entries(
    leg_id: Optional[str] = None,
    entry_type: Optional[str] = None,
    limit: int = Query(100, ge=1, le=1000),
    db: sqlite3.Connection = Depends(get_db),
):
    filters = {
        k: v for k, v in {"leg_id": leg_id, "entry_type": entry_type}.items()
        if v is not None
    }
    repo = JournalRepository(db)
    rows = repo.list(filters, order_by=repo.default_order, limit=limit)
    return [JournalEntry(**r) for r in rows]


@router.post("", response_model=JournalEntry, status_code=201)
def create_entry(payload: JournalEntryCreate, db: sqlite3.Connection = Depends(get_db)):
    """Append-only. Per spec §6, journal entries are autonomous (no approval gate)."""
    if payload.leg_id and LegRepository(db).get(payload.leg_id) is None:
        raise HTTPException(status_code=400, detail="leg_id does not exist")
    row = JournalRepository(db).create(payload.model_dump())
    return JournalEntry(**row)
