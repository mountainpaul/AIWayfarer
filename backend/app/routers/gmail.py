"""
Gmail booking scanner endpoint — scans Gmail for booking confirmations,
uses Claude to extract structured data, returns candidates for import.
"""

import sqlite3
import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import get_db
from ..services import claude as claude_svc
from ..services import gmail_scanner, google_auth

router = APIRouter(prefix="/gmail", tags=["gmail"])


@router.get("/threads")
def list_threads():
    """Legacy stub — returns empty. Use POST /gmail/scan-bookings instead."""
    return []


def _dedup_key(b: dict) -> str:
    """Fallback identity for bookings without a confirmation number."""
    return "|".join(
        str(b.get(k) or "").strip().lower()
        for k in ("leg_id", "type", "name", "start_date")
    )


def _iso_date_or_none(v) -> str | None:
    """Accept YYYY-MM-DD (or a longer ISO string starting with it); else None."""
    s = str(v).strip()[:10] if v else ""
    try:
        date.fromisoformat(s)
        return s
    except ValueError:
        return None


def _int_or_none(v) -> int | None:
    if v is None or isinstance(v, bool):
        return None
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def _str_or_none(v) -> str | None:
    s = str(v).strip() if v is not None else ""
    return s or None


@router.post("/scan-bookings")
def scan_bookings(
    months: int = Query(6, ge=1, le=24, description="How many months back to scan"),
    db: sqlite3.Connection = Depends(get_db),
):
    """
    Scan Gmail for booking-related emails and parse them into structured
    booking candidates using Claude. Returns a list of candidate bookings
    ready for review and import.
    """
    try:
        # Get legs for date-range matching
        rows = db.execute(
            "SELECT id, name, start_date, end_date FROM legs ORDER BY start_date"
        ).fetchall()
        legs = [dict(r) for r in rows]

        candidates = gmail_scanner.scan_and_parse(legs=legs, months=months)

        # Flag candidates that already exist so the UI can pre-skip them.
        # Match on confirmation number when present, else on a composite key
        # (leg/type/name/date) so re-scans don't surface known duplicates.
        existing = db.execute("SELECT * FROM bookings").fetchall()
        existing_confs = {r["confirmation"] for r in existing if r["confirmation"]}
        existing_keys = {_dedup_key(dict(r)) for r in existing}

        for c in candidates:
            conf = c.get("confirmation")
            c["already_exists"] = bool(
                (conf and conf in existing_confs) or _dedup_key(c) in existing_keys
            )

        return {"candidates": candidates, "candidate_count": len(candidates)}

    except google_auth.GoogleNotConfiguredError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except gmail_scanner.GmailApiError as e:
        raise HTTPException(status_code=502, detail=str(e))
    except claude_svc.ClaudeUnavailableError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Anthropic API error: {e}")


@router.post("/import-bookings")
def import_bookings(
    bookings: list[dict],
    db: sqlite3.Connection = Depends(get_db),
):
    """
    Import a list of booking candidates (from scan-bookings) into the database.
    Each dict should have: leg_id, type, name, status, and optional fields.
    Skips rows whose leg is unknown or that already exist (by confirmation or
    composite key), and coerces type/status to valid enum values.
    """
    # Build the dedup indexes once up front.
    existing = db.execute("SELECT * FROM bookings").fetchall()
    existing_confs = {r["confirmation"] for r in existing if r["confirmation"]}
    existing_keys = {_dedup_key(dict(r)) for r in existing}

    created = []
    skipped = 0
    for b in bookings:
        leg_id = _str_or_none(b.get("leg_id"))
        if not leg_id:
            skipped += 1
            continue
        if not db.execute("SELECT id FROM legs WHERE id = ?", (leg_id,)).fetchone():
            skipped += 1
            continue

        # Sanitize every field — never trust the caller-supplied (LLM-origin)
        # values. A JSON null name would violate NOT NULL and abort the batch;
        # a string cost_cents would insert fine (SQLite flexible typing) but
        # then fail Pydantic validation on every subsequent /bookings read.
        btype = str(b.get("type") or "other").lower()
        if btype not in gmail_scanner.BOOKING_TYPES:
            btype = "other"
        status = str(b.get("status") or "booked").lower()
        if status not in gmail_scanner.BOOKING_STATUSES:
            status = "booked"
        name = _str_or_none(b.get("name")) or "Unknown"
        conf = _str_or_none(b.get("confirmation"))

        normalized = {**b, "type": btype, "name": name, "leg_id": leg_id}
        key = _dedup_key(normalized)
        if (conf and conf in existing_confs) or key in existing_keys:
            skipped += 1
            continue

        new_id = str(uuid.uuid4())
        try:
            db.execute(
                """INSERT INTO bookings
                   (id, leg_id, type, name, status, start_date, end_date,
                    confirmation, cost_cents, currency, location_name, notes)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    new_id,
                    leg_id,
                    btype,
                    name,
                    status,
                    _iso_date_or_none(b.get("start_date")),
                    _iso_date_or_none(b.get("end_date")),
                    conf,
                    _int_or_none(b.get("cost_cents")),
                    _str_or_none(b.get("currency")) or "EUR",
                    _str_or_none(b.get("location_name")),
                    _str_or_none(b.get("notes")),
                ),
            )
        except sqlite3.Error:
            # One malformed row must not abort the rest of the batch.
            skipped += 1
            continue
        created.append(new_id)
        # Keep indexes current so duplicates within the same batch are skipped too.
        if conf:
            existing_confs.add(conf)
        existing_keys.add(key)

    return {"imported": len(created), "skipped": skipped, "ids": created}
