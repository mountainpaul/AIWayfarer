"""
Grounding layer (spec §4): assemble GPS + clock + Trip HQ state into a payload
that every chat query is answered against.
"""

import sqlite3
from datetime import datetime, timezone
from typing import Optional

from ..models import GroundingPayload
from ..repositories.traveler_profile_repository import (
    DEFAULT_USER_ID,
    TravelerProfileRepository,
)


def _row_to_dict(row: sqlite3.Row | None) -> Optional[dict]:
    return dict(row) if row is not None else None


def traveler_profile_summary(
    db: sqlite3.Connection,
    user_id: str = DEFAULT_USER_ID,
) -> Optional[str]:
    """Distilled traveler-profile paragraph for the system prompt, or None.

    Kept separate from enrich_grounding_text(): the profile is stable across a
    session (it changes per-trip, not per-message), so the chat router injects
    it into the *cached* system block rather than the volatile grounding text.
    """
    return TravelerProfileRepository(db).summary_for(user_id)


def find_current_leg(db: sqlite3.Connection, date: str) -> Optional[dict]:
    row = db.execute(
        """SELECT * FROM leg
           WHERE date(?) BETWEEN date(start_date) AND date(end_date)
           ORDER BY start_date ASC LIMIT 1""",
        (date,),
    ).fetchone()
    return _row_to_dict(row)


def todays_bookings(db: sqlite3.Connection, date: str) -> list[dict]:
    rows = db.execute(
        """SELECT * FROM booking
           WHERE (start_date IS NOT NULL AND date(start_date) = date(?))
              OR (end_date   IS NOT NULL AND date(end_date)   = date(?))
              OR (start_date IS NOT NULL AND end_date IS NOT NULL
                  AND date(?) BETWEEN date(start_date) AND date(end_date))
           ORDER BY start_date ASC""",
        (date, date, date),
    ).fetchall()
    return [dict(r) for r in rows]


def next_booking_after(db: sqlite3.Connection, iso_now: str) -> Optional[dict]:
    # Compare on date(): start_date is date-only (YYYY-MM-DD) while iso_now is
    # a full timestamp, and string ordering would skip everything dated today.
    row = db.execute(
        """SELECT * FROM booking
           WHERE start_date IS NOT NULL AND date(start_date) >= date(?)
           ORDER BY start_date ASC LIMIT 1""",
        (iso_now,),
    ).fetchone()
    return _row_to_dict(row)


def open_tasks_count(db: sqlite3.Connection) -> int:
    row = db.execute("SELECT COUNT(*) AS n FROM task WHERE is_done = 0").fetchone()
    return int(row["n"]) if row else 0


def build_grounding_context(
    db: sqlite3.Connection,
    now: Optional[datetime] = None,
) -> GroundingPayload:
    """Build grounding from DB when the Flutter app doesn't send one."""
    if now is None:
        now = datetime.now(timezone.utc)
    iso_now = now.isoformat(timespec="seconds")
    iso_date = iso_now[:10]

    leg = find_current_leg(db, iso_date)
    return GroundingPayload(
        local_time_iso=iso_now,
        current_leg_id=leg.get("id") if leg else None,
        current_leg_slug=leg.get("slug") if leg else None,
    )


def enrich_grounding_text(
    g: GroundingPayload,
    db: sqlite3.Connection,
) -> str:
    """Render grounding as text for the system prompt, enriching with DB data."""
    iso_date = g.local_time_iso[:10]

    lines = [f"Now: {g.local_time_iso}"]
    if g.timezone:
        lines.append(f"Timezone: {g.timezone}")

    if g.gps_lat is not None and g.gps_lon is not None:
        lines.append(f"GPS: {g.gps_lat:.4f}, {g.gps_lon:.4f}")
        if g.gps_accuracy_m is not None:
            lines[-1] += f" (+/- {g.gps_accuracy_m:.0f}m)"
    else:
        lines.append("GPS: (not provided)")

    # Enrich with DB data
    leg = find_current_leg(db, iso_date) if not g.current_leg_id else None
    if g.current_leg_id:
        row = db.execute("SELECT * FROM leg WHERE id = ?", (g.current_leg_id,)).fetchone()
        if row:
            leg = dict(row)

    if leg:
        lines.append(
            f"Current leg: {leg.get('name')} ({leg.get('start_date')} → {leg.get('end_date')}); "
            f"places: {leg.get('places') or '—'}"
        )
    else:
        lines.append("Current leg: (none — between legs or pre-trip)")

    bookings = todays_bookings(db, iso_date)
    if bookings:
        lines.append("Today's bookings:")
        for b in bookings:
            lines.append(
                f"  - [{b.get('type')}] {b.get('name')} ({b.get('status')})"
                f" {b.get('start_date') or ''} {('@ ' + b.get('location_name')) if b.get('location_name') else ''}".strip()
            )
    else:
        lines.append("Today's bookings: none")

    nb = next_booking_after(db, g.local_time_iso)
    if nb:
        lines.append(f"Next booking: {nb.get('name')} on {nb.get('start_date')} ({nb.get('type')})")

    lines.append(f"Open tasks: {open_tasks_count(db)}")
    return "\n".join(lines)


# Keep backward compat alias
def grounding_to_text(g: GroundingPayload, db: Optional[sqlite3.Connection] = None) -> str:
    if db is not None:
        return enrich_grounding_text(g, db)
    # Minimal fallback without DB enrichment
    lines = [f"Now: {g.local_time_iso}"]
    if g.gps_lat is not None and g.gps_lon is not None:
        lines.append(f"GPS: {g.gps_lat:.4f}, {g.gps_lon:.4f}")
    return "\n".join(lines)
