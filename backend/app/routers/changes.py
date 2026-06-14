"""Change-log feed + undo (docs/sync-redesign-v2-change-log.md).

GET /changes        — history / audit / future delta-sync feed (read-only).
POST /changes/{id}/undo — append-only undo: applies the inverse to the
                          projection AND records it as a new change, so the undo
                          is itself auditable and redoable (redo = undo the undo).
"""
import json
import sqlite3
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import get_db
from ..services import changelog

router = APIRouter(prefix="/changes", tags=["changes"])


def _to_change(row: sqlite3.Row) -> dict:
    d = dict(row)
    d["patch"] = json.loads(d["patch"]) if d.get("patch") else None
    return d


@router.get("")
def list_changes(
    since_seq: int = Query(0, description="Return events with seq > this cursor."),
    entity: Optional[str] = None,
    entity_id: Optional[str] = None,
    limit: int = Query(500, le=5000),
    db: sqlite3.Connection = Depends(get_db),
):
    where = ["seq > ?"]
    params: list = [since_seq]
    if entity:
        where.append("entity = ?"); params.append(entity)
    if entity_id:
        where.append("entity_id = ?"); params.append(entity_id)
    params.append(limit)
    rows = db.execute(
        f"SELECT * FROM change WHERE {' AND '.join(where)} ORDER BY seq ASC LIMIT ?",
        params,
    ).fetchall()
    return [_to_change(r) for r in rows]


@router.post("/{change_id}/undo")
def undo_change(change_id: str, db: sqlite3.Connection = Depends(get_db)):
    target = db.execute(
        "SELECT * FROM change WHERE change_id = ?", (change_id,)
    ).fetchone()
    if not target:
        raise HTTPException(status_code=404, detail="change not found")

    entity = target["entity"]
    entity_id = target["entity_id"]
    table = changelog.ENTITY_TABLE.get(entity)
    if table is None:
        raise HTTPException(status_code=400, detail=f"cannot undo entity '{entity}'")

    op = target["op"]
    patch = json.loads(target["patch"]) if target["patch"] else {}
    now = changelog.now_iso()

    # Each branch applies the inverse to the projection, then records the undo
    # using the op that describes its projection effect (so the undo is itself
    # undoable → redo).
    if op in ("create", "restore"):
        # Inverse of "row now exists/visible" is to tombstone it.
        db.execute(
            f"UPDATE {table} SET deleted_at = ?, updated_at = ? WHERE id = ?",
            (now, now, entity_id),
        )
        changelog.append(db, entity=entity, entity_id=entity_id, op="delete",
                         undoes=change_id)
    elif op == "delete":
        # Inverse of a delete is to restore (clear the tombstone).
        db.execute(
            f"UPDATE {table} SET deleted_at = NULL, updated_at = ? WHERE id = ?",
            (now, entity_id),
        )
        changelog.append(db, entity=entity, entity_id=entity_id, op="restore",
                         undoes=change_id)
    elif op == "update":
        old = patch.get("old") or {}
        if not old:
            raise HTTPException(status_code=400,
                                detail="change carries no prior values to restore")
        current = changelog.row_dict(db, table, entity_id) or {}
        prior_current = {k: current.get(k) for k in old}
        set_clause = ", ".join(f"{k} = ?" for k in old)
        db.execute(
            f"UPDATE {table} SET {set_clause}, updated_at = ? WHERE id = ?",
            list(old.values()) + [now, entity_id],
        )
        # Record as an update whose 'old' is the state we just replaced, so
        # undoing this undo (redo) restores it.
        changelog.append(db, entity=entity, entity_id=entity_id, op="update",
                         new=old, old=prior_current, undoes=change_id)
    else:
        raise HTTPException(status_code=400, detail=f"cannot undo op '{op}'")

    restored = changelog.row_dict(db, table, entity_id)
    return {"undone": change_id, "entity": entity, "entity_id": entity_id,
            "state": restored}
