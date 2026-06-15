-- 0008_trip_review.sql
-- Step 3: post-trip review. One review per trip + per-entity rated items
-- (linked to the actual leg/booking so feedback is specific, not vague).
-- Submitting a review distills traveler_profile.profile_summary (revealed
-- preferences refine the stated questionnaire ones).

CREATE TABLE IF NOT EXISTS trip_review (
    id              TEXT PRIMARY KEY,
    trip_id         TEXT NOT NULL REFERENCES trip(id),
    overall_rating  INTEGER,                       -- 1..5
    pace_feedback   TEXT,                          -- too_packed | just_right | too_slow
    highlight       TEXT,
    lowlight        TEXT,
    free_text       TEXT,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    deleted_at      TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_trip_review_trip    ON trip_review(trip_id);
CREATE INDEX        IF NOT EXISTS idx_trip_review_updated ON trip_review(updated_at);

CREATE TABLE IF NOT EXISTS review_item (
    id              TEXT PRIMARY KEY,
    review_id       TEXT NOT NULL REFERENCES trip_review(id),
    leg_id          TEXT REFERENCES leg(id),
    booking_id      TEXT REFERENCES booking(id),
    subject_type    TEXT NOT NULL CHECK (subject_type IN (
                        'stay', 'activity', 'transport', 'food', 'leg', 'other'
                    )),
    subject_label   TEXT NOT NULL,                 -- denormalized name at review time
    rating          INTEGER,                       -- 1..5
    liked           TEXT,
    disliked        TEXT,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    deleted_at      TEXT
);
CREATE INDEX IF NOT EXISTS idx_review_item_review  ON review_item(review_id);
CREATE INDEX IF NOT EXISTS idx_review_item_updated ON review_item(updated_at);

CREATE TRIGGER IF NOT EXISTS trg_trip_review_updated AFTER UPDATE ON trip_review
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE trip_review SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;

CREATE TRIGGER IF NOT EXISTS trg_review_item_updated AFTER UPDATE ON review_item
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN UPDATE review_item SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id; END;
