#!/usr/bin/env python3
"""
Migrate Trip HQ data from the React artifact JSON export into the Wayfarer SQLite database.

Usage:
    python migrate_trip_hq.py                          # creates wayfarer.db in current dir
    python migrate_trip_hq.py --db /path/to/wayfarer.db
    python migrate_trip_hq.py --export-gmaps           # also writes Google Maps CSV
"""

import argparse
import json
import sqlite3
import uuid
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
DATA_DIR = SCRIPT_DIR.parent.parent / "data"
SCHEMA_PATH = SCRIPT_DIR / "schema.sql"
EXPORT_JSON = DATA_DIR / "trip-hq-export.json"

# ── Trip definition ─────────────────────────────────────────────

TRIP = {
    "name": "Europe 2026",
    "start_date": "2026-03-11",
    "end_date": "2026-06-24",
}

# ── Legs (from hardcoded LEGS constant in JSX) ─────────────────

LEGS = [
    {"slug": "pre",          "name": "Pre-Trip",       "emoji": "🏠", "color": "#6366f1", "start": "2026-03-11", "end": "2026-04-01", "schengen": False, "budget": 3000, "places": "Cozumel → Alaska → Florida → Spain/Andorra"},
    {"slug": "tunisia",      "name": "Tunisia",        "emoji": "🇹🇳", "color": "#f59e0b", "start": "2026-04-02", "end": "2026-04-10", "schengen": False, "budget": 1200, "places": "Tunis, Carthage, Dougga, El Jem, Matmata, La Goulette"},
    {"slug": "sicily",       "name": "Sicily",         "emoji": "🇮🇹", "color": "#ef4444", "start": "2026-04-12", "end": "2026-04-26", "schengen": True,  "budget": 2500, "places": "Palermo → Agrigento → Ragusa → Modica → Malta → Syracuse → Catania → Giardini Naxos → Palermo"},
    {"slug": "malta",        "name": "Malta",          "emoji": "🇲🇹", "color": "#3b82f6", "start": "2026-04-16", "end": "2026-04-21", "schengen": True,  "budget": 1800, "places": "Birgu/Vittoriosa, Valletta, Mdina, Three Cities, Marsaxlokk, Gozo"},
    {"slug": "sardinia",     "name": "Sardinia",       "emoji": "🇮🇹", "color": "#10b981", "start": "2026-04-26", "end": "2026-05-08", "schengen": True,  "budget": 2800, "places": "Cagliari → Oliena → Dorgali → Cala Gonone → Alghero → Oristano"},
    {"slug": "italy-cities", "name": "Italian Cities", "emoji": "🇮🇹", "color": "#8b5cf6", "start": "2026-05-08", "end": "2026-06-02", "schengen": True,  "budget": 4500, "places": "Praiano/Amalfi → Matera → Puglia → Lecce → Cinque Terre → Bologna → Turin → Lake Como"},
    {"slug": "slovenia",     "name": "Slovenia",       "emoji": "🇸🇮", "color": "#06b6d4", "start": "2026-05-22", "end": "2026-06-02", "schengen": True,  "budget": 2200, "places": "Ljubljana, Soča Valley, Triglav, Bled"},
    {"slug": "slovakia",     "name": "Slovakia",       "emoji": "🇸🇰", "color": "#ec4899", "start": "2026-06-03", "end": "2026-06-09", "schengen": True,  "budget": 1200, "places": "Bratislava, Slovak Paradise, High Tatras"},
    {"slug": "garda",        "name": "Lake Garda",     "emoji": "🇮🇹", "color": "#14b8a6", "start": "2026-06-10", "end": "2026-06-12", "schengen": True,  "budget": 750,  "places": "Riva del Garda"},
    {"slug": "dolomites",    "name": "Dolomites",      "emoji": "🏔️",  "color": "#f97316", "start": "2026-06-13", "end": "2026-06-24", "schengen": True,  "budget": 3000, "places": "Tre Cime, Cortina, Seceda, Marmolada"},
]

# ── Ghost task IDs to drop ──────────────────────────────────────
# These are titleless duplicates superseded by the real booked tasks.

GHOST_TASK_IDS = {"tn01x", "tn02x", "tn03x", "tn04x", "t09x", "t10x", "t08x", "t11x"}

# ── Hotel geocoding ─────────────────────────────────────────────
# Lat/lon for each hotel/rifugio booking, keyed by original Trip HQ ID.
# Coordinates sourced from Google Maps for the specific property.

