#!/usr/bin/env python3
"""
Extract SEED_BOOKINGS and SEED_TASKS from trip-hq.jsx and emit
trip-hq-export.json in the shape that backend/db/migrate_trip_hq.py expects:

    {
      "europe-trip-hq-2026-v2": {
        "bookings": [...],
        "tasks":    [...]
      }
    }

Run:
    python3 data/extract_trip_hq.py
"""

import json
import re
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
JSX_PATH   = SCRIPT_DIR / "trip-hq.jsx"
OUT_PATH   = SCRIPT_DIR / "trip-hq-export.json"
STORAGE_KEY = "europe-trip-hq-2026-v2"


def extract_array(jsx_text: str, const_name: str) -> str:
    """Return the inner body of `const <name> = [ ... ];`."""
    m = re.search(
        rf"const\s+{re.escape(const_name)}\s*=\s*\[(.*?)\];",
        jsx_text,
        re.DOTALL,
    )
    if not m:
        raise RuntimeError(f"could not locate {const_name} in JSX")
    return m.group(1)


def parse_object_line(line: str) -> dict:
    """Convert a single-line JS object literal (unquoted keys, double-quoted
    string values, booleans) into a Python dict."""
    obj_text = line.rstrip(",").strip()

    # Mask out string literals so the key-quoting regex can't touch their
    # internals (notes contain colons, commas, braces, etc.).
    strings: list[str] = []

    def stash(m: re.Match) -> str:
        strings.append(m.group(0))
        return f"__S{len(strings) - 1}__"

    masked = re.sub(r'"[^"]*"', stash, obj_text)

    # Quote bare identifier keys: `id:` → `"id":`. Anchor on `{` or `,` so we
    # only catch object keys, not random identifiers in expressions.
    masked = re.sub(
        r'([{,])\s*([A-Za-z_]\w*)\s*:',
        r'\1"\2":',
        masked,
    )

    restored = re.sub(
        r"__S(\d+)__",
        lambda m: strings[int(m.group(1))],
        masked,
    )
    return json.loads(restored)


def parse_array_body(body: str) -> list[dict]:
    """Walk the body line-by-line, returning a list of parsed objects."""
    items: list[dict] = []
    for raw in body.split("\n"):
        line = raw.strip()
        if not line or line.startswith("//"):
            continue
        if not line.startswith("{"):
            # Defensive: skip any unexpected non-object line rather than
            # silently misparsing.
            raise RuntimeError(f"unexpected line in array body: {line!r}")
        items.append(parse_object_line(line))
    return items


def main() -> None:
    jsx = JSX_PATH.read_text()

    bookings = parse_array_body(extract_array(jsx, "SEED_BOOKINGS"))
    tasks    = parse_array_body(extract_array(jsx, "SEED_TASKS"))

    export = {
        STORAGE_KEY: {
            "bookings": bookings,
            "tasks":    tasks,
            "budget":   {},
            "notes":    {},
        }
    }

    OUT_PATH.write_text(json.dumps(export, indent=2, ensure_ascii=False))
    print(f"Wrote {OUT_PATH}")
    print(f"  bookings: {len(bookings)}")
    print(f"  tasks:    {len(tasks)}")


if __name__ == "__main__":
    main()
