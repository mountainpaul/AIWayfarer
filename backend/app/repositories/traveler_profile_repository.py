"""TravelerProfileRepository — persistent traveler-preference store.

Single-user for v1 (one row, user_id = DEFAULT_USER_ID), but shaped for
multi-user later: access is by user_id, not a path id. Stable preferences live
in typed columns; the evolving questionnaire/tags/avoids live in the JSON
`preferences_blob` sandbox; `profile_summary` holds the distilled paragraph the
chat grounding layer injects.

Raw SQL stays here (BEST_PRACTICES.md §2.1) — routers only call these methods.
"""
import json
import sqlite3
from typing import Optional

from ..services.ids import uuidv7
from .base import BaseRepository

#: single-user v1 — every row belongs to Paul until multi-user lands.
DEFAULT_USER_ID = "paul"


class TravelerProfileRepository(BaseRepository):
    table = "traveler_profile"
    entity = "traveler_profile"
    #: stored as a JSON TEXT column, exposed to the API as a dict
    json_columns: tuple[str, ...] = ("preferences_blob",)

    # ── JSON (de)serialization for the sandbox blob ───────────────
    def _encode(self, data: dict) -> dict:
        out = super()._encode(data)
        for k in self.json_columns:
            if k in out and not isinstance(out[k], str):
                out[k] = json.dumps(out[k] if out[k] is not None else {})
        return out

    def _decode(self, row: Optional[dict]) -> Optional[dict]:
        if row is None:
            return None
        out = dict(row)
        for k in self.json_columns:
            raw = out.get(k)
            out[k] = json.loads(raw) if isinstance(raw, str) and raw else {}
        return out

    # Override the read paths so callers (and create()/update(), which return
    # via get()) always receive the blob decoded.
    def get(self, entity_id: str, *, include_deleted: bool = False) -> Optional[dict]:
        return self._decode(super().get(entity_id, include_deleted=include_deleted))

    def list(self, *args, **kwargs) -> list[dict]:
        return [self._decode(r) for r in super().list(*args, **kwargs)]  # type: ignore[misc]

    # ── single-user singleton access ──────────────────────────────
    def for_user(self, user_id: str = DEFAULT_USER_ID) -> Optional[dict]:
        rows = self.list(filters={"user_id": user_id}, limit=1)
        return rows[0] if rows else None

    def ensure(self, user_id: str = DEFAULT_USER_ID) -> dict:
        """Return the user's profile, creating an empty one on first access."""
        existing = self.for_user(user_id)
        if existing is not None:
            return existing
        return self.create(
            {"user_id": user_id, "preferences_blob": {}},
            entity_id=uuidv7(),
        )

    def update_for_user(self, patch: dict, user_id: str = DEFAULT_USER_ID) -> dict:
        """Patch the singleton profile (creating it first if absent)."""
        profile = self.ensure(user_id)
        return self.update(profile["id"], patch)  # type: ignore[return-value]

    def summary_for(self, user_id: str = DEFAULT_USER_ID) -> Optional[str]:
        """Just the distilled paragraph — the cheap read the grounding layer needs."""
        profile = self.for_user(user_id)
        if not profile:
            return None
        summary = (profile.get("profile_summary") or "").strip()
        return summary or None
