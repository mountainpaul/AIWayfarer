from .base import BaseRepository


class BookingRepository(BaseRepository):
    table = "booking"
    entity = "booking"
    # SQLite has no NULLS LAST — fold NULL start_date to the end.
    default_order = "COALESCE(start_date, '9999') ASC, name ASC"
