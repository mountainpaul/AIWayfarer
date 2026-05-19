-- Wayfarer Trip HQ schema
-- SQLite-first, Postgres-compatible
-- All dates: ISO 8601 TEXT (YYYY-MM-DD)
-- All timestamps: ISO 8601 TEXT (YYYY-MM-DDTHH:MM:SSZ)
-- All money: INTEGER cents (avoids float rounding)
-- All booleans: INTEGER 0/1

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- ── Trips ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS trips (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    start_date  TEXT NOT NULL,
    end_date    TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- ── Legs ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS legs (
    id            TEXT PRIMARY KEY,
    trip_id       TEXT NOT NULL REFERENCES trips(id),
    slug          TEXT NOT NULL UNIQUE,   -- "sicily", "malta" — stable migration key
    name          TEXT NOT NULL,
    emoji         TEXT,
    color         TEXT,                   -- hex, e.g. "#ef4444"
    start_date    TEXT NOT NULL,
    end_date      TEXT NOT NULL,
    is_schengen   INTEGER NOT NULL DEFAULT 0,
    budget_cents  INTEGER,                -- per-leg budget in cents
    currency      TEXT NOT NULL DEFAULT 'USD',
    places        TEXT,                   -- human-readable route summary
    notes         TEXT,                   -- freeform per-leg notes
    sort_order    INTEGER NOT NULL,
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_legs_trip ON legs(trip_id);
CREATE INDEX IF NOT EXISTS idx_legs_dates ON legs(start_date, end_date);

-- ── Bookings ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS bookings (
    id              TEXT PRIMARY KEY,
    leg_id          TEXT NOT NULL REFERENCES legs(id),
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
    confirmation    TEXT,                 -- booking reference only
    cost_cents      INTEGER,              -- NULL = unknown, 0 = free
    currency        TEXT NOT NULL DEFAULT 'USD',
    location_name   TEXT,                 -- "Palermo", "Ragusa Ibla"
    location_lat    REAL,
    location_lon    REAL,
    notes           TEXT,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_bookings_leg ON bookings(leg_id);
CREATE INDEX IF NOT EXISTS idx_bookings_dates ON bookings(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_bookings_type ON bookings(type);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

-- ── Tasks ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS tasks (
    id          TEXT PRIMARY KEY,
    leg_id      TEXT REFERENCES legs(id),   -- nullable for general tasks
    title       TEXT NOT NULL,
    priority    TEXT NOT NULL CHECK (priority IN (
                    'critical', 'high', 'medium', 'low'
                )),
    due_date    TEXT,
    is_done     INTEGER NOT NULL DEFAULT 0,
    notes       TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_tasks_leg ON tasks(leg_id);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_done ON tasks(is_done);

-- ── Packing Items ──────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS packing_items (
    id          TEXT PRIMARY KEY,
    trip_id     TEXT NOT NULL REFERENCES trips(id),
    category    TEXT NOT NULL CHECK (category IN (
                    'clothing', 'layers', 'footwear', 'toiletries',
                    'electronics', 'documents', 'gear', 'misc'
                )),
    name        TEXT NOT NULL,
    is_packed   INTEGER NOT NULL DEFAULT 0,
    sort_order  INTEGER NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_packing_trip ON packing_items(trip_id);

-- ── Journal Entries ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS journal_entries (
    id              TEXT PRIMARY KEY,
    leg_id          TEXT REFERENCES legs(id),
    content         TEXT NOT NULL,
    entry_type      TEXT NOT NULL DEFAULT 'note' CHECK (entry_type IN (
                        'note', 'voice', 'reflection'
                    )),
    location_name   TEXT,
    location_lat    REAL,
    location_lon    REAL,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_journal_leg ON journal_entries(leg_id);
CREATE INDEX IF NOT EXISTS idx_journal_type ON journal_entries(entry_type);
CREATE INDEX IF NOT EXISTS idx_journal_created ON journal_entries(created_at);

-- ── Briefings ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS briefings (
    id          TEXT PRIMARY KEY,
    date        TEXT NOT NULL UNIQUE,
    markdown    TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
