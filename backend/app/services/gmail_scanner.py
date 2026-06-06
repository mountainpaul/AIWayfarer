"""
Gmail booking scanner — fetches booking-related emails and uses Claude
to extract structured booking data.

Uses the same Google OAuth credentials as calendar.py.
"""

from __future__ import annotations

import base64
import html
import json
import logging
import re

from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

from . import google_auth
from .claude import call_chat

log = logging.getLogger(__name__)


# Mirror the Literal enums in models.py. LLM output is untrusted, so we coerce
# any out-of-set value to a safe default before it reaches the DB — a strict
# Pydantic read model would otherwise 500 the whole /bookings list on one bad row.
BOOKING_TYPES = {
    "flight", "hotel", "ferry", "car", "train", "activity", "rifugio", "other",
}
BOOKING_STATUSES = {"booked", "pending", "needs_booking", "researching"}


class GmailApiError(RuntimeError):
    pass


def _service():
    creds = google_auth.get_credentials()
    return build("gmail", "v1", credentials=creds, cache_discovery=False)


_BOOKING_QUERY = (
    "("
    "subject:(booking OR confirmation OR reservation OR ticket OR itinerary) "
    "(flight OR airline OR train OR trenitalia OR hotel OR hostel OR airbnb "
    "OR ferry OR rifugio OR apartment OR accommodation OR flixbus OR bus)"
    ") "
    "newer_than:{months}m"
)

_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"[ \t]*\n[ \t]*")


def _decode_b64(data: str) -> str:
    if not data:
        return ""
    return base64.urlsafe_b64decode(data).decode("utf-8", errors="replace")


def _html_to_text(raw_html: str) -> str:
    """Cheap HTML→text: drop script/style, strip tags, unescape entities."""
    if not raw_html:
        return ""
    no_scripts = re.sub(
        r"<(script|style)[^>]*>.*?</\1>", " ", raw_html, flags=re.DOTALL | re.IGNORECASE
    )
    text = _TAG_RE.sub(" ", no_scripts)
    text = html.unescape(text)
    # Collapse runs of blank lines/whitespace introduced by stripping.
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = _WS_RE.sub("\n", text)
    return text.strip()


def _walk_parts(payload: dict, mime: str) -> str:
    """Depth-first search for the first body of the given MIME type."""
    if payload.get("mimeType", "").startswith(mime):
        body = _decode_b64(payload.get("body", {}).get("data", ""))
        if body:
            return body
    for part in payload.get("parts", []):
        found = _walk_parts(part, mime)
        if found:
            return found
    return ""


def _get_message_body(msg: dict) -> str:
    """Prefer text/plain; fall back to stripped text/html (many emails are HTML-only)."""
    payload = msg.get("payload", {})
    plain = _walk_parts(payload, "text/plain")
    if plain:
        return plain
    return _html_to_text(_walk_parts(payload, "text/html"))


def _get_header(headers: list[dict], name: str) -> str:
    for h in headers:
        if h.get("name", "").lower() == name.lower():
            return h.get("value", "")
    return ""


def fetch_booking_emails(months: int = 6, max_results: int = 50) -> list[dict]:
    """Fetch booking-related emails from Gmail. Returns simplified email dicts."""
    query = _BOOKING_QUERY.format(months=months)

    try:
        svc = _service()
        resp = svc.users().messages().list(
            userId="me", q=query, maxResults=max_results
        ).execute()
    except HttpError as e:
        raise GmailApiError(f"Gmail API error: {e}") from e

    messages = resp.get("messages", [])
    if not messages:
        return []

    results = []
    for msg_ref in messages:
        try:
            msg = svc.users().messages().get(
                userId="me", id=msg_ref["id"], format="full"
            ).execute()

            headers = msg.get("payload", {}).get("headers", [])
            body = _get_message_body(msg)

            # Truncate body to avoid token bloat — snippets often suffice
            if len(body) > 1500:
                body = body[:1500] + "..."

            results.append({
                "id": msg_ref["id"],
                "subject": _get_header(headers, "Subject"),
                "sender": _get_header(headers, "From"),
                "date": _get_header(headers, "Date"),
                "snippet": msg.get("snippet", ""),
                "body": body,
            })
        except HttpError:
            continue

    return results


