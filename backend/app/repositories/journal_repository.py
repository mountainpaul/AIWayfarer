from .base import BaseRepository


class JournalRepository(BaseRepository):
    table = "journal_entry"
    # Append-only per spec §6 — not change-logged / undoable, so entity is blank.
    entity = ""
    default_order = "created_at DESC"
