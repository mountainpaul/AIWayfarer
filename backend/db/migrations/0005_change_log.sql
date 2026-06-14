-- v2: append-only change log (docs/sync-redesign-v2-change-log.md).
-- Source of truth for history/undo/audit; the entity tables are projections.
-- Additive: a new table only. No existing data touched.

CREATE TABLE IF NOT EXISTS changes (
    seq         INTEGER PRIMARY KEY AUTOINCREMENT,  -- monotonic server order
    change_id   TEXT NOT NULL UNIQUE,               -- client-supplied UUID = idempotency key
    entity      TEXT NOT NULL,                      -- 'booking' | 'task' | 'packing'
    entity_id   TEXT NOT NULL,
    op          TEXT NOT NULL,                      -- 'create' | 'update' | 'delete' | 'restore' | 'undo'
    patch       TEXT,                               -- JSON {"new": {...}, "old": {...}}
    undoes      TEXT,                               -- change_id this event reverts (for undo/redo chains)
    device      TEXT,
    client_ts   TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_changes_entity ON changes(entity, entity_id, seq);
CREATE INDEX IF NOT EXISTS idx_changes_seq    ON changes(seq);
