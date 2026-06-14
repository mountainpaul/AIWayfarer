from .base import BaseRepository


class TripRepository(BaseRepository):
    """Trips (read-heavy for now; full CRUD lands with the trip-lifecycle work).
    Exposed so other routers can do FK-existence checks without raw SQL."""

    table = "trip"
    entity = "trip"
