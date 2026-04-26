# Wayfarer v1 — Design Spec

**Author:** Paul (with Claude)
**Date:** April 21, 2026
**Status:** Final draft — ready for implementation

---

## 1. What Wayfarer is

Wayfarer is a travel planning and live-companion app. One app, two modes:

- **Planning mode** — pre-trip itinerary building, bookings research, accommodation search, multi-leg logistics. (The original Wayfarer concept.)
- **Companion mode** — during-trip reasoning partner: answers questions, navigates, journals, flags broken plans, generates voice tours. Replaces ad-hoc Claude chat sessions that lose context when artifacts die.

Same Flutter app, same FastAPI backend, shared database. Mode is just a UI state.

## 2. The core problem it solves

Claude chat currently fails Paul in four ways:
1. **Confidently wrong first answers** (Sicily clockwise routing).
2. **Flip-flopping under pressure** (Barcelona Sants vs. Nord — four contradictory answers in five turns).
3. **State drift** (loses track of day/place/phase mid-conversation).
4. **Orphaned artifacts** (Trip HQ stuck in a dead chat when conversation fills up).

Wayfarer fixes all four by (a) separating answer-generation from verification, (b) grounding every response in GPS + clock + trip state, (c) owning persistent storage the user controls.

## 3. Architecture

### 3.1 Multi-agent pipeline (adapted from original Wayfarer design)

Every user query flows through a **plan → research → critique → present** pipeline:

```
User query
    ↓
[Grounding layer] ← GPS, system clock, Trip HQ state, calendar
    ↓
[Planner] (Opus)      — Decomposes query, decides what tools to call
    ↓
[Researchers] (Sonnet, parallel) — Web search, Reddit, Maps, Gmail, Calendar, Trip HQ DB
    ↓
[Draft answer] (Sonnet) — Synthesizes researcher outputs
    ↓
[Critic] (Opus, separate context) — Runs explicit checks (see §3.3)
    ↓
[Revised answer] — Draft + critic's corrections
    ↓
[Presenter] — Formats for text or voice output
```

**Why separate contexts matter:** a critic sharing context with the drafter tends to rubber-stamp. The critic gets the query + the draft + tool results, not the drafter's reasoning.

### 3.2 v0.5 simplification (ship faster)

For v0.5, collapse to a single Claude call with a strong verification prompt, but keep the grounding layer and critic-style checks inline. Full multi-agent pipeline lands in v1.0.

### 3.3 Critic's explicit checklist

Every draft answer is run against these six checks before shown to Paul:

1. **Geography/routing sanity** — does the route physically flow? No backtracking, no impossible connections.
2. **Transport verification** — are schedules, station names, and operators confirmed against primary sources (operator websites), not just Google summary cards?
3. **Date/time arithmetic** — is "tomorrow" the right day of week? Is this before/after Paul's check-in?
4. **Cross-source agreement** — do Google, the operator site, Reddit, and Paul's calendar agree? If not, flag the conflict explicitly.
5. **Opening hours / seasonal closures / strikes / weather** — is the place actually open when Paul plans to go?
6. **Logical consistency with prior decisions** — does this answer contradict a booking Paul already has?

A Reddit sanity check (r/travel, r/solotravel, country-specific subs) runs in parallel for transport and lodging queries — this is where real-world quirks live.

### 3.4 Confidence handling

