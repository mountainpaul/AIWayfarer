from .base import BaseRepository


class PackingRepository(BaseRepository):
    table = "packing_item"
    entity = "packing"
    bool_columns = ("is_packed",)
    default_order = "sort_order ASC"
