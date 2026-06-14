from .base import BaseRepository


class TaskRepository(BaseRepository):
    table = "task"
    entity = "task"
    bool_columns = ("is_done",)
    default_order = (
        "CASE priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 "
        "WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END, "
        "COALESCE(due_date, '9999') ASC"
    )
