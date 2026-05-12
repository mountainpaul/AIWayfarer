# Wayfarer backend (v0.5)

FastAPI service for the Wayfarer travel companion (single-user, Paul).

## Setup

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# edit .env to set ANTHROPIC_API_KEY
uvicorn app.main:app --reload
```

The service auto-applies `db/migrations/*.sql` (in lexical order) on startup.
The base schema is already populated via `backend/db/migrate_trip_hq.py`.

## Environment variables

| Var                | Default                          | Notes                                            |
| ------------------ | -------------------------------- | ------------------------------------------------ |
| `ANTHROPIC_API_KEY`| _(unset)_                        | Required for `/chat` and `/briefing/generate`    |
| `ANTHROPIC_MODEL`  | `claude-sonnet-4-6`              | v0.5 collapses to a single Claude call           |
| `DB_PATH`          | `backend/db/wayfarer.db`         | Override only for testing                        |
| `CORS_ORIGINS`     | `*`                              | Comma-separated, or `*` for v0.5 dev             |

## Endpoints

| Method | Path                          | Purpose                                              |
| ------ | ----------------------------- | ---------------------------------------------------- |
| GET    | `/health`                     | Service status + whether Anthropic is configured     |
| GET    | `/trips`                      | List all trips                                       |
| GET    | `/trips/{id}`                 | Trip detail                                          |
| GET    | `/legs`                       | List legs (filter by `trip_id`)                      |
| GET    | `/legs/current?date=…`        | Leg covering the given date (defaults today)         |
| GET    | `/legs/{id}`                  | Leg detail                                           |
| PATCH  | `/legs/{id}`                  | Edit leg fields                                      |
| GET    | `/bookings`                   | List bookings (filter by `leg_id`, `type`, `status`) |
| POST   | `/bookings`                   | Create booking                                       |
| GET    | `/bookings/{id}`              | Booking detail                                       |
| PATCH  | `/bookings/{id}`              | Edit booking                                         |
| DELETE | `/bookings/{id}`              | Delete booking                                       |
| GET    | `/tasks`                      | List tasks (filter by `leg_id`, `is_done`)           |
| POST   | `/tasks`                      | Create task                                          |
| GET    | `/tasks/{id}`                 | Task detail                                          |
| PATCH  | `/tasks/{id}`                 | Edit task                                            |
| PATCH  | `/tasks/{id}/done`            | Toggle done state                                    |
| DELETE | `/tasks/{id}`                 | Delete task                                          |
| GET    | `/packing`                    | List packing items (filter by `trip_id`, `category`) |
| POST   | `/packing`                    | Create packing item                                  |
| GET    | `/packing/{id}`               | Packing item detail                                  |
| PATCH  | `/packing/{id}`               | Edit item                                            |
| PATCH  | `/packing/{id}/packed`        | Toggle packed state                                  |
| DELETE | `/packing/{id}`               | Delete item                                          |
| GET    | `/journal`                    | List journal entries                                 |
| POST   | `/journal`                    | Append entry (autonomous per spec §6)                |
| POST   | `/chat`                       | Single-Claude w/ critic prompt (spec §3.2)           |
| POST   | `/briefing/generate`          | Generate + cache today's briefing                    |
| GET    | `/briefing/today`             | Latest cached briefing as `text/markdown`            |
| GET    | `/grounding?lat=&lon=&now=`   | Assemble grounding payload (spec §4)                 |
| GET    | `/sync/snapshot`              | Offline cache bundle (current leg + future state)    |
| GET    | `/calendar/events`            | Stub — returns `[]` (TODO: Google OAuth)             |
| GET    | `/gmail/threads`              | Stub — returns `[]` (TODO: Google OAuth)             |

## Conventions

- **IDs:** UUID4 strings, generated in app code (not the schema).
- **Money:** all cost fields are `INTEGER` cents on the wire and in the DB. Pass `cost_cents` directly.
- **Booleans:** Pydantic models expose `bool`; converted to `INTEGER 0/1` at the SQL boundary.
- **Dates:** ISO 8601 (`YYYY-MM-DD` for dates, `YYYY-MM-DDTHH:MM:SSZ` for timestamps).

## Chat endpoint shape

```json
POST /chat
{
  "message": "When does the ferry leave Pozzallo?",
  "mode": "companion",
  "session_id": null,
  "grounding": null
}
```

If `grounding` is omitted, the server derives it from the DB (current leg,
today's bookings, open task count). Provide your own when the client has GPS.

Response includes the draft, the critic's notes, the revised answer, a
confidence label, and parsed source citations — see `app/models.py:ChatResponse`.

If `ANTHROPIC_API_KEY` is unset, `/chat` returns 503 with a clear error.

## Tests

```bash
pytest
```

Tests use the populated `db/wayfarer.db`. The `/chat` test mocks the Anthropic
client — no API key required.
