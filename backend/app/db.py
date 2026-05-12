import sqlite3
from pathlib import Path
from typing import Iterator

from . import config


def _connect(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def apply_migrations() -> None:
    """Apply any *.sql files under db/migrations in lexical order. Idempotent."""
    migrations_dir: Path = config.MIGRATIONS_DIR
    if not migrations_dir.is_dir():
        return
    files = sorted(p for p in migrations_dir.glob("*.sql") if p.is_file())
    if not files:
        return
    conn = _connect(config.DB_PATH)
    try:
        for path in files:
            conn.executescript(path.read_text())
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