HOTEL_COORDS = {
    # Pre-trip
    "gc03":  {"loc": "Fairbanks, Alaska",       "lat": 64.8378,  "lon": -147.7164},  # Wedgewood Resort
    "gc16":  {"loc": "Miami Lakes, Florida",     "lat": 25.9065,  "lon": -80.3340},   # VRBO 18610 NW 8th Rd
    "gc25":  {"loc": "Pas de la Casa, Andorra",  "lat": 42.5425,  "lon": 1.7336},     # Hotel Focus
    "gc26":  {"loc": "Barcelona, Spain",         "lat": 41.3851,  "lon": 2.1734},     # Hotel Nouvel, Las Ramblas

    # Tunisia
    "gc28":  {"loc": "La Marsa, Tunisia",        "lat": 36.8784,  "lon": 10.3247},    # Dar Souad
    "gc29":  {"loc": "Ghomrassen, Tunisia",      "lat": 33.0644,  "lon": 10.3422},    # Ksar Hadada
    "gc29b": {"loc": "Matmata, Tunisia",         "lat": 33.5444,  "lon": 9.9717},     # Hotel Sidi Idris
    "gc29c": {"loc": "Tunis, Tunisia",           "lat": 36.7964,  "lon": 10.1815},    # Hôtel Suisse Tunis

    # Sicily
    "gc29e": {"loc": "Palermo, Sicily",          "lat": 38.1157,  "lon": 13.3615},    # B&B D'Angelo
    "gc29f": {"loc": "Agrigento, Sicily",        "lat": 37.3111,  "lon": 13.5766},    # Duomo Rent Room, Via Madonna della Neve 1
    "gc29j": {"loc": "Ragusa Ibla, Sicily",      "lat": 36.9256,  "lon": 14.7326},    # Il Canale Design House, Via Canale 2
    "gc29l": {"loc": "Syracuse (Ortigia), Sicily","lat": 37.0588, "lon": 15.2938},    # Maison Ortigia, Piazza San Giuseppe 25
    "gc29m": {"loc": "Catania, Sicily",          "lat": 37.5079,  "lon": 15.0830},    # B&B Domus Pina
    "gc29n": {"loc": "Giardini Naxos, Sicily",   "lat": 37.8231,  "lon": 15.2680},    # Mimosa B&B, Via Ischia 58
    "gc29o": {"loc": "Palermo, Sicily",          "lat": 38.1182,  "lon": 13.3566},    # B&B Benincasa, Via Benedetto Gravina 67

    # Malta
    "gc29k": {"loc": "Birgu (Vittoriosa), Malta","lat": 35.8881,  "lon": 14.5225},    # Number 20, 20 Convent Street

    # Sardinia
    "sar01": {"loc": "Cagliari, Sardinia",       "lat": 39.2178,  "lon": 9.1135},     # White Moon, Via G.M. Dettori 5
    "sar02": {"loc": "Oliena, Sardinia",         "lat": 40.2714,  "lon": 9.4029},     # Gli Olivi B&B, Via Alghero 6
    "sar03": {"loc": "Dorgali, Sardinia",        "lat": 40.2883,  "lon": 9.5956},     # La Croisette, Località Predu SP64
    "sar04": {"loc": "Cala Gonone, Sardinia",    "lat": 40.2835,  "lon": 9.6320},     # B&B Ichnos, Via delle Conchiglie 5
    "sar05": {"loc": "Alghero, Sardinia",        "lat": 40.5588,  "lon": 8.3190},     # B&B Alghero Aigua, Via Ambrogio Machin 22
    "sar06": {"loc": "Oristano, Sardinia",       "lat": 39.9036,  "lon": 8.5921},     # Sa Domu e Crakeras, Via G.M. Angioy 49

    # Italy Cities (not yet booked — city-center coords as placeholders)
    "ita01": {"loc": "Praiano, Amalfi Coast",    "lat": 40.6120,  "lon": 14.5310},
    "ita02": {"loc": "Matera, Basilicata",       "lat": 40.6664,  "lon": 16.6114},
    "ita03": {"loc": "Ostuni, Puglia",           "lat": 40.7296,  "lon": 17.5779},
    "ita04": {"loc": "Lecce, Puglia",            "lat": 40.3516,  "lon": 18.1750},

    # Dolomites
    "gc30":  {"loc": "Innsbruck, Austria",       "lat": 47.2692,  "lon": 11.3933},    # Goldener Adler
    "gc31":  {"loc": "Dobbiaco, South Tyrol",    "lat": 46.7312,  "lon": 12.2197},    # Youth Hostel Toblach
    "gc32":  {"loc": "Passo Falzarego, Dolomites","lat": 46.5189, "lon": 11.9978},    # Rifugio Col Gallina
    "gc33":  {"loc": "Passo Falzarego, Dolomites","lat": 46.5205, "lon": 12.0042},    # Hotel Al Sasso di Stria
    "gc34":  {"loc": "Transacqua, Trentino",     "lat": 46.1778,  "lon": 11.8350},    # Hotel Castel Pietra
    "gc35":  {"loc": "Pale di San Martino",      "lat": 46.2603,  "lon": 11.8382},    # Rifugio Castiglioni
    "gc36":  {"loc": "Pozza di Fassa, Trentino", "lat": 46.4290,  "lon": 11.6870},    # GH Hotel Piaz
}

