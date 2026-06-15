-- 0007_traveler_profile.sql
-- Step 1 of the traveler-profile feature: persistent preference store whose
-- distilled `profile_summary` is injected into the chat grounding block.
-- Single-user v1 (one row, user_id = 'paul'); shaped for multi-user later.

CREATE TABLE IF NOT EXISTS traveler_profile (
    id                   TEXT PRIMARY KEY,              -- UUIDv7 (time-ordered)
    user_id              TEXT NOT NULL,
    lodging_style        TEXT,                          -- boutique | luxury | budget_guesthouse | ...
    transport_preference TEXT,                          -- rental_car | public_transit | trains | ...
    travel_pace          TEXT,                          -- relaxed | moderate | packed
    budget_tier          TEXT,                          -- economy | mid_range | splurge
    profile_summary      TEXT,                          -- distilled AI paragraph (injected into grounding)
    preferences_blob     TEXT NOT NULL DEFAULT '{}',    -- JSON sandbox: evolving fields, tags, avoids
    created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    deleted_at           TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_traveler_profile_user    ON traveler_profile(user_id);
CREATE INDEX        IF NOT EXISTS idx_traveler_profile_updated ON traveler_profile(updated_at);

CREATE TRIGGER IF NOT EXISTS trg_traveler_profile_updated AFTER UPDATE ON traveler_profile
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE traveler_profile SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;
