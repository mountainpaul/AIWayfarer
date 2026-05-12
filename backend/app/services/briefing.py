"""
Pre-trip / morning briefing generator (spec §9).

Produces a compact markdown briefing for a given date. Computes the route from
today's and tomorrow's bookings + open tasks. Weather is stubbed (TODO).
"""

import sqlite3
from datetime import date as date_cls, datetime, timedelta, timezone
from typing import Optional


def _bookings_on(db: sqlite3.Connection, day: str) -> list[dict]:
    rows = db.execute(
        """SELECT * FROM bookings
           WHERE (start_date IS NOT NULL AND date(start_date) = date(?))
              OR (end_date   IS NOT NULL AND date(end_date)   = date(?))
              OR (start_date IS NOT NULL AND end_date IS NOT NULL
                  AND date(?) BETWEEN date(start_date) AND date(end_date))
           ORDER BY start_date ASC""",
        (day, day, day),
    ).fetchall()
    return [dict(r) for r in rows]


def _leg_for(db: sqlite3.Connection, day: str) -> Optional[dict]:
    row = db.execute(
        """SELECT * FROM legs WHERE date(?) BETWEEN date(start_date) AND date(end_date)
           ORDER BY start_date ASC LIMIT 1""",
        (day,),
    ).fetchone()
    return dict(row) if row else None


def _open_tasks(db: sqlite3.Connection, leg_id: Optional[str]) -> list[dict]:
    if leg_id:
        rows = db.execute(
            """SELECT * FROM tasks WHERE is_done = 0 AND (leg_id = ? OR leg_id IS NULL)
               ORDER BY CASE priority
                   WHEN 'critical' THEN 0 WHEN 'high' THEN 1
                   WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END,
                   due_date ASC""",
            (leg_id,),
        ).fetchall()
    else:
        rows = db.execute(
            """SELECT * FROM tasks WHERE is_done = 0
               ORDER BY CASE priority
                   WHEN 'critical' THEN 0 WHEN 'high' THEN 1
                   WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END,
                   due_date ASC LIMIT 10""",
        ).fetchall()
    return [dict(r) for r in rows]


def _format_booking(b: dict) -> str:
    bits = [f"**{b.get('name')}**"]
    if b.get("type"):
        bits.append(f"({b['type']})")
    if b.get("start_date"):
        bits.append(f"— {b['start_date']}")
    if b.get("location_name"):
        bits.append(f"@ {b['location_name']}")
    if b.get("status") and b["status"] != "booked":
        bits.append(f"[{b['status']}]")
    return " ".join(bits)


def generate_briefing(db: sqlite3.Connection, day: str) -> str:
    """Return a markdown string for the given ISO date (YYYY-MM-DD)."""
    try:
        d = date_cls.fromisoformat(day)
    except ValueError:
        d = datetime.now(timezone.utc).date()
        day = d.isoformat()
    tomorrow = (d + timedelta(days=1)).isoformat()

    leg = _leg_for(db, day)
    today_bk = _bookings_on(db, day)
    tomorrow_bk = _bookings_on(db, tomorrow)
    open_tasks = _open_tasks(db, leg["id"] if leg else None)

    out: list[str] = []
    weekday = d.strftime("%A")
    out.append(f"# Briefing — {weekday}, {day}")
    out.append("")

    if leg:
        emoji = (leg.get("emoji") or "").strip()
        out.append(f"## {emoji} {leg['name']}".strip())
        if leg.get("places"):
            out.append(f"_{leg['places']}_")
        out.append("")
    else:
        out.append("## Between legs")
        out.append("")

    if today_bk:
        out.append("## Today")
        for b in today_bk:
            out.append(f"- {_format_booking(b)}")
        out.append("")

    if tomorrow_bk:
        out.append(f"## Tomorrow ({tomorrow})")
        for b in tomorrow_bk:
            out.append(f"- {_format_booking(b)}")
        out.append("")

    out.append("## Weather")
    out.append("_TODO: weather lookup for current location._")
    out.append("")

    if open_tasks:
        shown = open_tasks[:5]
        out.append(f"## Open tasks ({len(open_tasks)} total)")
        for t in shown:
            due = f" — due {t['due_date']}" if t.get("due_date") else ""
            out.append(f"- **[{t['priority']}]** {t['title']}{due}")
        if len(open_tasks) > 5:
            out.append(f"- _…and {len(open_tasks) - 5} more_")
        out.append("")

    return "\n".join(out).rstrip() + "\n"
