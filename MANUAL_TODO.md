# Wayfarer — Manual To-Do List

Things Claude can't do for you. Work through these to get v0.5 running end-to-end.
Today's date for reference: **2026-04-26**. v0.5 target: **late May 2026** (Dolomites leg starts 2026-06-13, but you wanted to dogfood earlier).

---

## 1. Local toolchain (your dev machine)

- [ ] **Install Python 3.12+** (already have it)
- [ ] **Install pip + venv** if not already:
  ```bash
  sudo apt install python3-pip python3-venv
  ```
- [ ] **Install Flutter SDK** (stable channel, **≥ 3.27** — required for the `CardThemeData` API used in `app/theme.dart`; pinned in `pubspec.yaml`):
  - Linux: `snap install flutter --classic` *or* download from https://docs.flutter.dev/get-started/install/linux
  - Run `flutter doctor` and resolve any red Xs (Android SDK, Android licenses, etc.)
- [ ] **Install Android Studio** (for Android emulator + SDK + platform-tools)
  - Accept Android SDK licenses: `flutter doctor --android-licenses`
- [ ] **(Optional) Install Xcode** if you want to build for iOS — only on macOS, so skip on this Linux box

---

## 2. Backend bring-up

The venv is already created at `backend/.venv` with deps installed; all 72 tests pass and the DB is populated. To run:

```bash
cd backend
source .venv/bin/activate
cp .env.example .env
# edit .env with your Anthropic key (see §3)
uvicorn app.main:app --reload
```

Visit http://localhost:8000/docs to poke endpoints via Swagger.

- [x] DB at `backend/db/wayfarer.db` populated (1 trip, 10 legs, 63 bookings, 40 tasks, 57 packing items)
- [x] `pytest` from `backend/` — 72/72 green (CRUD + service-layer + sync + chat-mode contract tests)
- [ ] Hit `GET /trips` from your machine and confirm Europe 2026 returns
- [ ] Add the venv path to your IDE (VS Code: `.venv/bin/python`) if you'll be editing

---

## 3. API keys / secrets

Copy `backend/.env.example` to `backend/.env`. The current vars are:

```bash
ANTHROPIC_API_KEY=sk-ant-...        # required for /chat and /briefing/generate
DB_PATH=                            # blank → defaults to db/wayfarer.db
CORS_ORIGINS=*                      # tighten before exposing publicly
ANTHROPIC_MODEL=claude-sonnet-4-6
GOOGLE_SECRETS_DIR=                 # blank → defaults to backend/secrets/
```

Google OAuth credentials are now file-based, not env-var-based: drop `client_secret.json` into `backend/secrets/` and run `scripts/google_auth.py` once — see §4.

- [ ] **Anthropic API key** — generate at https://console.anthropic.com/. Set up usage budget alert at $40/month so you trip the alarm before the $50 ceiling (spec §13).
- [ ] **Verify model name** — `claude-sonnet-4-6` is what the backend uses for v0.5. Override via `ANTHROPIC_MODEL` env var if pricing/availability changes; no code edit needed.
- [ ] **Without the key**: `/chat` returns 503 with a clear error; `/briefing/generate` falls back to deterministic markdown. Everything else (CRUD, grounding, sync) works fine.

---

## 4. Google OAuth (Calendar + Gmail read) — Sprint 3

The Calendar side is wired: `routers/calendar.py` (real, with mocked tests), shared auth in `services/google_auth.py`, and a one-time helper at `scripts/google_auth.py`. Gmail still stubbed in `routers/gmail_stub.py` — same pattern when you're ready.

