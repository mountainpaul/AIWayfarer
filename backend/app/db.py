import sqlite3
from pathlib import Path
from typing import Iterator

from . import config


def _connect(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    # Per-request connections can contend (e.g. an email import racing a task
    # toggle from the phone); wait instead of raising "database is locked".
    conn.execute("PRAGMA busy_timeout = 5000")
    return conn


def apply_migrations() -> None:
    """Bootstrap the base schema (idempotent), then run each db/migrations/*.sql
    exactly once, tracked in schema_migrations."""
    conn = _connect(config.DB_PATH)
    try:
        schema: Path = config.SCHEMA_PATH
        if schema.is_file():
            conn.executescript(schema.read_text())
        conn.execute(
            """CREATE TABLE IF NOT EXISTS schema_migrations (
                   filename   TEXT PRIMARY KEY,
                   applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
               )"""
        )
        applied = {
            r["filename"]
            for r in conn.execute("SELECT filename FROM schema_migrations")
        }
        if config.MIGRATIONS_DIR.is_dir():
            for path in sorted(config.MIGRATIONS_DIR.glob("*.sql")):
                if not path.is_file() or path.name in applied:
                    continue
                conn.executescript(path.read_text())
                conn.execute(
                    "INSERT INTO schema_migrations (filename) VALUES (?)",
                    (path.name,),
                )
        conn.commit()
    finally:
        conn.close()


def get_db() -> Iterator[sqlite3.Connection]:
    """FastAPI dependency: per-request SQLite connection."""
    conn = _connect(config.DB_PATH)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def row_to_dict(row: sqlite3.Row | None) -> dict | None:
    return dict(row) if row is not None else None
