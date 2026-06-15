from typing import Optional

from .base import BaseRepository


class TripReviewRepository(BaseRepository):
    table = "trip_review"
    entity = "trip_review"
    default_order = "created_at DESC"

    def by_trip(self, trip_id: str) -> Optional[dict]:
        """The (single) review for a trip, or None. One review per trip."""
        rows = self.list(filters={"trip_id": trip_id}, limit=1)
        return rows[0] if rows else None
