"""Sync repository: the multi-table snapshot/delta reads for /sync/snapshot.
Returns EVERY row (including tombstones) so soft-deletes propagate; the router
maps rows to models. See docs/sync-redesign.md."""
import sqlite3
from typing import Optional


class SyncRepository:
    # Order matters for the response shape; mirrors SyncSnapshot fields.
    TABLES = ("trip", "leg", "booking", "task", "packing_item", "journal_entry")

    def __init__(self, db: sqlite3.Connection):
        self.db = db

    def _rows(self, table: str, since: Optional[str]) -> list[sqlite3.Row]:
        if since is not None:
            # >= (not >) at the boundary: timestamps are second-granular, so a
            # change in the same second as the cursor isn't missed. Re-fetching
            # boundary rows is harmless — the client merge is idempotent.
            # COALESCE guards rows whose updated_at was never set.
            return self.db.execute(
                f"SELECT * FROM {table} "
                f"WHERE COALESCE(updated_at, created_at) >= ? "
                f"ORDER BY COALESCE(updated_at, created_at) ASC",
                (since,),
            ).fetchall()
        return self.db.execute(f"SELECT * FROM {table}").fetchall()

    def snapshot(self, since: Optional[str]) -> dict[str, list[sqlite3.Row]]:
        return {t: self._rows(t, since) for t in self.TABLES}

    def current_leg_row(self, today: str) -> Optional[sqlite3.Row]:
        # Convenience pointer for the home screen — never a tombstone.
        return self.db.execute(
            """SELECT * FROM leg
               WHERE deleted_at IS NULL
                 AND date(?) BETWEEN date(start_date) AND date(end_date)
               ORDER BY start_date ASC LIMIT 1""",
            (today,),
        ).fetchone()
