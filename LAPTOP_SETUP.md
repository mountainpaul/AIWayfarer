# Laptop smoke test — bootstrap

This is the minimal path to get Wayfarer running on the Pixel 9 XL Pro via your laptop, with the backend running locally on the laptop. Once this works end-to-end, we can move the backend to the cloud server (MANUAL_TODO §7).

Assumes Linux or macOS laptop. Flutter SDK ≥ 3.27 (you have it). Python 3.12+. Pixel on USB with Developer Options + USB debugging enabled.

---

## 1. Clone and check out the scaffold branch

```bash
git clone git@github.com:mountainpaul/AIWayfarer.git
cd AIWayfarer
git checkout v0.5-scaffold
```

The latest commit should be `4dca997 Fix Flutter compile blockers found during smoke-test prep`.

---

## 2. Backend bring-up

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Populate the DB from data/trip-hq.jsx (1 trip / 10 legs / 63 bookings / 40 tasks / 57 packing items)
python db/migrate_trip_hq.py

# Sanity: run the test suite
pytest                              # expect 72/72 green

# Leave this terminal running for the rest of the smoke test
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

In a **separate terminal**, sanity-check the API:

```bash
curl -s http://127.0.0.1:8000/trips | python3 -m json.tool
curl -s http://127.0.0.1:8000/legs/current | python3 -m json.tool
```

You should see Europe 2026 in the first response and "Italian Cities" (Amalfi → Lake Como) in the second — that's the leg containing today's date.

---

## 3. Wire the phone to the laptop's backend

With the Pixel plugged in via USB:

```bash
adb devices
# Expect a single device line ending in "device" (if it says "unauthorized",
# accept the USB-debug prompt on the phone screen).

adb reverse tcp:8000 tcp:8000
# Now the phone's localhost:8000 routes to the laptop's localhost:8000.
# This is the cleanest way to wire phone → laptop-backend over USB; no LAN
# IP or wifi required.
```

If `adb` isn't on PATH, it lives at `~/Android/sdk/platform-tools/adb` (or `~/Library/Android/sdk/...` on macOS).

---

## 4. Flutter

```bash
cd ../flutter
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # ~80 sec, generates *.freezed.dart and *.g.dart
flutter run                                                # auto-picks the Pixel
```

The first `flutter run` build can take 2–5 minutes (gradle warmup, asset compile). Subsequent hot reloads are seconds.

The default `API_BASE_URL` is `http://localhost:8000`, which — thanks to `adb reverse` — points back at your laptop. No env override needed.

---

## 5. What success looks like

Once the app launches on the phone:

- **Home screen** loads without crashing
- **Trips → Europe 2026** shows the trip with 10 legs
- **Italian Cities leg → Bookings** shows the bookings for the current leg
- **Companion mode** (toggle from home): chat input is visible, but sending a message returns a friendly 503 because we haven't set the Anthropic key yet — that's expected at this tier
- **Settings screen** shows the current `API_BASE_URL` (should be `http://localhost:8000`)

Permissions the app will request on first run: microphone, speech recognition, location (when-in-use). Grant all three.

---

## 6. Tier 3 — chat round-trip (needs Anthropic key)

When you're ready to test the actual /chat flow:

```bash
cd backend
cp .env.example .env
# Edit .env, set:  ANTHROPIC_API_KEY=sk-ant-...
# (Get the key at https://console.anthropic.com/; set a $40/mo budget alert per spec §13)

# Restart uvicorn (Ctrl-C the running one, then re-run the command from §2)
```

Then in the app, Companion mode → send "where am I right now?" → expect a real response with grounding context.

---

## Common failure modes

| Symptom | Most likely cause | Fix |
|---|---|---|
| `flutter pub get` fails with version conflict | Flutter SDK < 3.27 | `flutter upgrade` |
| `build_runner` fails on a model file | Stale generated file | already handled by `--delete-conflicting-outputs` |
| Phone shows empty trip list | `adb reverse` didn't take, or uvicorn isn't running | redo step 3, confirm step 2's curl works |
| "Connection refused" on phone | uvicorn bound to wrong interface | confirm `--host 127.0.0.1` (default) and `adb reverse` is active |
| Chat returns 503 | No Anthropic key (expected at Tier 2) | add key per §6 |
| `pytest` fails | Probably venv has stale deps | `pip install -r requirements.txt --upgrade` |

---

## After the smoke test passes

Likely next moves, in priority order:

1. Replace the Gmail stub (backend, mirrors the Calendar work that's done)
2. Wire pre-trip briefing into the home screen + cron it
3. MANUAL_TODO §7 — DigitalOcean droplet bring-up so the phone can hit the backend without USB
