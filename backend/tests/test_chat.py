from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app
from app.services import claude as claude_svc

client = TestClient(app)


MOCK_RESPONSE = """\
<draft>
The ferry from Pozzallo to Valletta runs daily at 17:00.
</draft>

<critique>
1. Geography: Pozzallo → Valletta is the standard southern crossing — valid.
2. Transport verification: confirmed against Virtu Ferries primary site.
3. Date arithmetic: trip date is on a Saturday — service runs Saturdays.
4. Cross-source agreement: Google and Virtu Ferries agree.
5. Opening hours: ferry operates year-round.
6. No conflict with prior bookings.
</critique>

<confidence>high</confidence>

<answer>
Take the Virtu Ferries crossing Pozzallo → Valletta at 17:00. Catamaran, ~1h45m.
</answer>

<sources>
- Virtu Ferries official schedule
- Trip HQ booking record
</sources>
"""


def test_chat_parses_structured_response():
    with patch.object(claude_svc, "call_chat", return_value=MOCK_RESPONSE):
        r = client.post(
            "/api/v1/chat",
            json={"message": "When does the ferry leave?", "mode": "companion"},
        )
        assert r.status_code == 200
        body = r.json()
        assert body["confidence"] == "high"
        assert "Virtu Ferries" in body["answer"]
        assert "Pozzallo" in body["draft"]
        assert len(body["sources"]) == 2
        assert "official schedule" in body["sources"][0]


def test_chat_returns_503_when_anthropic_unavailable():
    def _raise(*args, **kwargs):
        raise claude_svc.ClaudeUnavailableError("ANTHROPIC_API_KEY is not set.")

    with patch.object(claude_svc, "call_chat", side_effect=_raise):
        r = client.post("/api/v1/chat", json={"message": "hi"})
        assert r.status_code == 503
        assert "ANTHROPIC_API_KEY" in r.json()["message"]


def test_chat_rejects_empty_message():
    r = client.post("/api/v1/chat", json={"message": "   "})
    assert r.status_code == 400


def test_chat_falls_back_to_medium_confidence_on_unparseable_response():
    with patch.object(claude_svc, "call_chat", return_value="some unstructured reply"):
        r = client.post("/api/v1/chat", json={"message": "hi"})
        assert r.status_code == 200
        body = r.json()
        assert body["confidence"] == "medium"
        assert body["answer"] == "some unstructured reply"
