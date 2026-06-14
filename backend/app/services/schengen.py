"""Schengen 90/180 rule: a non-EU visitor may spend at most 90 days in any
rolling 180-day window in the Schengen area. We model each Schengen leg as an
inclusive date range (entry and exit days both count as days present), dedupe
overlapping legs via a set of dates, and report usage for a reference date plus
the worst-case (peak) usage across the whole trip.
"""
from datetime import date, timedelta

WINDOW_DAYS = 180
LIMIT_DAYS = 90
WARN_REMAINING = 10  # remaining <= this ⇒ warning


def schengen_days(legs: list[dict]) -> set[date]:
    """Every distinct calendar day spent in a (non-deleted) Schengen leg."""
    days: set[date] = set()
    for leg in legs:
        if not leg.get("is_schengen") or leg.get("deleted_at"):
            continue
        start = date.fromisoformat(leg["start_date"])
        end = date.fromisoformat(leg["end_date"])
        d = start
        while d <= end:
            days.add(d)
            d += timedelta(days=1)
    return days


def usage_on(days: set[date], as_of: date) -> int:
    """Days present in the 180-day window ending on (and including) as_of."""
    window_start = as_of - timedelta(days=WINDOW_DAYS - 1)
    return sum(1 for d in days if window_start <= d <= as_of)


def report(legs: list[dict], as_of: date) -> dict:
    days = schengen_days(legs)
    used = usage_on(days, as_of)

    # Peak rolling-180 usage across every day the trip touches Schengen.
    peak = 0
    peak_date: date | None = None
    if days:
        d, hi = min(days), max(days)
        while d <= hi:
            u = usage_on(days, d)
            if u > peak:
                peak, peak_date = u, d
            d += timedelta(days=1)

    remaining = LIMIT_DAYS - used
    if used > LIMIT_DAYS:
        status = "exceeded"
    elif remaining <= WARN_REMAINING:
        status = "warning"
    else:
        status = "ok"

    return {
        "as_of": as_of.isoformat(),
        "window_days": WINDOW_DAYS,
        "limit_days": LIMIT_DAYS,
        "days_used": used,
        "days_remaining": remaining,
        "status": status,
        "peak_days": peak,
        "peak_date": peak_date.isoformat() if peak_date else None,
        "ever_exceeds": peak > LIMIT_DAYS,
    }
