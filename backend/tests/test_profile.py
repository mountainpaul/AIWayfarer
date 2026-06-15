"""Traveler-profile feature (Step 1 + Step 2 backend):
- /api/v1/profile GET (auto-create singleton) + PATCH (partial, JSON blob)
- repository singleton/JSON semantics
- distilled summary injection into the chat system prompt
- uuidv7 ids
"""
import sqlite3
import uuid
from unittest.mock import patch

from fastapi.testclient import TestClient

from app import config
from app.main import app
from app.services import claude as claude_svc
from app.services import critic as critic_svc
from app.services import grounding as grounding_svc
from app.services.changelog import ENTITY_TABLE
from app.services.ids import uuidv7
from app.repositories.traveler_profile_repository import (
    DEFAULT_USER_ID,
    TravelerProfileRepository,
)

client = TestClient(app)

# Minimal isolated DB for repository unit tests (avoids the shared singleton in
# the session DB that the API tests mutate). Only the two tables the repo touches.
_CHANGE_DDL = """
CREATE TABLE change (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    change_id TEXT NOT NULL UNIQUE,
    entity TEXT NOT NULL, entity_id TEXT NOT NULL, op TEXT NOT NULL,
    patch TEXT, undoes TEXT, device TEXT, client_ts TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
"""


def _mem_db() -> sqlite3.Connection:
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.executescript(
        (config.MIGRATIONS_DIR / "0007_traveler_profile.sql").read_text()
    )
    con.executescript(_CHANGE_DDL)
    return con


# ── API: GET creates the singleton ────────────────────────────────
def test_get_profile_auto_creates_singleton():
    r = client.get("/api/v1/profile")
    assert r.status_code == 200
    p = r.json()
    assert p["user_id"] == DEFAULT_USER_ID
    assert uuid.UUID(p["id"]).version == 7
    assert isinstance(p["preferences_blob"], dict)


def test_get_profile_is_idempotent():
    first = client.get("/api/v1/profile").json()
    second = client.get("/api/v1/profile").json()
    assert first["id"] == second["id"]  # same row, never duplicated


# ── API: PATCH typed columns + JSON sandbox ───────────────────────
def test_patch_updates_columns_and_blob_roundtrips():
    patch_body = {
        "lodging_style": "boutique",
        "travel_pace": "relaxed",
        "budget_tier": "mid_range",
        "preferences_blob": {"interests": ["food", "trains"], "avoids": ["5am flights"]},
    }
    r = client.patch("/api/v1/profile", json=patch_body)
    assert r.status_code == 200
    p = r.json()
    assert p["lodging_style"] == "boutique"
    assert p["preferences_blob"]["interests"] == ["food", "trains"]
    # persisted, not just echoed
    assert client.get("/api/v1/profile").json()["preferences_blob"]["avoids"] == ["5am flights"]


def test_patch_is_partial():
    client.patch("/api/v1/profile", json={"lodging_style": "hostel"})
    client.patch("/api/v1/profile", json={"travel_pace": "packed"})
    p = client.get("/api/v1/profile").json()
    assert p["lodging_style"] == "hostel"  # untouched by the second patch
    assert p["travel_pace"] == "packed"


# ── Chat injection ────────────────────────────────────────────────
def test_summary_injected_into_chat_system_prompt():
    client.patch("/api/v1/profile", json={"profile_summary": "Paul loves slow train travel."})
    captured = {}

    def _capture(system_prompt, user_message, **kw):
        captured["system"] = system_prompt
        return "<answer>ok</answer>"

    with patch.object(claude_svc, "call_chat", side_effect=_capture):
        r = client.post("/api/v1/chat", json={"message": "hi", "mode": "planning"})
        assert r.status_code == 200
    assert "Traveler profile" in captured["system"]
    assert "slow train travel" in captured["system"]


def test_blank_summary_omits_profile_block():
    client.patch("/api/v1/profile", json={"profile_summary": "   "})
    captured = {}

    def _capture(system_prompt, user_message, **kw):
        captured["system"] = system_prompt
        return "<answer>ok</answer>"

    with patch.object(claude_svc, "call_chat", side_effect=_capture):
        client.post("/api/v1/chat", json={"message": "hi"})
    assert "Traveler profile" not in captured["system"]


# ── critic unit: section is conditional ───────────────────────────
def test_build_system_prompt_profile_section_conditional():
    without = critic_svc.build_system_prompt("GROUND", "planning")
    with_ = critic_svc.build_system_prompt("GROUND", "planning", profile_summary="Likes trains.")
    assert "Traveler profile" not in without
    assert "Traveler profile" in with_ and "Likes trains." in with_


# ── repository units (isolated in-memory DB) ──────────────────────
def test_ensure_is_idempotent_and_blob_defaults_empty():
    db = _mem_db()
    repo = TravelerProfileRepository(db)
    p1 = repo.ensure()
    p2 = repo.ensure()
    assert p1["id"] == p2["id"]
    assert p1["preferences_blob"] == {}
    assert uuid.UUID(p1["id"]).version == 7


def test_summary_for_returns_none_when_blank():
    db = _mem_db()
    repo = TravelerProfileRepository(db)
    repo.ensure()
    assert repo.summary_for() is None
    repo.update_for_user({"profile_summary": "  "})
    assert repo.summary_for() is None
    repo.update_for_user({"profile_summary": "Prefers boutique stays."})
    assert repo.summary_for() == "Prefers boutique stays."


def test_blob_serialized_as_json_text_in_db():
    db = _mem_db()
    repo = TravelerProfileRepository(db)
    repo.update_for_user({"preferences_blob": {"interests": ["food"]}})
    raw = db.execute("SELECT preferences_blob FROM traveler_profile").fetchone()[0]
    assert isinstance(raw, str) and '"interests"' in raw  # stored as TEXT JSON


def test_grounding_summary_helper_reads_repo():
    db = _mem_db()
    TravelerProfileRepository(db).update_for_user(
        {"profile_summary": "Avoids early flights."}
    )
    assert grounding_svc.traveler_profile_summary(db) == "Avoids early flights."


# ── misc ──────────────────────────────────────────────────────────
def test_changelog_knows_traveler_profile_entity():
    assert ENTITY_TABLE.get("traveler_profile") == "traveler_profile"


def test_uuidv7_version_and_uniqueness():
    ids = [uuidv7() for _ in range(200)]
    assert all(uuid.UUID(x).version == 7 for x in ids)
    assert len(set(ids)) == len(ids)
