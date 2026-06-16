# Modes, Personas, and Trip Intake — design notes

> Status: **discussion, not built.** Captured 2026-06-15 from a design chat.
> Revisit before implementing. Nothing here has been coded.

## The core problem

Today the app has one **mode toggle** (Planning ⇄ Companion) that secretly does
three different jobs at once:

1. **Grounding** — where Paul physically is (GPS + clock + current leg).
2. **Subject** — *what* he's working on (the current leg, a future leg, or a
   different trip entirely).
3. **Persona** — *how* the AI should behave (travel agent, tour guide, logistics
   co-pilot, neutral researcher).

Collapsing these into one switch creates two concrete pain points:

- **Planning while on a trip.** Paul is often physically on a trip but needs to
  plan a *later* part of it, or a *subsequent* trip. The binary toggle forces a
  false either/or. He's "here" (grounding live) but the subject is "elsewhere."
- **No tour-guide stance.** Companion mode today is purely logistics
  ("immediate decisions, navigation, schedule changes"). There's no licensed
  way for the AI to *narrate* a place (history, what-to-see, local color) the
  way a tour guide would.

## The reframe: three independent axes

Decouple them:

| Axis | What it is | How it's set |
|---|---|---|
| **Grounding** | Physical presence (GPS/clock/current leg) | Always live, even mid-planning. It's the sanity check ("you land Aug 3, so that can't start Aug 1"). |
| **Subject** | Which trip/leg the conversation is about | Inferred from the question; optional explicit scope picker ("Working on: [Trip/Leg ▾]"). |
| **Persona** | Behavioral stance | Mostly auto-inferred from intent; one sticky exception (see Tour Guide). |

Once decoupled, "plan a future trip while standing in a piazza" and the
new-trip interview both just work — the travel agent is available regardless of
where Paul physically is.

### Planning ⇄ Companion becomes *emergent*, not a lock
- Subject = current leg & it's now → **Companion** behaviors.
- Subject = a future/other leg or trip → **Planning / travel-agent** behaviors.
- The hard toggle either disappears or becomes a soft, per-message-overridable
  default. A lightweight **subject scope picker** covers the case where Paul
  wants to pin it explicitly.

## Personas (within any grounding)

- **Planning spectrum:** *researcher* (neutral facts) ⇄ *travel agent*
  (proactive: builds itineraries, presents 2–3 options with tradeoffs, flags
  what to book now, budget-aware).
- **Companion spectrum:** *logistics co-pilot* (terse, factual: "when's my
  train") ⇄ *tour guide* (narrates place/history/what-to-see, paced to clock +
  GPS).

### How a persona is chosen
1. **Auto by intent (default).** Enrich each grounding's prompt to name and
   license both stances and how to pick. Mostly a `critic.py` prompt change —
   cheap, no UI.
2. **Explicit + persistent — Tour Guide only.** Tour-guiding while wandering a
   city wants to *hold* the voice across many messages, not snap back to terse
   after one answer → a small **"Tour guide" toggle/chip in Companion** that
   sticks until turned off.
3. **Cost-aware.** Tour-guide narration is generative/Heavy-tier; logistics is a
   cheap Light-tier lookup. Persona is a strong signal for the v1.0 tiered
   router.

## New-trip interview (travel-agent intake)

Starting a new trip should kick off a **short, profile-aware interview** — the
flagship payoff of the traveler-profile work (Steps 1–3).

- Because the AI already knows Paul's durable preferences (the distilled
  `profile_summary`), it **confirms and fills gaps** rather than asking what it
  can infer: *"Japan, ~10 days in October. You usually want trains over rental
  cars and boutique stays — keep that here? Who's coming? Any must-dos?"*
- Output is a **draft scaffold** dropped into Trip HQ (legs, a rough day-shape,
  a research/booking task list), which Paul then edits — not a locked plan.
- It also *feeds* the profile loop: the trip's eventual post-trip review
  distills back into the summary.

### Open shaping decisions
- **Format:** conversational extraction / structured form / hybrid (chat that
  produces an editable skeleton)?
- **First-version scope:** just *propose* a skeleton in chat, vs actually
  *create* the legs/tasks in Trip HQ? (The latter is the bigger build and a
  natural fit for the v1.0 plan→research→critique→present pipeline.)

## Unverifiable-narration tension
Tour-guide storytelling (history, local color) can lean on facts the AI can't
verify on-device/offline — which rubs against the **"ask, don't guess"**
low-confidence rule (`critic.py` §3.4). Decide how to reconcile rich narration
with that guardrail before building the tour-guide persona.

## Suggested sequencing (when ready)
1. **Decouple grounding / subject / persona** — mostly a prompt change + a small
   scope selector. Unblocks everything else.
2. **Profile-aware new-trip interview** on top.

## Related / see also
- `docs/wayfarer-v1-spec.md` — modes, tiered routing, multi-agent pipeline.
- Traveler-profile feature (Steps 1–3): `profile_summary` is the through-line —
  the interview *uses* it, personas *read* it, the review *updates* it.
