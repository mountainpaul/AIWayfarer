from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _sicily_leg_id() -> str:
    legs = client.get("/api/v1/legs").json()
    return next(l["id"] for l in legs if l["slug"] == "sicily")


def test_create_journal_entry_defaults_to_note():
    created = client.post("/api/v1/journal", json={
        "content": "Tested the carbonara at Trattoria Mimì",
        "leg_id": _sicily_leg_id(),
    }).json()
    try:
        assert created["entry_type"] == "note"
        assert "Mimì" in created["content"]
        assert created["leg_id"] == _sicily_leg_id()
    finally:
        # No DELETE endpoint per spec §6 (journal is append-only).
        # Tests stack, but cleanup happens via the temp-DB reset between pytest runs.
        pass


def test_create_journal_rejects_unknown_leg():
    r = client.post("/api/v1/journal", json={
        "leg_id": "00000000-0000-0000-0000-000000000000",
        "content": "ghost",
    })
    assert r.status_code == 400


def test_journal_list_returns_most_recent_first():
    a = client.post("/api/v1/journal", json={"content": "first"}).json()
    b = client.post("/api/v1/journal", json={"content": "second"}).json()
    listing = client.get("/api/v1/journal").json()
    ids = [e["id"] for e in listing]
    # b was created after a, so b should appear before a
    assert ids.index(b["id"]) < ids.index(a["id"])


def test_journal_list_respects_limit():
    for i in range(3):
        client.post("/api/v1/journal", json={"content": f"limit test {i}"})
    listing = client.get("/api/v1/journal?limit=2").json()
    assert len(listing) == 2


def test_journal_filter_by_leg():
    leg_id = _sicily_leg_id()
    client.post("/api/v1/journal", json={"leg_id": leg_id, "content": "scoped to sicily"})
    listing = client.get(f"/api/v1/journal?leg_id={leg_id}").json()
    assert all(e["leg_id"] == leg_id for e in listing)
