"""Change-log repository: the append-only feed and append-only undo
(docs/sync-redesign-v2-change-log.md). Owns all SQL against the `change` table
and the projection-table inverses that undo applies."""
import json
import sqlite3

from ..services import changelog


class UndoError(Exception):
    """Undo could not be applied; carries the HTTP status the router should use."""

    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status
        self.message = message


class ChangeRepository:
    def __init__(self, db: sqlite3.Connection):
        self.db = db

    @staticmethod
    def _parse(row: sqlite3.Row) -> dict:
        d = dict(row)
        d["patch"] = json.loads(d["patch"]) if d.get("patch") else None
        return d

    def feed(self, *, since_seq: int = 0, entity=None, entity_id=None,
             limit: int = 500) -> list[dict]:
        where = ["seq > ?"]
        params: list = [since_seq]
        if entity:
            where.append("entity = ?"); params.append(entity)
        if entity_id:
            where.append("entity_id = ?"); params.append(entity_id)
        params.append(limit)
        rows = self.db.execute(
            f"SELECT * FROM change WHERE {' AND '.join(where)} "
            f"ORDER BY seq ASC LIMIT ?",
            params,
        ).fetchall()
        return [self._parse(r) for r in rows]

    def undo(self, change_id: str) -> dict:
        target = self.db.execute(
            "SELECT * FROM change WHERE change_id = ?", (change_id,)
        ).fetchone()
        if not target:
            raise UndoError(404, "change not found")

        entity = target["entity"]
        entity_id = target["entity_id"]
        table = changelog.ENTITY_TABLE.get(entity)
        if table is None:
            raise UndoError(400, f"cannot undo entity '{entity}'")

        op = target["op"]
        patch = json.loads(target["patch"]) if target["patch"] else {}
        now = changelog.now_iso()

        # Apply the inverse to the projection, then record the undo using the op
        # that describes its projection effect (so the undo is itself undoable).
        if op in ("create", "restore"):
            self.db.execute(
                f"UPDATE {table} SET deleted_at = ?, updated_at = ? WHERE id = ?",
                (now, now, entity_id),
            )
            changelog.append(self.db, entity=entity, entity_id=entity_id,
                             op="delete", undoes=change_id)
        elif op == "delete":
            self.db.execute(
                f"UPDATE {table} SET deleted_at = NULL, updated_at = ? WHERE id = ?",
                (now, entity_id),
            )
            changelog.append(self.db, entity=entity, entity_id=entity_id,
                             op="restore", undoes=change_id)
        elif op == "update":
            old = patch.get("old") or {}
            if not old:
                raise UndoError(400, "change carries no prior values to restore")
            current = changelog.row_dict(self.db, table, entity_id) or {}
            prior_current = {k: current.get(k) for k in old}
            set_clause = ", ".join(f"{k} = ?" for k in old)
            self.db.execute(
                f"UPDATE {table} SET {set_clause}, updated_at = ? WHERE id = ?",
                list(old.values()) + [now, entity_id],
            )
            changelog.append(self.db, entity=entity, entity_id=entity_id,
                             op="update", new=old, old=prior_current,
                             undoes=change_id)
        else:
            raise UndoError(400, f"cannot undo op '{op}'")

        return {
            "undone": change_id,
            "entity": entity,
            "entity_id": entity_id,
            "state": changelog.row_dict(self.db, table, entity_id),
        }
