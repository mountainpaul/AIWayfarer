"""BaseRepository — the single place SQL execution, soft-delete, and change-log
generation live (BEST_PRACTICES.md §2.1). Routers stay thin and call these
methods; concrete per-entity repositories subclass this and set `table`,
`entity`, and optional `bool_columns`.

SQL identifiers (`table`, column names) come only from trusted code — the
subclass `table` and Pydantic-derived field names — never from raw user input,
so the f-string interpolation here is safe (values are always parameterized).
"""
import sqlite3
import uuid
from datetime import datetime, timezone
from typing import Any, Optional

from ..services import changelog


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


class BaseRepository:
    #: singular table name (e.g. "booking")
    table: str = ""
    #: change-log entity name (e.g. "booking"); empty disables logging
    entity: str = ""
    #: columns stored as INTEGER 0/1 but exposed as bool
    bool_columns: tuple[str, ...] = ()

    def __init__(self, db: sqlite3.Connection):
        self.db = db

    # ── helpers ────────────────────────────────────────────────
    def _encode(self, data: dict) -> dict:
        out = dict(data)
        for k in self.bool_columns:
            if isinstance(out.get(k), bool):
                out[k] = 1 if out[k] else 0
        return out

    def _log(self, entity_id: str, op: str, **kw) -> None:
        if self.entity:
            changelog.append(self.db, entity=self.entity, entity_id=entity_id,
                             op=op, **kw)

    # ── reads ──────────────────────────────────────────────────
    def list(
        self,
        filters: Optional[dict] = None,
        *,
        include_deleted: bool = False,
        order_by: Optional[str] = None,
        limit: Optional[int] = None,
    ) -> list[dict]:
        where, params = [], []
        if not include_deleted:
            where.append("deleted_at IS NULL")
        for col, val in (filters or {}).items():
            where.append(f"{col} = ?")
            params.append(val)
        sql = f"SELECT * FROM {self.table}"
        if where:
            sql += " WHERE " + " AND ".join(where)
        if order_by:
            sql += f" ORDER BY {order_by}"
        if limit is not None:
            sql += " LIMIT ?"
            params.append(limit)
        return [dict(r) for r in self.db.execute(sql, params).fetchall()]

    def get(self, entity_id: str, *, include_deleted: bool = False) -> Optional[dict]:
        sql = f"SELECT * FROM {self.table} WHERE id = ?"
        if not include_deleted:
            sql += " AND deleted_at IS NULL"
        row = self.db.execute(sql, (entity_id,)).fetchone()
        return dict(row) if row is not None else None

    # ── writes (each appends to the change log) ────────────────
    def create(self, data: dict, *, entity_id: Optional[str] = None) -> dict:
        new_id = entity_id or str(uuid.uuid4())
        enc = self._encode(data)
        cols = list(enc.keys())
        placeholders = ", ".join("?" for _ in cols)
        col_sql = ", ".join(cols)
        self.db.execute(
            f"INSERT INTO {self.table} (id, {col_sql}) VALUES (?, {placeholders})",
            [new_id, *enc.values()],
        )
        row = self.get(new_id, include_deleted=True)
        self._log(new_id, "create", new=row)
        return row  # type: ignore[return-value]

    def update(self, entity_id: str, patch: dict) -> Optional[dict]:
        existing = self.get(entity_id)
        if existing is None:
            return None
        if not patch:
            return existing
        enc = self._encode(patch)
        old = {k: existing.get(k) for k in enc}
        set_clause = ", ".join(f"{k} = ?" for k in enc)
        self.db.execute(
            f"UPDATE {self.table} SET {set_clause}, updated_at = ? WHERE id = ?",
            [*enc.values(), _now(), entity_id],
        )
        self._log(entity_id, "update", new=enc, old=old)
        return self.get(entity_id)

    def soft_delete(self, entity_id: str) -> bool:
        now = _now()
        cur = self.db.execute(
            f"UPDATE {self.table} SET deleted_at = ?, updated_at = ? "
            f"WHERE id = ? AND deleted_at IS NULL",
            (now, now, entity_id),
        )
        if cur.rowcount == 0:
            return False
        self._log(entity_id, "delete")
        return True
