-- Soft-delete + complete timestamps for timestamp-based (last-write-wins) sync.
-- Fully additive: only ADD COLUMN (nullable, no data rewritten) + backfill of
-- newly-added updated_at from created_at + triggers. No DROP, no DELETE.

-- ── deleted_at tombstone on every syncable table ───────────────
ALTER TABLE trips           ADD COLUMN deleted_at TEXT;
ALTER TABLE legs            ADD COLUMN deleted_at TEXT;
ALTER TABLE bookings        ADD COLUMN deleted_at TEXT;
ALTER TABLE tasks           ADD COLUMN deleted_at TEXT;
ALTER TABLE packing_items   ADD COLUMN deleted_at TEXT;
ALTER TABLE journal_entries ADD COLUMN deleted_at TEXT;
ALTER TABLE briefings       ADD COLUMN deleted_at TEXT;

-- ── updated_at where missing (cannot use a non-constant DEFAULT in
--    ALTER ADD COLUMN, so add nullable then backfill from created_at) ──
ALTER TABLE journal_entries ADD COLUMN updated_at TEXT;
ALTER TABLE briefings       ADD COLUMN updated_at TEXT;
UPDATE journal_entries SET updated_at = created_at WHERE updated_at IS NULL;
UPDATE briefings       SET updated_at = created_at WHERE updated_at IS NULL;

-- ── indexes to make ?since= delta sync cheap ───────────────────
CREATE INDEX IF NOT EXISTS idx_trips_updated         ON trips(updated_at);
CREATE INDEX IF NOT EXISTS idx_legs_updated          ON legs(updated_at);
CREATE INDEX IF NOT EXISTS idx_bookings_updated      ON bookings(updated_at);
CREATE INDEX IF NOT EXISTS idx_tasks_updated         ON tasks(updated_at);
CREATE INDEX IF NOT EXISTS idx_packing_updated       ON packing_items(updated_at);
CREATE INDEX IF NOT EXISTS idx_journal_updated       ON journal_entries(updated_at);
CREATE INDEX IF NOT EXISTS idx_briefings_updated     ON briefings(updated_at);

-- ── auto-bump updated_at on any UPDATE that doesn't set it itself.
--    WHEN NEW.updated_at = OLD.updated_at: skip when a write explicitly
--    changes updated_at (e.g. applying a synced timestamp / LWW), and avoid
--    trigger recursion. ───────────────────────────────────────────
CREATE TRIGGER IF NOT EXISTS trg_trips_updated AFTER UPDATE ON trips
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE trips SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_legs_updated AFTER UPDATE ON legs
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE legs SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_bookings_updated AFTER UPDATE ON bookings
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE bookings SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_tasks_updated AFTER UPDATE ON tasks
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE tasks SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_packing_updated AFTER UPDATE ON packing_items
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE packing_items SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_journal_updated AFTER UPDATE ON journal_entries
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE journal_entries SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_briefings_updated AFTER UPDATE ON briefings
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE briefings SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;
