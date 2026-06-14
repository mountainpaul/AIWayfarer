from .base import BaseRepository


class TripRepository(BaseRepository):
    table = "trip"
    entity = "trip"
    default_order = "start_date ASC"
