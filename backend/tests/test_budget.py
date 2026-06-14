"""Budget rollup — per-currency planned vs actual."""
from fastapi.testclient import TestClient

from app.main import app
from app.services import budget

client = TestClient(app)


def _leg(budget_cents, cur="USD", deleted=False):
    return {"budget_cents": budget_cents, "currency": cur,
            "deleted_at": "x" if deleted else None}


def _book(cost_cents, cur="USD", deleted=False):
    return {"cost_cents": cost_cents, "currency": cur,
            "deleted_at": "x" if deleted else None}


def _row(report, cur):
    return next(r for r in report["by_currency"] if r["currency"] == cur)


def test_planned_minus_actual():
    r = budget.report([_leg(100000)], [_book(30000), _book(20000)])
    usd = _row(r, "USD")
    assert usd["planned_cents"] == 100000
    assert usd["actual_cents"] == 50000
    assert usd["remaining_cents"] == 50000


def test_currencies_not_mixed():
    r = budget.report([_leg(100000, "USD"), _leg(50000, "EUR")],
                      [_book(40000, "EUR")])
    usd = _row(r, "USD")
    eur = _row(r, "EUR")
    assert usd["planned_cents"] == 100000 and usd["actual_cents"] == 0
    assert eur["planned_cents"] == 50000 and eur["actual_cents"] == 40000
    assert eur["remaining_cents"] == 10000


def test_nulls_and_deleted_ignored():
    r = budget.report(
        [_leg(100000), _leg(None), _leg(99999, deleted=True)],
        [_book(10000), _book(None), _book(99999, deleted=True)],
    )
    usd = _row(r, "USD")
    assert usd["planned_cents"] == 100000
    assert usd["actual_cents"] == 10000


def test_overspend_is_negative_remaining():
    r = budget.report([_leg(10000)], [_book(15000)])
    assert _row(r, "USD")["remaining_cents"] == -5000


def test_budget_endpoint_shape():
    r = client.get("/api/v1/budget")
    assert r.status_code == 200
    body = r.json()
    assert "by_currency" in body
    for line in body["by_currency"]:
        assert line["planned_cents"] - line["actual_cents"] == line["remaining_cents"]
