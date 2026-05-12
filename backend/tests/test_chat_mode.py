"""
T3: mode propagation test — the planning/companion toggle in the UI is only
meaningful if `mode` reaches build_system_prompt and changes the system text.
"""

from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app
from app.services import claude as claude_svc

client = TestClient(app)


_MOCK_REPLY = "<answer>ok</answer><confidence>high</confidence>"


def _capture_system_prompt():
    """Patch claude_svc.call_chat and capture the system prompt arg."""
    captured = {}

    def fake_call_chat(system_prompt, user_message, max_tokens=4096):
        captured["system"] = system_prompt
        captured["user"] = user_message
        return _MOCK_REPLY

    return captured, fake_call_chat


def test_planning_mode_reaches_system_prompt():
    captured, fake = _capture_system_prompt()
    with patch.object(claude_svc, "call_chat", side_effect=fake):
        r = client.post("/chat", json={"message": "what should I book", "mode": "planning"})
        assert r.status_code == 200
    assert "PLANNING" in captured["system"]
    assert "COMPANION" not in captured["system"].split("PLANNING", 1)[0]


def test_companion_mode_reaches_system_prompt():
    captured, fake = _capture_system_prompt()
    with patch.object(claude_svc, "call_chat", side_effect=fake):
        r = client.post("/chat", json={"message": "where am I", "mode": "companion"})
        assert r.status_code == 200
    assert "COMPANION" in captured["system"]


def test_default_mode_is_companion():
    captured, fake = _capture_system_prompt()
    with patch.object(claude_svc, "call_chat", side_effect=fake):
        r = client.post("/chat", json={"message": "no mode given"})
        assert r.status_code == 200
    assert "COMPANION" in captured["system"]


def test_iterations_use_label_content_keys():
    """T3-adjacent: the parser's iterations format must match the Flutter
    IterationStep model ({label, content}), not the older {role, text}."""
    raw = """\
<draft>thinking</draft>
<critique>checking</critique>
<answer>final</answer>
<confidence>high</confidence>
"""
    with patch.object(claude_svc, "call_chat", return_value=raw):
        body = client.post("/chat", json={"message": "x"}).json()
    assert body["iterations"]
    for step in body["iterations"]:
        assert "label" in step
        assert "content" in step
        assert "role" not in step
        assert "text" not in step
