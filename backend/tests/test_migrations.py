"""apply_migrations must bootstrap a fully working schema on an empty DB
(fresh clone / droplet deploy) and be safe to run repeatedly."""

import sqlite3

from app import config, db


def _tables(path: str) -> set[str]:
    conn = sqlite3.connect(path)
    try:
        return {
            r[0]
            for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
        }
    finally:
        conn.close()


def test_bootstrap_fresh_db(tmp_path, monkeypatch):
    fresh = tmp_path / "fresh.db"
    monkeypatch.setattr(config, "DB_PATH", str(fresh))

    db.apply_migrations()
    db.apply_migrations()  # second run must be a no-op, not a crash

    tables = _tables(str(fresh))
    for expected in (
        "trips",
        "legs",
        "bookings",
        "tasks",
        "packing_items",
        "journal_entries",
        "briefings",
        "schema_migrations",
    ):
        assert expected in tables, f"missing table {expected}"

    conn = sqlite3.connect(str(fresh))
    try:
        applied = [
            r[0] for r in conn.execute("SELECT filename FROM schema_migrations")
        ]
    finally:
        conn.close()
    # Each migration file recorded exactly once despite running twice.
    assert applied == sorted(set(applied))
    assert "0002_briefings.sql" in applied
