"""
Gmail booking scanner endpoint — scans Gmail for booking confirmations,
uses Claude to extract structured data, returns candidates for import.
"""

import sqlite3
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import get_db
from ..services import gmail_scanner, google_auth

router = APIRouter(prefix="/gmail", tags=["gmail"])


@router.get("/threads")
def list_threads():
    """Legacy stub — returns empty. Use POST /gmail/scan-bookings instead."""
    return []


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

        # Mark which candidates already exist (by confirmation number)
        existing_confs = set()
        conf_rows = db.execute(
            "SELECT confirmation FROM bookings WHERE confirmation IS NOT NULL"
        ).fetchall()
        for r in conf_rows:
            existing_confs.add(r["confirmation"])

        for c in candidates:
            c["already_exists"] = (
                c.get("confirmation") in existing_confs
                if c.get("confirmation")
                else False
            )

        return {"candidates": candidates, "email_count": len(candidates)}

    except google_auth.GoogleNotConfiguredError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except gmail_scanner.GmailApiError as e:
        raise HTTPException(status_code=502, detail=str(e))


@router.post("/import-bookings")
def import_bookings(
    bookings: list[dict],
    db: sqlite3.Connection = Depends(get_db),
):
    """
    Import a list of booking candidates (from scan-bookings) into the database.
    Each dict should have: leg_id, type, name, status, and optional fields.
    """
    import uuid

    created = []
    for b in bookings:
        leg_id = b.get("leg_id")
        if not leg_id:
            continue

        # Verify leg exists
        leg = db.execute("SELECT id FROM legs WHERE id = ?", (leg_id,)).fetchone()
        if not leg:
            continue

        # Skip if confirmation already exists
        conf = b.get("confirmation")
        if conf:
            existing = db.execute(
                "SELECT id FROM bookings WHERE confirmation = ?", (conf,)
            ).fetchone()
            if existing:
                continue

        new_id = str(uuid.uuid4())
        db.execute(
            """INSERT INTO bookings
               (id, leg_id, type, name, status, start_date, end_date,
                confirmation, cost_cents, currency, location_name, notes)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                new_id,
                leg_id,
                b.get("type", "other"),
                b.get("name", "Unknown"),
                b.get("status", "booked"),
                b.get("start_date"),
                b.get("end_date"),
                conf,
                b.get("cost_cents"),
                b.get("currency", "EUR"),
                b.get("location_name"),
                b.get("notes"),
            ),
        )
        created.append(new_id)

    return {"imported": len(created), "ids": created}
