"""Change-log feed + undo (docs/sync-redesign-v2-change-log.md).

GET /changes        — history / audit / delta-sync feed (read-only).
POST /changes/{id}/undo — append-only undo: applies the inverse to the
                          projection AND records it as a new change, so the undo
                          is itself auditable and redoable (redo = undo the undo).
"""
import sqlite3
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import get_db
from ..repositories.change_repository import ChangeRepository, UndoError

router = APIRouter(prefix="/changes", tags=["changes"])


@router.get("")
def list_changes(
    since_seq: int = Query(0, description="Return events with seq > this cursor."),
    entity: Optional[str] = None,
    entity_id: Optional[str] = None,
    limit: int = Query(500, le=5000),
    db: sqlite3.Connection = Depends(get_db),
):
    return ChangeRepository(db).feed(
        since_seq=since_seq, entity=entity, entity_id=entity_id, limit=limit
    )


@router.post("/{change_id}/undo")
def undo_change(change_id: str, db: sqlite3.Connection = Depends(get_db)):
    try:
        return ChangeRepository(db).undo(change_id)
    except UndoError as e:
        raise HTTPException(status_code=e.status, detail=e.message)
