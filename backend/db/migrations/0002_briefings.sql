-- Cached briefings (one per date). Idempotent.

CREATE TABLE IF NOT EXISTS briefings (
    id          TEXT PRIMARY KEY,
    date        TEXT NOT NULL UNIQUE,
    markdown    TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_briefings_date ON briefings(date);
