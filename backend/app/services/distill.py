"""Fold a submitted post-trip review into traveler_profile.profile_summary.

Closes the loop with Step 1: the distilled paragraph is what the chat grounding
layer injects (services/grounding.traveler_profile_summary). Revealed
preferences — what Paul actually rated high/low — refine the stated
questionnaire prefs. Runs once per review submission (a cheap, batched Claude
call) and degrades gracefully to leaving the summary unchanged if Claude is
unavailable, so the structured review is still saved.
"""
import sqlite3
from typing import Optional

from . import claude as claude_svc
from ..repositories.traveler_profile_repository import TravelerProfileRepository

_SYSTEM = (
    "You maintain Paul's traveler profile — a single concise paragraph "
    "(<=120 words) capturing his durable travel preferences, used to ground "
    "future trip planning. Update the existing summary by folding in what the "
    "new post-trip review reveals. Revealed preferences (what he actually rated "
    "high or low) outweigh stated ones when they conflict. Keep it specific and "
    "factual. Output ONLY the updated paragraph — no preamble, no headings."
)


def _review_to_text(review: dict, items: list[dict]) -> str:
    lines = [f"Overall rating: {review.get('overall_rating')}/5"]
    for key, label in (
        ("pace_feedback", "Pace"),
        ("highlight", "Highlight"),
        ("lowlight", "Lowlight"),
        ("free_text", "Notes"),
    ):
        if review.get(key):
            lines.append(f"{label}: {review[key]}")
    for it in items:
        bits = [
            f"- [{it.get('subject_type')}] {it.get('subject_label')}: "
            f"{it.get('rating')}/5"
        ]
        if it.get("liked"):
            bits.append(f"liked: {it['liked']}")
        if it.get("disliked"):
            bits.append(f"disliked: {it['disliked']}")
        lines.append(" — ".join(bits))
    return "\n".join(lines)


def distill_from_review(
    db: sqlite3.Connection, review: dict, items: list[dict]
) -> Optional[str]:
    """Regenerate profile_summary from the current profile + this review.

    Returns the new summary, or None if Claude was unavailable / produced
    nothing (in which case the existing summary is left untouched)."""
    repo = TravelerProfileRepository(db)
    profile = repo.ensure()
    current = (profile.get("profile_summary") or "").strip() or "(no summary yet)"
    stated = {
        k: profile.get(k)
        for k in ("lodging_style", "transport_preference", "travel_pace", "budget_tier")
    }
    user = (
        f"Current summary:\n{current}\n\n"
        f"Stated preferences: {stated}\n\n"
        f"New post-trip review:\n{_review_to_text(review, items)}"
    )
    try:
        updated = claude_svc.call_simple(_SYSTEM, user, max_tokens=400).strip()
    except claude_svc.ClaudeUnavailableError:
        return None
    except Exception:
        return None
    if not updated:
        return None
    repo.update_for_user({"profile_summary": updated})
    return updated
