# Wayfarer — CLAUDE.md

## What this is

Wayfarer is a travel planning and live-companion app. Two modes, one app:
- **Planning mode** — pre-trip itinerary building, bookings research, multi-leg logistics
- **Companion mode** — during-trip reasoning partner: answers questions, navigates, journals, flags broken plans

## Architecture

- **flutter/** — Flutter mobile app (Android + iOS)
- **backend/** — FastAPI Python service (Claude/Gemini multi-agent pipeline)
- **data/** — Exported Trip HQ data (JSON) for migration
- **docs/** — Design specs, sprint plans

## Key design decisions

- Single-user (Paul) for v1
- Multi-agent pipeline: plan → research → critique → present
- Grounding layer: GPS + clock + Trip HQ state + Calendar
- Tiered query routing (Light/Medium/Heavy) to stay under $50/month API budget
- SQLite on device + Postgres on DO droplet (2GB)
- Voice: push-to-talk default, wake-word when charging
- Offline-first for current-leg data

## Common commands

```bash
# Flutter app
cd flutter && flutter pub get && flutter run

# Backend
cd backend && pip install -r requirements.txt
uvicorn app.main:app --reload

# Tests
cd flutter && flutter test
cd backend && pytest
```

## Version targets

- **v0.5** (late May 2026) — Text chat + voice, single-Claude with critic prompt, grounding layer, Trip HQ CRUD, Calendar/Gmail read, pre-trip briefing, offline cache
- **v1.0** (August 5, 2026) — Full multi-agent pipeline, Reddit/Maps integration, broken plan detection, voice tours, robust offline (JMT)
