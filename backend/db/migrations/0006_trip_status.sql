-- Trip lifecycle: a status a trip moves through. Additive.
-- planning -> active -> completed (set explicitly; backfilled from dates here).
ALTER TABLE trip ADD COLUMN status TEXT NOT NULL DEFAULT 'planning';

-- Backfill existing trips from their dates so the seeded trip isn't mislabeled.
UPDATE trip SET status = 'completed' WHERE date(end_date) < date('now');
UPDATE trip SET status = 'active'
  WHERE date('now') BETWEEN date(start_date) AND date(end_date);
