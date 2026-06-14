"""Accommodation coverage: which nights of each leg have a lodging booking, and
how many don't. A "night" is modelled as the hotel convention — a stay from
check-in to check-out covers nights [start, end) (check-out day excluded). A leg
from start to end therefore needs lodging for nights [start, end).
"""
from datetime import date, timedelta

ACCOMMODATION_TYPES = {"hotel", "rifugio"}


def _nights(start: str, end: str) -> set[date]:
    """Night-dates in [start, end) — the nights slept; check-out day excluded."""
    s = date.fromisoformat(start)
    e = date.fromisoformat(end)
    out: set[date] = set()
    d = s
    while d < e:
        out.add(d)
        d += timedelta(days=1)
    return out


def leg_coverage(leg: dict, bookings: list[dict]) -> dict:
    leg_nights = _nights(leg["start_date"], leg["end_date"])
    covered: set[date] = set()
    for b in bookings:
        if b.get("type") not in ACCOMMODATION_TYPES or b.get("deleted_at"):
            continue
        if not b.get("start_date") or not b.get("end_date"):
            continue
        covered |= _nights(b["start_date"], b["end_date"])
    booked = covered & leg_nights
    return {
        "leg_id": leg["id"],
        "leg_name": leg["name"],
        "start_date": leg["start_date"],
        "end_date": leg["end_date"],
        "total_nights": len(leg_nights),
        "booked_nights": len(booked),
        "unbooked_nights": len(leg_nights) - len(booked),
    }


def report(legs: list[dict], bookings: list[dict]) -> list[dict]:
    by_leg: dict[str, list[dict]] = {}
    for b in bookings:
        by_leg.setdefault(b.get("leg_id"), []).append(b)
    return [leg_coverage(leg, by_leg.get(leg["id"], [])) for leg in legs]
