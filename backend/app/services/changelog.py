"""Append-only change log (docs/sync-redesign-v2-change-log.md).

Every mutation appends an immutable event here *and* updates the entity table
(the projection), so the full history is preserved — enabling audit, recovery
of overwritten values, and undo/redo. Writes happen inside the request's DB
transaction (see db.get_db), so the event and the projection update commit
together.
"""
import json
import sqlite3
import uuid
from datetime import datetime, timezone
from typing import Optional

# entity name -> projection table. The single place that knows the mapping.
ENTITY_TABLE = {
    "booking": "booking",
    "task": "task",
    "packing": "packing_item",
    "trip": "trip",
    "leg": "leg",
}


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def append(
    db: sqlite3.Connection,
    *,
    entity: str,
    entity_id: str,
    op: str,
    new: Optional[dict] = None,
    old: Optional[dict] = None,
    undoes: Optional[str] = None,
    change_id: Optional[str] = None,
    device: Optional[str] = None,
    client_ts: Optional[str] = None,
) -> str:
    """Record one change event. Idempotent on change_id (INSERT OR IGNORE), so a
    client retrying a queued op never duplicates it. Returns the change_id."""
    cid = change_id or str(uuid.uuid4())
    db.execute(
        """INSERT OR IGNORE INTO change
               (change_id, entity, entity_id, op, patch, undoes, device, client_ts, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            cid,
            entity,
            entity_id,
            op,
            json.dumps({"new": new, "old": old}),
            undoes,
            device,
            client_ts or now_iso(),
            now_iso(),
        ),
    )
    return cid


def row_dict(db: sqlite3.Connection, table: str, entity_id: str) -> Optional[dict]:
    """Current projection row as a plain dict (or None)."""
    r = db.execute(f"SELECT * FROM {table} WHERE id = ?", (entity_id,)).fetchone()
    return dict(r) if r is not None else None
