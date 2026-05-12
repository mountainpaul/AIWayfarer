from app.services.claude import parse_chat_response


FULL_RESPONSE = """\
<draft>
First-pass answer.
</draft>

<critique>
1. Geography ok.
2. Transport verified.
</critique>

<confidence>high</confidence>

<answer>
Final answer.
</answer>

<sources>
- source A
* source B
• source C
</sources>
"""


def test_parses_all_tags():
    r = parse_chat_response(FULL_RESPONSE)
    assert r.draft == "First-pass answer."
    assert "Geography" in r.critique
    assert r.confidence == "high"
    assert r.answer == "Final answer."
    assert r.sources == ["source A", "source B", "source C"]
    assert len(r.iterations) == 2


def test_missing_tags_falls_back_to_raw_text_as_answer():
    r = parse_chat_response("just a plain string with no tags")
    assert r.answer == "just a plain string with no tags"
    assert r.confidence == "medium"
    assert r.draft == r.answer
    assert r.critique == ""
    assert r.sources == []
    assert r.iterations == []


def test_invalid_confidence_value_defaults_to_medium():
    raw = "<answer>x</answer><confidence>extreme</confidence>"
    r = parse_chat_response(raw)
    assert r.confidence == "medium"


def test_low_confidence_passes_through():
    raw = "<answer>maybe</answer><confidence>low</confidence>"
    r = parse_chat_response(raw)
    assert r.confidence == "low"


def test_empty_sources_block_yields_empty_list():
    raw = "<answer>x</answer><sources>\n\n</sources>"
    r = parse_chat_response(raw)
    assert r.sources == []


def test_partial_response_with_only_draft():
    raw = "<draft>thinking out loud</draft>"
    r = parse_chat_response(raw)
    assert r.draft == "thinking out loud"
    # answer falls back to raw text
    assert "thinking" in r.answer
    assert len(r.iterations) >= 1
