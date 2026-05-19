#!/usr/bin/env python3
"""
Migrate Trip HQ v3 data (May 2026 Claude export) into the Wayfarer SQLite database.

Usage:
    python migrate_trip_hq_v3.py                          # creates wayfarer.db in current dir
    python migrate_trip_hq_v3.py --db /path/to/wayfarer.db
"""

import argparse
import json
import re
import sqlite3
import uuid
from datetime import datetime, timedelta
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
DATA_DIR = SCRIPT_DIR.parent.parent / "data"
SCHEMA_PATH = SCRIPT_DIR / "schema.sql"
EXPORT_JSON = DATA_DIR / "trip-hq-export-v3.json"

# ── Legs ─────────────────────────────────────────────────────────
# Updated to match the v3 region-based structure.
# Pre-trip and Tunisia kept from v1 (not in v3 bookings but historically valid).

LEGS = [
    {"slug": "pre",           "name": "Pre-Trip",       "emoji": "🏠", "color": "#6366f1", "start": "2026-03-11", "end": "2026-04-01", "schengen": False, "budget": 3000, "places": "Cozumel → Alaska → Florida → Spain/Andorra"},
    {"slug": "tunisia",       "name": "Tunisia",        "emoji": "🇹🇳", "color": "#f59e0b", "start": "2026-04-02", "end": "2026-04-11", "schengen": False, "budget": 1200, "places": "Tunis, Carthage, Dougga, El Jem, Matmata, Sfax, La Goulette"},
    {"slug": "sicily",        "name": "Sicily",         "emoji": "🇮🇹", "color": "#ef4444", "start": "2026-04-12", "end": "2026-04-26", "schengen": True,  "budget": 2500, "places": "Palermo → Agrigento → Ragusa/Modica → Malta → Syracuse → Catania → Giardini Naxos → Palermo"},
    {"slug": "sardinia",      "name": "Sardinia",       "emoji": "🇮🇹", "color": "#10b981", "start": "2026-04-26", "end": "2026-05-07", "schengen": True,  "budget": 2800, "places": "Oliena → Dorgali → Cala Gonone → Alghero → Oristano → Cagliari"},
    {"slug": "italy-south",   "name": "Italy South",    "emoji": "🇮🇹", "color": "#8b5cf6", "start": "2026-05-08", "end": "2026-05-20", "schengen": True,  "budget": 3000, "places": "Piano di Sorrento → Path of the Gods → Rome (Italian Open) → Matera → Ostuni → Lecce"},
    {"slug": "italy-north",   "name": "Italy North",    "emoji": "🇮🇹", "color": "#6366f1", "start": "2026-05-20", "end": "2026-05-29", "schengen": True,  "budget": 2500, "places": "Bologna → Bonassola/Cinque Terre → Turin → Verona"},
    {"slug": "slovenia",      "name": "Slovenia",       "emoji": "🇸🇮", "color": "#06b6d4", "start": "2026-05-29", "end": "2026-06-12", "schengen": True,  "budget": 3000, "places": "Ljubljana → Bled → Bohinj → Bovec/Soča → Kobarid → Piran → Trieste"},
    {"slug": "dolomites",     "name": "Dolomites",      "emoji": "🏔️",  "color": "#f97316", "start": "2026-06-12", "end": "2026-06-24", "schengen": True,  "budget": 3000, "places": "Bolzano → Chiusa → Dobbiaco → Falzarego → San Martino → Marmolada → Val di Fassa → Innsbruck → MUC"},
]

# Map v3 region names to leg slugs
REGION_TO_SLUG = {
    "Sicily": "sicily",
    "Sardinia": "sardinia",
    "Italy South": "italy-south",
    "Italy North": "italy-north",
    "Slovenia": "slovenia",
    "Dolomites": "dolomites",
}

# ── Type mapping ─────────────────────────────────────────────────
# v3 uses "lodging", "transport", "activity" — map to schema types.

FERRY_PATTERNS = re.compile(r"ferry|trasmed|grimaldi", re.IGNORECASE)
FLIGHT_PATTERNS = re.compile(r"aer lingus|flight|EI \d|AS \d", re.IGNORECASE)
CAR_PATTERNS = re.compile(r"car rental|fiat panda|sixt|pickup.*rental|rental.*pickup", re.IGNORECASE)
RIFUGIO_PATTERNS = re.compile(r"rifugio", re.IGNORECASE)


def map_booking_type(v3_type: str, name: str, place: str) -> str:
    """Map v3 booking type to schema type."""
    if v3_type == "activity":
        return "activity"
    if v3_type == "lodging":
        if RIFUGIO_PATTERNS.search(name):
            return "rifugio"
        return "hotel"
    if v3_type == "transport":
        combined = f"{name} {place}"
        if FERRY_PATTERNS.search(combined):
            return "ferry"
        if FLIGHT_PATTERNS.search(combined):
            return "flight"
        if CAR_PATTERNS.search(combined):
            return "car"
        return "train"
    return "other"


# ── Status mapping ───────────────────────────────────────────────

def map_status(v3_status: str) -> str:
    """Map v3 status to schema status."""
    if v3_status in ("done", "current", "booked"):
        return "booked"
    if v3_status == "pending":
        return "pending"
    if v3_status == "needs-booking":
        return "needs_booking"
    return "pending"


# ── Cost parsing ─────────────────────────────────────────────────

def parse_cost(cost_str: str | None) -> tuple[int | None, str]:
    """Return (cost_cents, currency) from freeform cost strings."""
    if not cost_str:
        return None, "USD"

    currency = "EUR" if "€" in cost_str else "USD"

    # Strip currency symbols and common suffixes
    cleaned = cost_str.replace("€", "").replace("$", "").replace(",", "")
    cleaned = cleaned.replace("RT total", "").replace("RT", "")
    cleaned = cleaned.replace("total", "").replace("/night", "").strip()
    cleaned = cleaned.lstrip("~")

    try:
        amount = float(cleaned)
        return int(round(amount * 100)), currency
    except ValueError:
        return None, currency


