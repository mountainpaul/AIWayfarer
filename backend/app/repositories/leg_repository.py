from .base import BaseRepository


class LegRepository(BaseRepository):
    """Legs (read-heavy for now; full CRUD lands with the trip-lifecycle work).
    Exposed so other routers can do FK-existence checks without raw SQL."""

    table = "leg"
    entity = "leg"
    bool_columns = ("is_schengen",)