# ── Transport/activity location coords (for non-hotel bookings) ─

TRANSPORT_COORDS = {
    "gc01":  {"loc": "Cancún Airport (CUN)"},
    "gc02":  {"loc": "Seattle (SEA)"},
    "gc14":  {"loc": "Fairbanks Airport (FAI)"},
    "gc15":  {"loc": "Seattle (SEA)"},
    "gc23":  {"loc": "Miami Airport (MIA)"},
    "gc24":  {"loc": "Lisbon (LIS)"},
    "gc27":  {"loc": "Barcelona (BCN)"},
    "gc37":  {"loc": "Munich Airport (MUC)"},
    "gc38":  {"loc": "Dublin (DUB)"},
    "gc29d": {"loc": "La Goulette, Tunisia"},
    "gc29g": {"loc": "Pozzallo, Sicily"},
    "gc29h": {"loc": "Valletta, Malta"},
    "gc29i": {"loc": "Palermo, Sicily"},
    "sar07": {"loc": "Cagliari, Sardinia"},
}

# ── Packing defaults (from JSX DEFAULT_PACKING) ────────────────

PACKING_CATEGORIES = [
    "clothing", "layers", "footwear", "toiletries",
    "electronics", "documents", "gear", "misc",
]

DEFAULT_PACKING = [
    ("clothing",    "T-shirts (3, merino/synthetic blend)"),
    ("clothing",    "Long-sleeve shirts (2)"),
    ("clothing",    "Simond Alpinism Light Evo pants"),
    ("clothing",    "Hiking pants (2nd pair, lightweight)"),
    ("clothing",    "Shorts (1, double as swim trunks)"),
    ("clothing",    "Underwear (5, merino or quick-dry)"),
    ("clothing",    "Darn Tough socks (4 pair)"),
    ("clothing",    "Liner socks (2 pair)"),
    ("clothing",    "Sun hat / cap"),
    ("clothing",    "Buff / neck gaiter"),
    ("layers",      "Lightweight down puffy (Decathlon)"),
    ("layers",      "Fleece midlayer"),
    ("layers",      "Rain-resistant jacket"),
    ("layers",      "Warm hat / beanie"),
    ("layers",      "Balaclava"),
    ("layers",      "Gloves"),
    ("layers",      "Fleece pants"),
    ("layers",      "Sun hoodie"),
    ("footwear",    "Kiprun TR2 trail runners — Click & Collect Barcelona"),
    ("footwear",    "Sandals (Chacos or Tevas)"),
    ("toiletries",  "Toiletry kit (travel sizes)"),
    ("toiletries",  "Sunscreen (SPF 50)"),
    ("toiletries",  "Prescription medications (full supply)"),
    ("toiletries",  "Creatine supply"),
    ("toiletries",  "First aid kit"),
    ("toiletries",  "Insect repellent"),
    ("toiletries",  "Microfiber towel"),
    ("toiletries",  "Earplugs + sleep mask"),
    ("electronics", "Phone + charger"),
    ("electronics", "Power bank (20,000 mAh)"),
    ("electronics", "Universal adapter (EU plugs)"),
    ("electronics", "Earbuds / headphones"),
    ("electronics", "USB-C cables (2)"),
    ("electronics", "Kindle / e-reader"),
    ("electronics", "Laptop"),
    ("documents",   "Passport (valid 6+ months)"),
    ("documents",   "IDP — International Driving Permit"),
    ("documents",   "US driver's license"),
    ("documents",   "Credit cards (2 different networks)"),
    ("documents",   "Debit card (Schwab or no-fee ATM)"),
    ("documents",   "Travel insurance docs"),
    ("documents",   "Copies of passport + IDs"),
    ("documents",   "Booking confirmations (offline)"),
    ("gear",        "Daypack (20-25L, packable)"),
    ("gear",        "Trekking poles — Forclaz collapsible (Decathlon Barcelona)"),
    ("gear",        "Headlamp"),
    ("gear",        "Water bottle (1L, collapsible)"),
    ("gear",        "Ski goggles — Wedze G500 (Decathlon Barcelona)"),
    ("gear",        "Sunglasses (polarized)"),
    ("gear",        "Dive cert card (for Malta / Tunisia)"),
    ("misc",        "Packing cubes / compression bags"),
    ("misc",        "Dry bag (small)"),
    ("misc",        "Laundry soap sheets"),
    ("misc",        "Clothesline"),
    ("misc",        "Carabiner + small lock"),
    ("misc",        "Pen (for customs forms)"),
    ("misc",        "Hearing aids + batteries/charger"),
]

