"""Budget rollup: planned (leg budgets) vs actual (booking costs).

Money is integer cents. Legs and bookings each carry their own currency, so we
group planned and actual by currency rather than fabricating FX conversion —
the totals are only summed within a single currency.
"""


def report(legs: list[dict], bookings: list[dict]) -> dict:
    planned: dict[str, int] = {}
    for leg in legs:
        if leg.get("deleted_at") or leg.get("budget_cents") is None:
            continue
        cur = leg.get("currency") or "USD"
        planned[cur] = planned.get(cur, 0) + leg["budget_cents"]

    actual: dict[str, int] = {}
    for b in bookings:
        if b.get("deleted_at") or b.get("cost_cents") is None:
            continue
        cur = b.get("currency") or "USD"
        actual[cur] = actual.get(cur, 0) + b["cost_cents"]

    rows = []
    for cur in sorted(set(planned) | set(actual)):
        p = planned.get(cur, 0)
        a = actual.get(cur, 0)
        rows.append({
            "currency": cur,
            "planned_cents": p,
            "actual_cents": a,
            "remaining_cents": p - a,
        })
    return {"by_currency": rows}
