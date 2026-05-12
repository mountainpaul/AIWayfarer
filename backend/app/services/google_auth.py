"""
Google OAuth 2.0 credentials loader for the backend.

This module is the *runtime* side: it loads the previously-authenticated token
from disk and refreshes the access token automatically when it expires. The
*one-time* device flow that produces that token lives in `scripts/google_auth.py`.

Storage layout (all paths overridable via env vars):
    backend/secrets/client_secret.json   ← downloaded from Google Cloud Console
    backend/secrets/google_token.json    ← written by scripts/google_auth.py

Both files are gitignored.
"""

from __future__ import annotations

import os
import threading
from pathlib import Path
from typing import Optional

from google.auth.exceptions import RefreshError
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials

from .. import config


# Read-only scopes — spec §6 says Calendar/Gmail are read-only in v0.5.
SCOPES = [
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/gmail.readonly",
]


class GoogleNotConfiguredError(RuntimeError):
    """Raised when no Google token is available — the user hasn't run the helper yet."""


def _secrets_dir() -> Path:
    return Path(os.getenv("GOOGLE_SECRETS_DIR", str(config.BACKEND_DIR / "secrets")))


def client_secret_path() -> Path:
    return _secrets_dir() / "client_secret.json"


def token_path() -> Path:
    return _secrets_dir() / "google_token.json"


_creds: Optional[Credentials] = None
_lock = threading.Lock()


def get_credentials() -> Credentials:
    """
    Return a valid (refreshed if needed) Credentials object. Cached process-wide.

    Raises GoogleNotConfiguredError if no token file exists yet — caller should
    surface a 503 with instructions to run the auth helper.
    """
    global _creds
    with _lock:
        if _creds is None:
            tok = token_path()
            if not tok.exists():
                raise GoogleNotConfiguredError(
                    f"Google token not found at {tok}. "
                    "Run `python scripts/google_auth.py` from backend/ to authenticate."
                )
            _creds = Credentials.from_authorized_user_file(str(tok), SCOPES)

        if not _creds.valid:
            if _creds.expired and _creds.refresh_token:
                try:
                    _creds.refresh(Request())
                    # Persist refreshed token (new access_token + expiry).
                    token_path().write_text(_creds.to_json())
                except RefreshError as e:
                    raise GoogleNotConfiguredError(
                        f"Failed to refresh Google token: {e}. "
                        "Re-run `python scripts/google_auth.py`."
                    ) from e
            else:
                raise GoogleNotConfiguredError(
                    "Google credentials present but invalid and not refreshable. "
                    "Re-run `python scripts/google_auth.py`."
                )

        return _creds


def reset_cache() -> None:
    """Test hook: clear the cached credentials so a fresh load happens."""
    global _creds
    with _lock:
        _creds = None
