"""
Gmail booking scanner endpoint — scans Gmail for booking confirmations,
uses Claude to extract structured data, returns candidates for import.
"""

import sqlite3
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import get_db
from ..repositories.booking_repository import BookingRepository
from ..repositories.leg_repository import LegRepository
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
        legs = LegRepository(db).list(order_by="start_date ASC")
        candidates = gmail_scanner.scan_and_parse(legs=legs, months=months)

        # Flag candidates that already exist so the UI can pre-skip them.
        # Match on confirmation number when present, else on a composite key
        # (leg/type/name/date) so re-scans don't surface known duplicates.
        existing = BookingRepository(db).list()
        existing_confs = {b["confirmation"] for b in existing if b["confirmation"]}
        existing_keys = {_dedup_key(b) for b in existing}

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


@router.post("/scan-offers")
def scan_offers(
    months: int = Query(2, ge=1, le=6, description="How many months back to scan"),
    db: sqlite3.Connection = Depends(get_db),
):
    """
    Scan Gmail for airline/hotel loyalty offers (promos, transfer bonuses,
    award sales) and parse them with Claude. Offers matched to a trip leg
    carry its leg_id; generic offers have leg_id null. Stateless — nothing
    is written to the database.
    """
    try:
        legs = LegRepository(db).list(order_by="start_date ASC")
        today = datetime.now(timezone.utc).date().isoformat()

        offers = gmail_scanner.scan_offers(legs=legs, today=today, months=months)

        # Drop offers Claude matched to a leg id that doesn't exist.
        leg_ids = {lg["id"] for lg in legs}
        for o in offers:
            if o.get("leg_id") not in leg_ids:
                o["leg_id"] = None

        return {"offers": offers, "offer_count": len(offers)}

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
    leg_repo = LegRepository(db)
    booking_repo = BookingRepository(db)

    # Build the dedup indexes once up front.
    existing = booking_repo.list()
    existing_confs = {b["confirmation"] for b in existing if b["confirmation"]}
    existing_keys = {_dedup_key(b) for b in existing}

    created = []
    skipped = 0
    for b in bookings:
        leg_id = _str_or_none(b.get("leg_id"))
        if not leg_id or leg_repo.get(leg_id) is None:
            skipped += 1
            continue

        # Sanitize every field — never trust the caller-supplied (LLM-origin)
        # values. A JSON null name would violate NOT NULL; a string cost_cents
        # would insert under SQLite's flexible typing but then fail Pydantic
        # validation on every subsequent /bookings read.
        btype = str(b.get("type") or "other").lower()
        if btype not in gmail_scanner.BOOKING_TYPES:
            btype = "other"
        status = str(b.get("status") or "booked").lower()
        if status not in gmail_scanner.BOOKING_STATUSES:
            status = "booked"
        name = _str_or_none(b.get("name")) or "Unknown"
        conf = _str_or_none(b.get("confirmation"))

        key = _dedup_key({"leg_id": leg_id, "type": btype, "name": name,
                          "start_date": b.get("start_date")})
        if (conf and conf in existing_confs) or key in existing_keys:
            skipped += 1
            continue

        data = {
            "leg_id": leg_id,
            "type": btype,
            "name": name,
            "status": status,
            "start_date": _iso_date_or_none(b.get("start_date")),
            "end_date": _iso_date_or_none(b.get("end_date")),
            "confirmation": conf,
            "cost_cents": _int_or_none(b.get("cost_cents")),
            "currency": _str_or_none(b.get("currency")) or "EUR",
            "location_name": _str_or_none(b.get("location_name")),
            "notes": _str_or_none(b.get("notes")),
        }
        try:
            row = booking_repo.create(data)
        except sqlite3.Error:
            # One malformed row must not abort the rest of the batch.
            skipped += 1
            continue
        created.append(row["id"])
        # Keep indexes current so duplicates within the same batch are skipped too.
        if conf:
            existing_confs.add(conf)
        existing_keys.add(key)

    return {"imported": len(created), "skipped": skipped, "ids": created}