# ── Cost parsing ────────────────────────────────────────────────

# Bookings where the cost value is in EUR, not USD.
# Identified from notes mentioning € or European pricing context.
EUR_COST_BOOKINGS = {"gc28", "gc29b", "gc29c"}


def parse_cost(booking_id: str, cost_str: str) -> tuple[int | None, str]:
    """Return (cost_cents, currency) from the raw cost string."""
    if not cost_str:
        return None, "USD"
    try:
        amount = float(cost_str)
    except ValueError:
        return None, "USD"
    currency = "EUR" if booking_id in EUR_COST_BOOKINGS else "USD"
    return int(round(amount * 100)), currency


# ── Status normalization ────────────────────────────────────────

def normalize_status(status: str) -> str:
    """Convert JSX status values to schema-compatible values."""
    return status.replace("-", "_")  # "needs-booking" → "needs_booking"


# ── Migration ───────────────────────────────────────────────────

def migrate(db_path: str, export_gmaps: bool = False):
    export = json.loads(EXPORT_JSON.read_text())
    data = export["europe-trip-hq-2026-v2"]

    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")

    # Apply schema
    conn.executescript(SCHEMA_PATH.read_text())

    # ── Trip ──
    trip_id = str(uuid.uuid4())
    conn.execute(
        "INSERT INTO trip (id, name, start_date, end_date) VALUES (?, ?, ?, ?)",
        (trip_id, TRIP["name"], TRIP["start_date"], TRIP["end_date"]),
    )

    # ── Legs ──
    slug_to_leg_id = {}
    for i, leg in enumerate(LEGS):
        leg_id = str(uuid.uuid4())
        slug_to_leg_id[leg["slug"]] = leg_id
        conn.execute(
            """INSERT INTO leg
               (id, trip_id, slug, name, emoji, color, start_date, end_date,
                is_schengen, budget_cents, currency, places, sort_order)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'USD', ?, ?)""",
            (
                leg_id, trip_id, leg["slug"], leg["name"], leg["emoji"],
                leg["color"], leg["start"], leg["end"],
                1 if leg["schengen"] else 0,
                leg["budget"] * 100,  # dollars → cents
                leg["places"],
                i,
            ),
        )

    # ── Bookings ──
    for b in data["bookings"]:
        leg_id = slug_to_leg_id.get(b["leg"])
        if not leg_id:
            print(f"  WARN: booking {b['id']} has unknown leg '{b['leg']}', skipping")
            continue

        cost_cents, currency = parse_cost(b["id"], b.get("cost", ""))
        coords = HOTEL_COORDS.get(b["id"]) or TRANSPORT_COORDS.get(b["id"]) or {}

        conn.execute(
            """INSERT INTO booking
               (id, leg_id, type, name, status, start_date, end_date,
                confirmation, cost_cents, currency,
                location_name, location_lat, location_lon, notes)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                str(uuid.uuid4()),
                leg_id,
                b["type"],
                b["name"],
                normalize_status(b["status"]),
                b.get("date") or None,
                b.get("dateEnd") or None,
                b.get("confirmation") or None,
                cost_cents,
                currency,
                coords.get("loc"),
                coords.get("lat"),
                coords.get("lon"),
                b.get("notes") or None,
            ),
        )

    # ── Tasks (drop ghosts) ──
    dropped = 0
    for t in data["tasks"]:
        if t["id"] in GHOST_TASK_IDS:
            dropped += 1
            continue

        title = t.get("title", "").strip()
        if not title:
            dropped += 1
            continue

        # Clean emoji prefixes from titles (e.g. "✅ IDP obtained" → "IDP obtained")
        for prefix in ("✅ ", "🔴 "):
            if title.startswith(prefix):
                title = title[len(prefix):]

        leg_id = slug_to_leg_id.get(t.get("leg", ""))

        conn.execute(
            """INSERT INTO task
               (id, leg_id, title, priority, due_date, is_done, notes)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (
                str(uuid.uuid4()),
                leg_id,
                title,
                t["priority"],
                t.get("due") or None,
                1 if t.get("done") else 0,
                t.get("notes") or None,
            ),
        )

    # ── Packing ──
    for i, (cat, item_name) in enumerate(DEFAULT_PACKING):
        conn.execute(
            """INSERT INTO packing_item
               (id, trip_id, category, name, is_packed, sort_order)
               VALUES (?, ?, ?, ?, 0, ?)""",
            (str(uuid.uuid4()), trip_id, cat, item_name, i),
        )

    conn.commit()

    # ── Summary ── (singular table names per BEST_PRACTICES.md §3.1)
    counts = {}
    for table in ("trip", "leg", "booking", "task", "packing_item", "journal_entry"):
        counts[table] = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]

    print(f"\nMigration complete → {db_path}")
    print(f"  trip:           {counts['trip']}")
    print(f"  leg:            {counts['leg']}")
    print(f"  booking:        {counts['booking']}")
    print(f"  task:           {counts['task']} ({dropped} ghosts dropped)")
    print(f"  packing_item:   {counts['packing_item']}")
    print(f"  journal_entry:  {counts['journal_entry']}")

    with_coords = conn.execute(
        "SELECT COUNT(*) FROM booking WHERE location_lat IS NOT NULL"
    ).fetchone()[0]
    print(f"  bookings with coords: {with_coords}")

    # ── Google Maps export ──
    if export_gmaps:
        export_google_maps_csv(conn, db_path)

    conn.close()


