-- Wayfarer schema — singular table names per BEST_PRACTICES.md §3.1.
-- Consolidated baseline: includes soft-delete (deleted_at), full timestamps,
-- the append-only change log, auto-updated_at triggers, and delta-sync indexes
-- (these were previously incremental migrations 0002/0004/0005, now folded in).
-- SQLite-first, Postgres-compatible.
-- Dates: ISO 8601 TEXT (YYYY-MM-DD). Timestamps: ISO 8601 TEXT (…THH:MM:SSZ).
-- Money: INTEGER cents. Booleans: INTEGER 0/1.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- ── trip ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trip (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    start_date  TEXT NOT NULL,
    end_date    TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    deleted_at  TEXT
);

-- ── leg ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leg (
    id            TEXT PRIMARY KEY,
    trip_id       TEXT NOT NULL REFERENCES trip(id),
    slug          TEXT NOT NULL UNIQUE,
    name          TEXT NOT NULL,
    emoji         TEXT,
    color         TEXT,
    start_date    TEXT NOT NULL,
    end_date      TEXT NOT NULL,
    is_schengen   INTEGER NOT NULL DEFAULT 0,
    budget_cents  INTEGER,
    currency      TEXT NOT NULL DEFAULT 'USD',
    places        TEXT,
    notes         TEXT,
    sort_order    INTEGER NOT NULL,
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    deleted_at    TEXT
);
CREATE INDEX IF NOT EXISTS idx_leg_trip    ON leg(trip_id);
CREATE INDEX IF NOT EXISTS idx_leg_dates   ON leg(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_leg_updated ON leg(updated_at);

-- ── booking ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS booking (
    id              TEXT PRIMARY KEY,
    leg_id          TEXT NOT NULL REFERENCES leg(id),
    type            TEXT NOT NULL CHECK (type IN (
                        'flight', 'hotel', 'ferry', 'car', 'train',
                        'activity', 'rifugio', 'other'
                    )),
    name            TEXT NOT NULL,
    status          TEXT NOT NULL CHECK (status IN (
                        'booked', 'pending', 'needs_booking', 'researching'
                    )),
    start_date      TEXT,
    end_date        TEXT,
    confirmation    TEXT,
    cost_cents      INTEGER,
    currency        TEXT NOT NULL DEFAULT 'USD',
    location_name   TEXT,
    location_lat    REAL,
    location_lon    REAL,
    notes           TEXT,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    deleted_at      TEXT
);
CREATE INDEX IF NOT EXISTS idx_booking_leg     ON booking(leg_id);
CREATE INDEX IF NOT EXISTS idx_booking_dates   ON booking(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_booking_type    ON booking(type);
CREATE INDEX IF NOT EXISTS idx_booking_status  ON booking(status);
CREATE INDEX IF NOT EXISTS idx_booking_updated ON booking(updated_at);

-- ── task ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS task (
    id          TEXT PRIMARY KEY,
    leg_id      TEXT REFERENCES leg(id),
    title       TEXT NOT NULL,
    priority    TEXT NOT NULL CHECK (priority IN (
                    'critical', 'high', 'medium', 'low'
                )),
    due_date    TEXT,
    is_done     INTEGER NOT NULL DEFAULT 0,
    notes       TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    deleted_at  TEXT
);
CREATE INDEX IF NOT EXISTS idx_task_leg      ON task(leg_id);
CREATE INDEX IF NOT EXISTS idx_task_priority ON task(priority);
CREATE INDEX IF NOT EXISTS idx_task_done     ON task(is_done);
CREATE INDEX IF NOT EXISTS idx_task_updated  ON task(updated_at);

-- ── packing_item ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS packing_item (
    id          TEXT PRIMARY KEY,
    trip_id     TEXT NOT NULL REFERENCES trip(id),
    category    TEXT NOT NULL CHECK (category IN (
                    'clothing', 'layers', 'footwear', 'toiletries',
                    'electronics', 'documents', 'gear', 'misc'
                )),
    name        TEXT NOT NULL,
    is_packed   INTEGER NOT NULL DEFAULT 0,
    sort_order  INTEGER NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    deleted_at  TEXT
);
CREATE INDEX IF NOT EXISTS idx_packing_item_trip    ON packing_item(trip_id);
CREATE INDEX IF NOT EXISTS idx_packing_item_updated ON packing_item(updated_at);

-- ── journal_entry ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS journal_entry (
    id              TEXT PRIMARY KEY,
    leg_id          TEXT REFERENCES leg(id),
    content         TEXT NOT NULL,
    entry_type      TEXT NOT NULL DEFAULT 'note' CHECK (entry_type IN (
                        'note', 'voice', 'reflection'
                    )),
    location_name   TEXT,
    location_lat    REAL,
    location_lon    REAL,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    deleted_at      TEXT
);
CREATE INDEX IF NOT EXISTS idx_journal_entry_leg     ON journal_entry(leg_id);
CREATE INDEX IF NOT EXISTS idx_journal_entry_type    ON journal_entry(entry_type);
CREATE INDEX IF NOT EXISTS idx_journal_entry_created ON journal_entry(created_at);
CREATE INDEX IF NOT EXISTS idx_journal_entry_updated ON journal_entry(updated_at);

-- ── briefing ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS briefing (
    id          TEXT PRIMARY KEY,
    date        TEXT NOT NULL UNIQUE,
    markdown    TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    deleted_at  TEXT
);
CREATE INDEX IF NOT EXISTS idx_briefing_updated ON briefing(updated_at);

-- ── change (append-only log) ───────────────────────────────────
CREATE TABLE IF NOT EXISTS change (
    seq         INTEGER PRIMARY KEY AUTOINCREMENT,
    change_id   TEXT NOT NULL UNIQUE,   -- client-supplied UUID = idempotency key
    entity      TEXT NOT NULL,          -- 'booking' | 'task' | 'packing'
    entity_id   TEXT NOT NULL,
    op          TEXT NOT NULL,          -- 'create' | 'update' | 'delete' | 'restore'
    patch       TEXT,                   -- JSON {"new": {...}, "old": {...}}
    undoes      TEXT,                   -- change_id this event reverts
    device      TEXT,
    client_ts   TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_change_entity ON change(entity, entity_id, seq);
CREATE INDEX IF NOT EXISTS idx_change_seq    ON change(seq);

-- ── auto-bump updated_at on any UPDATE that doesn't set it itself.
--    WHEN NEW.updated_at = OLD.updated_at: skip when a write explicitly sets
--    updated_at (e.g. applying a synced timestamp) and avoid recursion. ──
CREATE TRIGGER IF NOT EXISTS trg_trip_updated AFTER UPDATE ON trip
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE trip SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_leg_updated AFTER UPDATE ON leg
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE leg SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_booking_updated AFTER UPDATE ON booking
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE booking SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_task_updated AFTER UPDATE ON task
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE task SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_packing_item_updated AFTER UPDATE ON packing_item
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE packing_item SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_journal_entry_updated AFTER UPDATE ON journal_entry
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE journal_entry SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_briefing_updated AFTER UPDATE ON briefing
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE briefing SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;
