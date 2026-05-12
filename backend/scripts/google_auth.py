#!/usr/bin/env python3
"""
One-time Google OAuth flow for Wayfarer (Calendar + Gmail read-only).

Run this once from your laptop (must have a browser available):

    cd backend
    source .venv/bin/activate
    python scripts/google_auth.py

It opens your browser, you sign in to the Google account that owns the
trip data, approve the read-only Calendar + Gmail scopes, and the script
writes secrets/google_token.json. The backend's runtime auth loader picks
that up automatically — no env vars needed.

Re-run if the refresh token is revoked or scopes change.

Why loopback flow, not RFC 8628 device flow:
    Google's true device flow (the "enter this code on another device"
    one) only supports a small set of scopes. Calendar/Gmail go through
    the standard installed-app loopback redirect, which is the official
    recommendation for desktop apps. If you're authenticating on a
    headless droplet, run this on your laptop, then copy the resulting
    google_token.json to the droplet — refresh tokens are portable.
"""

import argparse
import sys
from pathlib import Path

from google_auth_oauthlib.flow import InstalledAppFlow

# Add backend/ to sys.path so we can import app.services.google_auth
SCRIPT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = SCRIPT_DIR.parent
sys.path.insert(0, str(BACKEND_DIR))

from app.services.google_auth import (  # noqa: E402
    SCOPES,
    client_secret_path,
    token_path,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--port",
        type=int,
        default=0,
        help="Local loopback port (0 = pick an open one)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing google_token.json without confirmation",
    )
    args = parser.parse_args()

    cs_path = client_secret_path()
    tok_path = token_path()
    tok_path.parent.mkdir(parents=True, exist_ok=True)

    if not cs_path.exists():
        print(f"ERROR: client_secret.json not found at {cs_path}")
        print("Download it from Google Cloud Console:")
        print("  APIs & Services -> Credentials -> Create OAuth Client ID")
        print("  -> Desktop app -> Download JSON")
        return 1

    if tok_path.exists() and not args.force:
        ans = input(
            f"Token already exists at {tok_path}. Overwrite? [y/N] "
        ).strip().lower()
        if ans != "y":
            print("Aborted.")
            return 0

    flow = InstalledAppFlow.from_client_secrets_file(str(cs_path), SCOPES)
    creds = flow.run_local_server(
        port=args.port,
        prompt="consent",
        access_type="offline",
    )

    tok_path.write_text(creds.to_json())
    # Tighten permissions on the token file (best-effort).
    try:
        tok_path.chmod(0o600)
    except OSError:
        pass

    print(f"\nOK — wrote {tok_path}")
    print(f"Scopes granted: {SCOPES}")
    if creds.refresh_token:
        print("Refresh token captured (long-lived).")
    else:
        print(
            "WARNING: no refresh_token returned. "
            "If access expires you'll need to re-run this. "
            "Check that you used --force / fresh consent screen."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
