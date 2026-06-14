"""Briefing repository: date-keyed upsert + latest read. Briefings are a local
cache of generated markdown, so the semantics differ from standard CRUD."""
import sqlite3
import uuid
from typing import Optional


class BriefingRepository:
    def __init__(self, db: sqlite3.Connection):
        self.db = db

    def upsert(self, day: str, markdown: str) -> dict:
        new_id = str(uuid.uuid4())
        self.db.execute(
            """INSERT INTO briefing (id, date, markdown) VALUES (?, ?, ?)
               ON CONFLICT(date) DO UPDATE SET
                   markdown = excluded.markdown,
                   created_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now')""",
            (new_id, day, markdown),
        )
        row = self.db.execute(
            "SELECT * FROM briefing WHERE date = ?", (day,)
        ).fetchone()
        return dict(row)

    def latest(self) -> Optional[dict]:
        row = self.db.execute(
            "SELECT * FROM briefing ORDER BY date DESC LIMIT 1"
        ).fetchone()
        return dict(row) if row else None
