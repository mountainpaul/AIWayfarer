import sqlite3
from unittest.mock import patch

from fastapi.testclient import TestClient

from app import config
from app.main import app
from app.services import briefing as briefing_svc
from app.services import claude as claude_svc

client = TestClient(app)


def _conn() -> sqlite3.Connection:
    c = sqlite3.connect(config.DB_PATH)
    c.row_factory = sqlite3.Row
    return c


# ── Service-level tests (deterministic markdown) ──────────────────────────


def test_generate_briefing_includes_leg_and_bookings():
    md = briefing_svc.generate_briefing(_conn(), "2026-04-15")
    assert "# Briefing" in md
    assert "Sicily" in md
    assert "## Today" in md or "## Tomorrow" in md
    assert "## Weather" in md


def test_generate_briefing_between_legs():
    # 2026-03-01 is before the trip starts.
    md = briefing_svc.generate_briefing(_conn(), "2026-03-01")
    assert "Between legs" in md


def test_generate_briefing_lists_open_tasks():
    md = briefing_svc.generate_briefing(_conn(), "2026-04-15")
    assert "Open tasks" in md


def test_generate_briefing_handles_invalid_date():
    md = briefing_svc.generate_briefing(_conn(), "not-a-date")
    # Should fall back to today rather than crash.
    assert "# Briefing" in md


# ── Endpoint-level tests ───────────────────────────────────────────────────


def test_briefing_today_returns_404_when_none_exists():
    # Wipe any briefings created by other tests in this run.
    c = _conn()
    c.execute("DELETE FROM briefing")
    c.commit()
    c.close()

    r = client.get("/api/v1/briefing/today")
    assert r.status_code == 404


def test_briefing_generate_falls_back_when_anthropic_unavailable():
    def _raise(*a, **kw):
        raise claude_svc.ClaudeUnavailableError("no key")

    with patch.object(claude_svc, "call_simple", side_effect=_raise):
        r = client.post("/api/v1/briefing/generate", json={"date": "2026-04-15"})
        assert r.status_code == 200
        body = r.json()
        assert body["date"] == "2026-04-15"
        assert "# Briefing" in body["markdown"]


def test_briefing_generate_uses_claude_rephrasing_when_available():
    with patch.object(claude_svc, "call_simple", return_value="# Rephrased\n- bullet"):
        r = client.post("/api/v1/briefing/generate", json={"date": "2026-04-16"})
        assert r.status_code == 200
        assert r.json()["markdown"] == "# Rephrased\n- bullet"


def test_briefing_generate_is_idempotent_on_same_date():
    client.post("/api/v1/briefing/generate", json={"date": "2026-04-17"})
    r2 = client.post("/api/v1/briefing/generate", json={"date": "2026-04-17"})
    assert r2.status_code == 200
    rows = _conn().execute(
        "SELECT COUNT(*) AS n FROM briefing WHERE date = ?", ("2026-04-17",)
    ).fetchone()
    assert rows["n"] == 1


def test_briefing_today_returns_json_briefing():
    client.post("/api/v1/briefing/generate", json={"date": "2026-04-18"})
    r = client.get("/api/v1/briefing/today")
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("application/json")
    body = r.json()
    # The Flutter client parses this into a Briefing (needs id/date/markdown).
    assert body["date"]
    assert body["id"]
    assert len(body["markdown"]) > 20, "briefing should have meaningful content"