- **High confidence:** show answer normally, with sources.
- **Medium:** show answer + flagged uncertainties.
- **Low (conflicting sources, can't verify):** **ask a clarifying question instead of guessing.** This is the single most valuable behavior change from baseline Claude.

### 3.5 Presentation modes

- **Default:** show the iteration. Draft → critic found issues → revised answer. Builds Paul's trust calibration.
- **Quiet mode (one-tap toggle):** silent iteration, only the final answer, with an expandable "show reasoning" section.
- **Voice mode:** short spoken answer; full reasoning available on screen.

## 4. Grounding layer

Every query is answered *against a known state*:

- **GPS** (phone sensor) — where Paul is right now.
- **System clock + timezone** — what time it is, what day of the week.
- **Trip HQ state** (DB) — what leg Paul is on, what's booked, what's next.
- **Calendar** (Google Calendar read) — appointments, check-ins.

These are cross-checked. If GPS says Catania but calendar says Syracuse, Wayfarer **notices the conflict and asks**, doesn't pick silently. This is the single fix for the "what day is it / where am I" drift.

## 5. Data sources (read)

| Source | Purpose | v0.5 | v1.0 |
|---|---|---|---|
| Google Calendar | Bookings, appointments | ✅ | ✅ |
| Gmail | Booking confirmations, tickets | ✅ | ✅ |
| Trip HQ DB | Itinerary, tasks, packing, budget | ✅ | ✅ |
| Web search + fetch | Schedules, hours, prices | ✅ | ✅ |
| Reddit | Transport/lodging sanity checks | — | ✅ |
| Google Maps / Rome2Rio | Routing, transit times | — | ✅ |
| Phone sensors | GPS, clock, timezone | ✅ | ✅ |
| Photos | Visual Q&A | — | deferred to v1.1+ |

## 6. Write access

| Action | Autonomy |
|---|---|
| Add/complete tasks, tick packing items, journal entries | **Autonomous** |
| Append to journal (narrative notes) | **Autonomous** |
| Edit Trip HQ bookings, itinerary | **Approval-gated** |
| Write to Google Calendar | **Approval-gated** |
| Draft emails/messages | **Draft only, never send** |
| Book anything (hotels, flights, ferries) | **Never autonomous** |

## 7. Storage architecture

Three layers, each with a clear job:

1. **SQLite on device + Postgres on droplet** (authoritative structured store): bookings, tasks, locations, dates, expenses, packing. Replaces Trip HQ's persistent-storage key. Queryable, editable, exportable, survives forever.
2. **Markdown/JSON journal files**: narrative and notes ("ate at Trattoria X, excellent carbonara"), trip reflections, voice-journaled entries. Sync from device to droplet.
3. **Vector index over journal + conversation history**: semantic recall for fuzzy queries ("remind me of that place in Ragusa with the view").

## 8. Voice interface

- **Default: push-to-talk.** Battery-friendly, predictable, privacy-preserving.
- **When charging: wake-word mode available.** Toggle in settings.
- **Bidirectional TTS** — responses spoken back on request.
- **STT:** device-native (Android SpeechRecognizer) with Whisper API fallback when online and quality matters.
- **TTS:** device-native default; higher-quality cloud TTS for voice tours.

**Voice use cases:**
- Quick lookups ("what time does the ferry leave")
- Navigation ("which way to the hotel")
- Journaling ("remember Trattoria Mimì was excellent")
- Real-time translation / phrasebook
- Complex planning ("rework tomorrow because the museum is closed")
- **Voice tours** — generated during planning (WiFi), cached to device, played back offline during the activity.

## 9. Proactive features

**Built-in, not chat-driven:**

- **Pre-trip briefing** — generated overnight, shown on wake. "Tomorrow Palermo → Agrigento. Bus 09:15 from Piazzale Cairoli. Check-in Il Melograno after 15:00. 22°C sunny. One open task: confirm Ksar Hadada." Addresses the "what day is it / where am I" drift directly.
- **Broken plan detection** — background job: ferry cancellations, strikes, weather for hiking days, venue closures on planned visit days, restaurant closed on reservation day. Proactive flagging beats reactive scrambling.
- **Offline primitives** — current leg's data (bookings, maps tiles, key references) cached to device from day one. Not a retrofit; it's in the data layer from v0.5.

## 10. Versions and timeline

### v0.5 — target late May 2026 (Dolomites leg)

- Text chat + push-to-talk voice (bidirectional TTS)
- Single-Claude with strong critic prompt (not full multi-agent yet)
- Grounding layer (GPS + clock + Trip HQ + Calendar)
- Six-point critic checklist
- Trip HQ CRUD (migrated from the React artifact so no data is orphaned)
- Calendar/Gmail read
- Pre-trip briefing (overnight generation, morning display)
- Offline cache of current-leg data (core primitive; retrofitting is painful)

**Ships the fix for the Barcelona and Sicily failures.** That alone is worth v0.5.

### v1.0 — target August 5, 2026 (JMT)

- Full multi-agent pipeline (Opus orchestrator + Sonnet workers + Opus critic, separate contexts)
- Reddit integration
- Maps + Rome2Rio
- Broken plan detection (background job)
- Voice tours — generation and offline playback
- Robust offline mode (JMT requirement — no cellular for 22 days)

### v1.1+ backlog (deferred, revisit after v0.5 ships)

- Photo Q&A (visual recognition)
- Expense tracking (voice-journaled; simple to add when needed)
- Two-way calendar sync
- Travel companion support (for Ireland 2026 with Kevin)
- Health/training log integration
- Receipt photo capture

## 11. Key tradeoffs

- **Always-verify default is slow.** Every answer incurs critic latency. Acceptable because the cost of a wrong answer (missed ferry, wrong station) is higher than a 5-second wait. Quiet mode available when Paul trusts a flow.
- **Multi-agent increases API cost.** Opus orchestrator + 2–3 Sonnet workers + Opus critic = ~4–6x single-call cost. Controlled via tiered query routing (§13) — only heavy queries trigger the full pipeline, and lighter tiers can use Gemini Flash where grounding and cost justify it. $50/month ceiling drives the discipline.
- **Multi-vendor means more integration surface.** Two vendors means two API clients, two auth flows, two failure modes to handle. Justified because the capability wins are real (Gemini's YouTube access, Google Search grounding) and the abstraction layer is thin — an LLM-agnostic client interface in the backend is ~a day of work.
- **Push-to-talk over wake word.** Loses hands-free convenience; gains battery life and privacy. Adaptive when charging.
- **SQLite + journal + vector is three storage systems.** More complexity than one database; justified because each one's job is different and forcing them into one shape makes all three worse.

## 12. Resolved decisions

1. **Hosting:** current 2GB DO droplet. Start here; upgrade only if v1.0 metrics force it.
2. **Auth:** single-user (Paul) for v1. Multi-user deferred with the rest of companion support.
3. **JMT offline:** skip local LLM fallback. Modern cellular coverage on JMT is better than commonly assumed; "mostly connected with robust caching for dead zones" is the target. Pre-generated voice tours and cached trail data cover the rest. Revisit post-JMT if reality differs.
4. **API budget:** $50/month ceiling. Reconsider at v1.0 review. Drives the tiered-routing architecture in §13.

## 13. Cost control: tiered query routing

To keep monthly spend under $50, not every query gets the full multi-agent pipeline. The planner classifies incoming queries and routes to the best model for the job — not locked to a single vendor.

| Tier | Query type | Routing | Approx cost |
|---|---|---|---|
| **Light** | Simple lookups ("what's my hotel tonight"), real-time factual queries with Google grounding ("ferry schedule today") | DB query + Haiku or Gemini Flash single-call | cents |
| **Medium** | Transport/lodging verification, factual queries needing multi-source checking | Sonnet + critic (v0.5 style) | ~$0.05 |
| **Heavy** | Routing sanity, multi-leg logistics, "rework my week because X" | Full Opus multi-agent pipeline | ~$0.30–0.50 |
| **Video** | "Summarize this YouTube trail video", "what does this van tour show" | Gemini (native YouTube access) | varies |

**Model selection rationale:**
- **Claude Opus/Sonnet** for reasoning, verification, multi-step logic — where the Sicily/Barcelona failures happened. This is Claude's strength.
- **Gemini Flash** for light queries where Google Search grounding adds value (opening hours, live schedules) and cost matters.
- **Gemini Pro** for YouTube content understanding (trail videos, van tours, walking tours) — Claude doesn't have native YouTube access.
- **Reddit** is API-accessed directly, passed to whichever model is reasoning. Not a model choice.

The critic still runs on medium and heavy tiers. Light tier skips the critic because DB lookups are already ground truth. This is the single most important cost lever.

**Additional cost levers (build in from v1.0):**

- **Prompt caching** — the long system prompt (critic checklist, trip state, grounding rules) is identical across queries within a session. Caching it cuts cost 50–90% on eligible input tokens.
- **Batch processing** — the overnight pre-trip briefing isn't time-sensitive. Running it through the batch API (50% discount) is free money.
- **Response caching** — identical queries within a short window (e.g., Paul asking "what's my hotel tonight" twice in an hour) should hit a local cache, not the API.

## 14. Next steps

1. Paul reviews this spec, flags final changes.
2. Move to Claude Code on MacBook for implementation.
3. v0.5 build plan: break into 2-week sprints.
   - **Sprint 1:** Trip HQ migration (extract data from React artifact → SQLite/Postgres schema) + basic Flutter shell.
   - **Sprint 2:** Grounding layer + critic prompt + text chat.
   - **Sprint 3:** Voice (push-to-talk + TTS) + Calendar/Gmail read.
   - **Sprint 4:** Pre-trip briefing + offline cache + polish for Dolomites dogfood.