# ── End date computation ─────────────────────────────────────────

def compute_end_date(start_date: str, nights: int) -> str | None:
    """Compute end date from start + nights. Returns None for 0-night entries."""
    if nights <= 0:
        return None
    start = datetime.strptime(start_date, "%Y-%m-%d")
    end = start + timedelta(days=nights)
    return end.strftime("%Y-%m-%d")


# ── Migration ───────────────────────────────────────────────────

def migrate(db_path: str):
    export = json.loads(EXPORT_JSON.read_text())
    trip_info = export["trip"]

    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")

    # Apply schema
    conn.executescript(SCHEMA_PATH.read_text())

    now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    # ── Trip ──
    trip_id = str(uuid.uuid4())
    conn.execute(
        "INSERT INTO trips (id, name, start_date, end_date, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
        (trip_id, trip_info["name"], trip_info["start_date"], trip_info["end_date"], now, now),
    )

    # ── Legs ──
    slug_to_leg_id = {}
    for i, leg in enumerate(LEGS):
        leg_id = str(uuid.uuid4())
        slug_to_leg_id[leg["slug"]] = leg_id
        conn.execute(
            """INSERT INTO legs
               (id, trip_id, slug, name, emoji, color, start_date, end_date,
                is_schengen, budget_cents, currency, places, sort_order, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'USD', ?, ?, ?, ?)""",
            (
                leg_id, trip_id, leg["slug"], leg["name"], leg["emoji"],
                leg["color"], leg["start"], leg["end"],
                1 if leg["schengen"] else 0,
                leg["budget"] * 100,
                leg["places"],
                i,
                now, now,
            ),
        )

    # ── Bookings ──
    booking_count = 0
    skipped = 0
    for b in export["bookings"]:
        region = b.get("region", "")
        slug = REGION_TO_SLUG.get(region)
        if not slug:
            print(f"  WARN: booking {b['id']} has unknown region '{region}', skipping")
            skipped += 1
            continue

        leg_id = slug_to_leg_id[slug]
        btype = map_booking_type(b["type"], b["name"], b.get("place", ""))
        status = map_status(b["status"])
        cost_cents, currency = parse_cost(b.get("cost"))
        end_date = compute_end_date(b["date"], b.get("nights", 0))

        # Build notes from extra fields
        notes_parts = []
        if b.get("notes"):
            notes_parts.append(b["notes"])
        if b.get("host"):
            notes_parts.append(f"Host: {b['host']}")
        if b.get("pin"):
            notes_parts.append(f"PIN: {b['pin']}")
        notes = " · ".join(notes_parts) if notes_parts else None

        conn.execute(
            """INSERT INTO bookings
               (id, leg_id, type, name, status, start_date, end_date,
                confirmation, cost_cents, currency,
                location_name, notes, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                str(uuid.uuid4()),
                leg_id,
                btype,
                b["name"],
                status,
                b["date"],
                end_date,
                b.get("confirmation"),
                cost_cents,
                currency,
                b.get("place"),
                notes,
                now, now,
            ),
        )
        booking_count += 1

    # ── Tasks (from todos) ──
    task_count = 0
    for t in export.get("todos", []):
        text = t.get("text", "").strip()
        if not text:
            continue

        # Map urgent → priority
        if t.get("urgent"):
            priority = "high"
        elif t.get("done"):
            priority = "low"
        else:
            priority = "medium"

        conn.execute(
            """INSERT INTO tasks
               (id, leg_id, title, priority, is_done, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (
                str(uuid.uuid4()),
                None,  # todos in v3 aren't leg-specific
                text,
                priority,
                1 if t.get("done") else 0,
                now, now,
            ),
        )
        task_count += 1

    # ── Preserve existing packing items ──
    # Don't re-insert packing — they were set up in v1 and may have been modified.
    # Only insert if table is empty.
    packing_count = conn.execute("SELECT COUNT(*) FROM packing_items").fetchone()[0]
    if packing_count == 0:
        from migrate_trip_hq import DEFAULT_PACKING
        for i, (cat, item_name) in enumerate(DEFAULT_PACKING):
            conn.execute(
                """INSERT INTO packing_items
                   (id, trip_id, category, name, is_packed, sort_order, created_at, updated_at)
                   VALUES (?, ?, ?, ?, 0, ?, ?, ?)""",
                (str(uuid.uuid4()), trip_id, cat, item_name, i, now, now),
            )
        packing_count = len(DEFAULT_PACKING)

    conn.commit()

    # ── Summary ──
    counts = {}
    for table in ("trips", "legs", "bookings", "tasks", "packing_items", "journal_entries"):
        counts[table] = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]

    print(f"\nMigration complete → {db_path}")
    print(f"  trips:           {counts['trips']}")
    print(f"  legs:            {counts['legs']}")
    print(f"  bookings:        {counts['bookings']} ({skipped} skipped)")
    print(f"  tasks:           {counts['tasks']}")
    print(f"  packing_items:   {counts['packing_items']}")
    print(f"  journal_entries: {counts['journal_entries']}")

    conn.close()


# ── CLI ─────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migrate Trip HQ v3 → Wayfarer SQLite")
    parser.add_argument("--db", default=str(SCRIPT_DIR / "wayfarer.db"),
                        help="Output database path")
    args = parser.parse_args()

    # Remove existing DB to start clean
    db = Path(args.db)
    if db.exists():
        db.unlink()
        print(f"Removed existing {db}")

    migrate(args.db)
