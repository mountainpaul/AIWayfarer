"""
Anthropic SDK wrapper. Sync client. Prompt caching on the system prompt.

For v0.5 we collapse plan→research→critique→present into a single Claude call
with a strong critic-style system prompt (spec §3.2). The full multi-agent
pipeline lands in v1.0.
"""

import re
from typing import Optional

import anthropic

from .. import config
from ..models import ChatResponse, Confidence


class ClaudeUnavailableError(RuntimeError):
    pass


_client: Optional[anthropic.Anthropic] = None


def get_client() -> anthropic.Anthropic:
    global _client
    if not config.ANTHROPIC_API_KEY:
        raise ClaudeUnavailableError(
            "ANTHROPIC_API_KEY is not set. Set it in backend/.env to enable /chat and /briefing/generate."
        )
    if _client is None:
        _client = anthropic.Anthropic(api_key=config.ANTHROPIC_API_KEY)
    return _client


_TAG_PATTERNS = {
    "draft": re.compile(r"<draft>\s*(.*?)\s*</draft>", re.DOTALL | re.IGNORECASE),
    "critique": re.compile(r"<critique>\s*(.*?)\s*</critique>", re.DOTALL | re.IGNORECASE),
    "confidence": re.compile(r"<confidence>\s*(high|medium|low)\s*</confidence>", re.IGNORECASE),
    "answer": re.compile(r"<answer>\s*(.*?)\s*</answer>", re.DOTALL | re.IGNORECASE),
    "sources": re.compile(r"<sources>\s*(.*?)\s*</sources>", re.DOTALL | re.IGNORECASE),
}


def parse_chat_response(raw: str) -> ChatResponse:
    """Parse the structured response. If tags are missing, fall back to using the whole text as the answer."""
    def _grab(key: str) -> str:
        m = _TAG_PATTERNS[key].search(raw)
        return m.group(1).strip() if m else ""

    draft = _grab("draft")
    critique = _grab("critique")
    answer = _grab("answer") or raw.strip()
    confidence_raw = _grab("confidence").lower()
    confidence: Confidence = confidence_raw if confidence_raw in ("high", "medium", "low") else "medium"  # type: ignore

    sources_block = _grab("sources")
    sources: list[str] = []
    if sources_block:
        for line in sources_block.splitlines():
            line = line.strip().lstrip("-*•").strip()
            if line:
                sources.append(line)

    iterations: list[dict] = []
    if draft:
        iterations.append({"label": "draft", "content": draft})
    if critique:
        iterations.append({"label": "critique", "content": critique})

    return ChatResponse(
        answer=answer,
        draft=draft or answer,
        critique=critique,
        confidence=confidence,
        sources=sources,
        iterations=iterations,
    )


def call_chat(system_prompt: str, user_message: str, max_tokens: int = 4096) -> str:
    """Single-turn call with prompt caching on the system prompt."""
    client = get_client()
    response = client.messages.create(
        model=config.ANTHROPIC_MODEL,
        max_tokens=max_tokens,
        system=[{"type": "text", "text": system_prompt, "cache_control": {"type": "ephemeral"}}],
        messages=[{"role": "user", "content": user_message}],
    )
    parts = [b.text for b in response.content if getattr(b, "type", None) == "text"]
    return "\n".join(parts).strip()


def call_simple(system_prompt: str, user_message: str, max_tokens: int = 2048) -> str:
    """Plain text response, no structured parsing — used by the briefing generator."""
    return call_chat(system_prompt, user_message, max_tokens=max_tokens)