_PARSE_SYSTEM = """You are a booking extraction assistant. Given a list of emails,
extract structured booking information. Each booking should include:

- type: one of "flight", "hotel", "ferry", "car", "train", "activity", "rifugio", "other"
- name: a short descriptive name (e.g. "Trenitalia Napoli → Roma", "Hotel Villa Belvedere")
- status: "booked" (confirmed bookings)
- start_date: ISO date YYYY-MM-DD if available
- end_date: ISO date YYYY-MM-DD if available (for hotels: checkout date)
- confirmation: booking reference number if available
- location_name: city or location name
- cost_cents: cost in cents (e.g. 2350 for €23.50, or null if unknown). Convert EUR to cents.
- currency: "EUR", "USD", etc.
- notes: any extra relevant details (seat number, check-in time, etc.)

You will also be given a list of trip legs with date ranges. Match each booking to the
correct leg based on the booking's start_date falling within the leg's date range.

Rules:
- Skip duplicate emails (same booking appearing multiple times)
- Skip cancellation confirmations
- Skip marketing/promotional emails
- Skip security update emails
- For buses (FlixBus, MarinoBus), use type "other" with a note
- Be conservative: only extract bookings you're confident about
- Return valid JSON only, no markdown fences

Return a JSON array of objects with these fields:
{type, name, status, start_date, end_date, confirmation, location_name, cost_cents, currency, notes, leg_id}
"""


def _normalize_candidate(c: dict) -> dict:
    """Coerce LLM output to safe enum values so it can't corrupt the bookings table."""
    t = str(c.get("type") or "other").lower()
    c["type"] = t if t in BOOKING_TYPES else "other"
    s = str(c.get("status") or "booked").lower()
    c["status"] = s if s in BOOKING_STATUSES else "booked"
    return c


def parse_bookings_with_claude(
    emails: list[dict],
    legs: list[dict],
) -> list[dict]:
    """Use Claude to parse emails into structured booking candidates."""
    if not emails:
        return []

    # Build email summaries for Claude
    email_text = "\n\n---\n\n".join(
        f"Subject: {e['subject']}\nFrom: {e['sender']}\nDate: {e['date']}\n"
        f"Snippet: {e['snippet']}\n\nBody:\n{e['body']}"
        for e in emails
    )

    legs_text = "\n".join(
        f"- leg_id={lg['id']}, name={lg['name']}, "
        f"dates={lg['start_date']} to {lg['end_date']}"
        for lg in legs
    )

    user_msg = (
        f"## Trip Legs\n{legs_text}\n\n"
        f"## Emails ({len(emails)} total)\n\n{email_text}"
    )

    raw = call_chat(_PARSE_SYSTEM, user_msg, max_tokens=8192)

    # Strip markdown fences if present
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[1]
        if raw.endswith("```"):
            raw = raw[:-3]

    try:
        result = json.loads(raw)
    except json.JSONDecodeError:
        log.error("Failed to parse Claude response as JSON: %s", raw[:500])
        return []

    if not isinstance(result, list):
        return []
    return [_normalize_candidate(c) for c in result if isinstance(c, dict)]


def scan_and_parse(
    legs: list[dict],
    months: int = 6,
    max_emails: int = 30,
) -> list[dict]:
    """Full pipeline: fetch emails → parse with Claude → return candidates."""
    emails = fetch_booking_emails(months=months, max_results=max_emails)
    log.info("Fetched %d booking emails, sending to Claude for parsing", len(emails))
    return parse_bookings_with_claude(emails, legs)