- [x] Go to https://console.cloud.google.com/ → create project "Wayfarer"
- [ ] Enable APIs in the Wayfarer project: **Google Calendar API**, **Gmail API** (APIs & Services → Library)
- [ ] Configure OAuth consent screen (External, single user — yourself; add your Google account as a Test User so unverified-app warnings don't block you)
- [ ] Create OAuth 2.0 Client ID (APIs & Services → Credentials → Create Credentials → OAuth client ID → **Desktop app**)
- [ ] Download the credentials JSON to `backend/secrets/client_secret.json` (the `secrets/` dir is gitignored except for `.gitkeep` — verify before committing)
- [ ] Run the auth helper from your laptop (must have a browser):
  ```bash
  cd backend
  source .venv/bin/activate
  python scripts/google_auth.py
  ```
  This opens your browser, you approve `calendar.readonly` + `gmail.readonly`, and `secrets/google_token.json` gets written. Refresh tokens are long-lived; re-run only if you revoke or change scopes.
- [ ] Smoke-test the endpoint: `curl http://localhost:8000/calendar/events` — expect a JSON list. While unauthenticated you'll get a 503 with instructions; after the helper runs it returns real events.
- [x] ~~Replace calendar stub with real implementation~~ — done; 6 new tests in `tests/test_calendar.py` cover 503/502/happy paths with mocked Google client
- [ ] Repeat the pattern for Gmail (next): mirror `routers/calendar.py` → `routers/gmail.py`, drop `gmail_stub.py`, reuse `services/google_auth.py` (scopes already include `gmail.readonly`)
- [ ] Once authenticated on the laptop, copy `backend/secrets/google_token.json` to the droplet (`scp`) — refresh tokens are portable

---

## 5. Flutter app bring-up

```bash
cd flutter
# First-time only — fills in platform-specific scaffolding the agent couldn't generate
# (Runner.xcodeproj, gradle wrapper, launch storyboard, app icons). Non-destructive:
flutter create --platforms=android,ios --org com.paulegges --project-name wayfarer .

flutter pub get
dart run build_runner build --delete-conflicting-outputs   # required: generates *.freezed.dart and *.g.dart
```

The build_runner step is **mandatory** — `briefing`, `chat_message`, `task`, `packing_item`, and `leg` had their generated files deleted after model changes (during the review pass) and will not compile until regenerated. The `--delete-conflicting-outputs` flag also overwrites the four still-committed generated sets (`booking`, `grounding`, `journal_entry`, `trip`) for consistency.

`API_BASE_URL` defaults to `http://localhost:8000` and is overridable two ways:
- **Build time**: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`
- **Runtime**: Settings screen inside the app (live override, no rebuild)

Per-target hosts:
- Android emulator → `http://10.0.2.2:8000`
- Physical Android device on same wifi → `http://<your-laptop-LAN-IP>:8000`
- iOS simulator → `http://localhost:8000`

- [ ] `flutter run` — pick your device
- [ ] Confirm Trips → Europe 2026 → Sicily → Bookings shows the 8 Sicily bookings
- [ ] Toggle to Companion mode, send a chat message, verify it round-trips through the backend
- [x] ~~Wire `shared_preferences` so the Settings API_BASE_URL persists~~ — done; hydrated eagerly in `main.dart` via a `ProviderScope` override

### Permissions (first run will prompt)
- [ ] Microphone (push-to-talk)
- [ ] Speech recognition
- [ ] Location (when-in-use)

---

## 6. Phone-side prep

- [ ] **Galaxy S25 Ultra**: enable Developer Options → USB debugging
- [ ] Install device via `adb devices` then `flutter run -d <id>`
- [ ] Test push-to-talk in a real environment (cafe, train) — STT quality is the v0.5 acceptance gate
- [ ] Test offline mode: airplane-mode the phone after pulling /sync/snapshot, confirm current-leg bookings still readable

---

## 7. DigitalOcean droplet (production backend, 2GB)

For when you want chat from the phone away from the laptop. Sprint 4 territory.

- [ ] Spin up Ubuntu 24.04 LTS, 2GB droplet (the one referenced in spec §12.1)
- [ ] `ssh` in, install: `python3.12 python3-venv nginx certbot python3-certbot-nginx`
- [ ] Clone the repo (read-only deploy key from GitHub)
- [ ] systemd unit for `uvicorn app.main:app --host 127.0.0.1 --port 8000`
- [ ] nginx reverse proxy → Let's Encrypt cert for `wayfarer.<your-domain>` or `<droplet-ip>.nip.io`
- [ ] Postgres optional in v0.5 — keep SQLite. The spec mentions Postgres for v1.0; revisit then.
- [ ] Set `CORS_ORIGINS` to your phone's expected origin (or keep `*` since single-user)
- [ ] Point Flutter at the droplet: `flutter run --dart-define=API_BASE_URL=https://wayfarer.<your-domain>` (or set in the Settings screen at runtime — note Settings persistence isn't wired, see §5)
- [ ] Add `ufw` rules: 22, 80, 443 only

---

## 8. Backups

- [ ] Cron daily `sqlite3 db/wayfarer.db .dump > backups/wayfarer-$(date +%F).sql.gz` on the droplet
- [ ] Rclone or rsync `backups/` to a second location (Backblaze B2 or your home NAS)
- [ ] Test restore at least once before the Tunisia leg (you're already past it as of 2026-04-26 — but Sicily leg is mid-flight, don't lose it)

---

## 9. v0.5 acceptance checklist (before Dolomites)

From spec §10:
- [ ] Text chat round-trips through backend with critic-style verification
- [ ] Push-to-talk voice in + TTS voice out
- [ ] Grounding layer working (GPS + clock + current leg + calendar)
- [ ] All Trip HQ CRUD works in-app
- [ ] Calendar + Gmail read returning real data (no stubs)
- [ ] Pre-trip briefing generates overnight (cron on droplet) and shows on home screen
- [ ] Current-leg data readable offline (airplane mode test passes)

---

## 10. Stuff explicitly deferred (don't accidentally build)

Spec §10.v1.1+ backlog — DO NOT BUILD THESE NOW:
- Photo Q&A
- Expense tracking
- Two-way calendar sync (read-only is fine for v0.5)
- Companion-traveler support (Kevin / Ireland)
- Wake-word (push-to-talk only in v0.5)
- Reddit integration (v1.0)
- Maps / Rome2Rio routing (v1.0)
- Full multi-agent pipeline (v1.0 — single-Claude with critic prompt is good enough for v0.5)

---

## 11. Watchlist (issues to keep an eye on)

- [ ] **Anthropic costs** — track daily; spec §13 says $50/month ceiling
- [ ] **Prompt cache hit rate** — should be >70% within a session. If not, the system prompt is varying when it shouldn't.
- [ ] **GPS battery drain** — check after first day-trip with the app live
- [ ] **STT accuracy in noise** — Whisper API fallback is the lever if device STT is bad

---

## 12. Things I (Claude) did automatically

- Re-ran `backend/db/migrate_trip_hq.py` — `wayfarer.db` is fresh: 1 trip, 10 legs, 63 bookings, 40 tasks, 57 packing items
- Generated `backend/db/wayfarer-hotels-gmaps.csv` — 33 hotel/rifugio pins for Google My Maps import (try it: https://www.google.com/maps/d/ → Create → Import)
- Wrote backend FastAPI app — **78/78 tests passing**
- Created `backend/.venv` and installed `requirements.txt` into it
- Added `backend/db/migrations/0002_briefings.sql` (auto-applied on app startup)
- Scaffolded Flutter app — 50 source files, all internal imports resolve, valid `pubspec.yaml` (Flutter ≥3.27)
- Stubbed `routers/calendar_stub.py` and `routers/gmail_stub.py` — they return `[]`; replace in Sprint 3

### Code review pass (post-scaffold)
- Caught and fixed 6 wire-mismatch bugs (B1–B6): sync shape, briefing model, toggle-vs-set semantics, missing chat `mode`, wrong chat response decode, wrong tasks filter param.
- Added 3 contract tests (T1–T3) so the wire shape can't silently regress: `tests/test_sync_contract.py`, `tests/test_chat_mode.py`, plus the iterations format check.

### Static Dart read pass (pre-first-compile)
- Caught and fixed 4 first-compile blockers (F1–F3, F15):
  - **F1** — `Task.is_done`, `PackingItem.is_packed`, `Leg.is_schengen` declared as `int` but backend sends `bool`. Changed Dart models to `bool`; added int↔bool conversion in `local_db.dart` at the sqflite boundary (`_clean` for reads, `_toSqlite` for writes).
  - **F2** — Missing `break;` after every case in `app/router.dart:_go`.
  - **F3** — `CardTheme(...)` → `CardThemeData(...)` for Flutter 3.27+. Pubspec min SDK bumped to `>=3.27.0` to match.
  - **F15** — `test/widget_test.dart` skipped with explicit reason; needs LocalDb test fixture (path_provider mock + sqflite_common_ffi) to actually run.
- Stale generated files (5 sets) deleted; `dart run build_runner build --delete-conflicting-outputs` regenerates everything.

### Sprint 3: Calendar (in progress)
- Added Google API deps (`google-api-python-client`, `google-auth-oauthlib`, etc.) to `requirements.txt` and installed in venv.
- Wrote `app/services/google_auth.py` — process-cached credentials loader with auto-refresh. Raises `GoogleNotConfiguredError` → 503 when token missing.
- Wrote `scripts/google_auth.py` — one-time loopback flow (the right pattern for desktop apps; true RFC 8628 device flow doesn't cover Calendar/Gmail scopes). Opens browser, captures consent, writes `secrets/google_token.json`.
- Wrote `app/services/calendar.py` — Calendar adapter that normalizes Google's event shape into stable JSON.
- Wrote `app/routers/calendar.py` — real GET `/calendar/events` with from/to query params; replaces `calendar_stub.py` (deleted).
- Created `backend/secrets/` (gitignored except `.gitkeep`); updated root `.gitignore` to never commit credentials.
- Added 6 calendar tests with mocked Google client (503 / 502 / happy / shape / default-window / missing-summary).

### Cleanup pass (post-review)
- Backend `briefing.py` `datetime.utcnow()` → `datetime.now(timezone.utc)` — pytest warning gone.
- Flutter `Color.withOpacity` → `Color.withValues(alpha:)` at 4 sites.
- `geolocator` `desiredAccuracy:` → `locationSettings: LocationSettings(accuracy: …)`.
- `speech_to_text` `listenMode:` / `partialResults:` → `listenOptions: SpeechListenOptions(…)`.
- Deleted unused `BookingType` / `BookingStatus` Dart enums in `models/booking.dart`.
- Deleted unreachable `ApiClient.getCurrentLeg()`.
- Settings screen: removed the unwired model picker; replaced with a one-liner pointing at the `ANTHROPIC_MODEL` env var.
- `shared_preferences` wired for `API_BASE_URL` persistence (`main.dart` hydrates eagerly before any Dio is constructed; `ApiBaseUrlNotifier.set()` writes back).

### Known gaps (carried into the to-dos above)
- `flutter create` still needs to be run once before first build (§5)
- `dart run build_runner build --delete-conflicting-outputs` is **mandatory** before first `flutter run` (§5)
- Clarifying-question chip renders when chat confidence is `low`, but its tap handler is a TODO (composing structured replies is its own UX)
- Wake-word voice mode is push-to-talk-only for v0.5 by design (§10)
- Offline write queue is out of scope for v0.5 — the app shows "Offline – writes disabled" toast on backend failure (§10)
- Widget tests skipped — `flutter test` will report 1 skipped, 0 failed; needs LocalDb test fixture (path_provider mock + sqflite_common_ffi)
