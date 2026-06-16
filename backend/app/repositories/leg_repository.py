import re
from typing import Optional

from .base import BaseRepository


class LegRepository(BaseRepository):
    table = "leg"
    entity = "leg"
    bool_columns = ("is_schengen",)
    default_order = "sort_order ASC"

    def unique_slug(self, name: str) -> str:
        """A globally-unique slug derived from the leg name (leg, leg-2, …).
        Checks all legs incl. tombstones, since slug is UNIQUE across the table."""
        base = re.sub(r"[^a-z0-9]+", "-", (name or "").strip().lower()).strip("-") or "leg"
        slug, n = base, 2
        while self.db.execute("SELECT 1 FROM leg WHERE slug = ?", (slug,)).fetchone():
            slug, n = f"{base}-{n}", n + 1
        return slug

    def current(self, day: str) -> Optional[dict]:
        """The active leg for a date (never a tombstone)."""
        row = self.db.execute(
            "SELECT * FROM leg WHERE deleted_at IS NULL "
            "AND date(?) BETWEEN date(start_date) AND date(end_date) "
            "ORDER BY start_date ASC LIMIT 1",
            (day,),
        ).fetchone()
        return dict(row) if row else None
