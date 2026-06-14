from typing import Optional

from .base import BaseRepository


class LegRepository(BaseRepository):
    table = "leg"
    entity = "leg"
    bool_columns = ("is_schengen",)
    default_order = "sort_order ASC"

    def current(self, day: str) -> Optional[dict]:
        """The active leg for a date (never a tombstone)."""
        row = self.db.execute(
            "SELECT * FROM leg WHERE deleted_at IS NULL "
            "AND date(?) BETWEEN date(start_date) AND date(end_date) "
            "ORDER BY start_date ASC LIMIT 1",
            (day,),
        ).fetchone()
        return dict(row) if row else None