# ── Google Maps CSV export ──────────────────────────────────────
#
# Google My Maps import format: CSV with columns
#   Name, Description, Latitude, Longitude, Category
#
# To use:
#   1. Go to https://www.google.com/maps/d/
#   2. Create new map → Import → upload the CSV
#   3. Select Latitude/Longitude columns when prompted
#   4. Select Name as the place marker title
#   All pins appear on your map, organized by category.
#
# To save individual locations to your Google Maps:
#   Open the URL in the "gmaps_url" column — it deep-links to
#   the exact coordinates. Tap "Save" → choose a list.

def export_google_maps_csv(conn: sqlite3.Connection, db_path: str):
    """Export hotel/rifugio bookings with coordinates as Google My Maps CSV."""
    rows = conn.execute(
        """SELECT b.name, b.start_date, b.end_date, b.location_name,
                  b.location_lat, b.location_lon, b.type, b.notes,
                  l.name as leg_name, l.emoji
           FROM booking b
           JOIN leg l ON b.leg_id = l.id
           WHERE b.location_lat IS NOT NULL
             AND b.type IN ('hotel', 'rifugio')
           ORDER BY b.start_date""",
    ).fetchall()

    csv_path = Path(db_path).parent / "wayfarer-hotels-gmaps.csv"

    import csv
    with open(csv_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "Name", "Description", "Latitude", "Longitude",
            "Category", "Dates", "Google Maps URL",
        ])
        for name, start, end, loc, lat, lon, btype, notes, leg, emoji in rows:
            dates = start or ""
            if end:
                dates += f" → {end}"
            desc = f"{emoji} {leg} | {loc or ''}"
            if notes:
                # Truncate long notes for CSV readability
                short_notes = notes[:120] + "..." if len(notes) > 120 else notes
                desc += f" | {short_notes}"

            gmaps_url = f"https://www.google.com/maps/search/?api=1&query={lat},{lon}"

            writer.writerow([name, desc, lat, lon, btype, dates, gmaps_url])

    print(f"\n  Google Maps CSV → {csv_path}")
    print(f"  {len(rows)} hotels/rifugios with coordinates")
    print(f"  Import at: https://www.google.com/maps/d/ → Create → Import")
    print(f"  Or open individual Google Maps URLs to save to a list.")


# ── CLI ─────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migrate Trip HQ → Wayfarer SQLite")
    parser.add_argument("--db", default=str(SCRIPT_DIR / "wayfarer.db"),
                        help="Output database path")
    parser.add_argument("--export-gmaps", action="store_true",
                        help="Also export Google Maps CSV for hotel locations")
    args = parser.parse_args()

    # Remove existing DB to start clean
    db = Path(args.db)
    if db.exists():
        db.unlink()
        print(f"Removed existing {db}")

    migrate(args.db, export_gmaps=args.export_gmaps)
