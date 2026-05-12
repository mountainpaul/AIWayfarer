"""
Grounding layer (spec §4): assemble GPS + clock + Trip HQ state into a payload
that every chat query is answered against.
"""

import sqlite3
from datetime import datetime, timezone
from typing import Optional

from ..models import GPS, GroundingPayload


def _row_to_dict(row: sqlite3.Row | None) -> Optional[dict]:
    return dict(row) if row is not None else None


def find_current_leg(db: sqlite3.Connection, date: str) -> Optional[dict]:
    row = db.execute(
        """SELECT * FROM legs
           WHERE date(?) BETWEEN date(start_date) AND date(end_date)
           ORDER BY start_date ASC LIMIT 1""",
        (date,),
    ).fetchone()
    return _row_to_dict(row)


def todays_bookings(db: sqlite3.Connection, date: str) -> list[dict]:
    rows = db.execute(
        """SELECT * FROM bookings
           WHERE (start_date IS NOT NULL AND date(start_date) = date(?))
              OR (end_date   IS NOT NULL AND date(end_date)   = date(?))
              OR (start_date IS NOT NULL AND end_date IS NOT NULL
                  AND date(?) BETWEEN date(start_date) AND date(end_date))
           ORDER BY start_date ASC""",
        (date, date, date),
    ).fetchall()
    return [dict(r) for r in rows]


def next_booking_after(db: sqlite3.Connection, iso_now: str) -> Optional[dict]:
    row = db.execute(
        """SELECT * FROM bookings
           WHERE start_date IS NOT NULL AND start_date >= ?
           ORDER BY start_date ASC LIMIT 1""",
        (iso_now,),
    ).fetchone()
    return _row_to_dict(row)


def open_tasks_count(db: sqlite3.Connection) -> int:
    row = db.execute("SELECT COUNT(*) AS n FROM tasks WHERE is_done = 0").fetchone()
    return int(row["n"]) if row else 0


def build_grounding_context(
    db: sqlite3.Connection,
    gps: Optional[GPS] = None,
    now: Optional[datetime] = None,
) -> GroundingPayload:
    if now is None:
        now = datetime.now(timezone.utc)
    iso_now = now.isoformat(timespec="seconds")
    iso_date = iso_now[:10]

    leg = find_current_leg(db, iso_date)
    return GroundingPayload(
        now=iso_now,
        gps=gps,
        current_leg=leg,
        todays_bookings=todays_bookings(db, iso_date),
        open_tasks_count=open_tasks_count(db),
        next_booking=next_booking_after(db, iso_now),
    )


def grounding_to_text(g: GroundingPayload) -> str:
    """Render the grounding payload as a compact text block for the system prompt."""
    lines = [f"Now: {g.now}"]
    if g.gps:
        lines.append(f"GPS: {g.gps.lat:.4f}, {g.gps.lon:.4f}")
    else:
        lines.append("GPS: (not provided)")
    if g.current_leg:
        leg = g.current_leg
        lines.append(
            f"Current leg: {leg.get('name')} ({leg.get('start_date')} → {leg.get('end_date')}); "
            f"places: {leg.get('places') or '—'}"
        )
    else:
        lines.append("Current leg: (none — between legs or pre-trip)")
    if g.todays_bookings:
        lines.append("Today's bookings:")
        for b in g.todays_bookings:
            lines.append(
                f"  - [{b.get('type')}] {b.get('name')} ({b.get('status')})"
                f" {b.get('start_date') or ''} {('@ ' + b.get('location_name')) if b.get('location_name') else ''}".strip()
            )
    else:
        lines.append("Today's bookings: none")
    if g.next_booking:
        nb = g.next_booking
        lines.append(f"Next booking: {nb.get('name')} on {nb.get('start_date')} ({nb.get('type')})")
    lines.append(f"Open tasks: {g.open_tasks_count}")
    return "\n".join(lines)
