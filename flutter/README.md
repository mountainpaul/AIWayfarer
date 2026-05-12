# Wayfarer Flutter app (v0.5)

Single-user travel planning + on-trip companion app for Paul. Targets Android
(primary) and iOS. See `../docs/wayfarer-v1-spec.md` for the full design.

## First-run setup

The Flutter SDK is required and was NOT bundled with this scaffold. Steps:

### 1. Install the Flutter SDK

Follow https://docs.flutter.dev/get-started/install for your OS, then run
`flutter doctor` until it's clean for Android (and optionally iOS).

### 2. Fill in platform shells

This scaffold ships hand-written `android/` and `ios/Runner/Info.plist` files
that are minimal but valid. Many platform-specific files (Gradle wrappers,
`Runner.xcodeproj`, launch screen storyboard, app icons, etc.) are NOT
included. Run:

```bash
cd flutter
flutter create --platforms=android,ios --org com.paulegges --project-name wayfarer .
```

`flutter create` is non-destructive for existing files - it fills in only what
is missing. Re-confirm `android/app/src/main/AndroidManifest.xml` still has the
`INTERNET / RECORD_AUDIO / ACCESS_*_LOCATION` permissions and that
`ios/Runner/Info.plist` still has `NSMicrophoneUsageDescription`,
`NSSpeechRecognitionUsageDescription`, and `NSLocationWhenInUseUsageDescription`.

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Generate Freezed / json_serializable code

```bash
dart run build_runner build --delete-conflicting-outputs
```

This creates the `*.freezed.dart` and `*.g.dart` files that the model classes
reference. Re-run after editing any model under `lib/models/`.

### 5. Point at the backend

Default base URL is `http://localhost:8000`. Override at run time:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

You can also change it inside the app via Settings (in-memory only for v0.5).

For Android emulator pointing at your host machine's localhost, use
`http://10.0.2.2:8000`. For an iOS Simulator, `http://localhost:8000` works.

### 6. Run

```bash
flutter run                      # picks first attached device
flutter run -d emulator-5554     # specific Android emulator
flutter run -d "iPhone 15"       # specific iOS Simulator
```

## What's in this scaffold

- **Two app modes** - Planning / Companion toggle in the app bar (just a UI
  flag for now; backend reads from grounding payload).
- **Today / Home screen** - briefing card, current leg, next booking, open task
  count. Pull to refresh.
- **Trips screen** - list of legs; tap into per-leg detail with tabs for
  Bookings, Tasks, Packing, Journal.
- **Chat screen** - text + push-to-talk voice. Default presentation mode shows
  draft -> critic -> revised iteration panel (collapsed). Low-confidence
  responses surface a clarifying-question chip.
- **Companion dashboard** - GPS / leg / next booking / open issues panel.
- **Settings** - API base URL, voice mode, model, quiet mode.
- **Local SQLite cache** - mirrors `backend/db/schema.sql`; populated from
  `GET /sync/snapshot` on startup. Reads are local; writes go to backend then
  refresh local.

## What's stubbed / TODO

- `flutter create` must be run to fill platform shells (see above).
- Wake-word voice mode (push-to-talk only for v0.5).
- Settings persistence (currently in-memory; add `shared_preferences` writes).
- Offline write queue (out of scope for v0.5; UI shows "Offline - writes
  disabled" toast on failure).
- Photo capture / visual Q&A (deferred to v1.1+).
- Two-way calendar sync (read-only for v0.5).

## Project layout

```
lib/
  main.dart
  app/                 # WayfarerApp, router, theme
  config/env.dart      # API_BASE_URL constant
  models/              # Freezed models matching backend schema
  services/            # api_client, local_db, location, voice, grounding, sync
  features/            # home, trips, chat, companion, settings UIs
  providers/           # Riverpod providers
test/                  # smoke widget test
android/               # minimal Android scaffold (AndroidManifest, Gradle stubs)
ios/Runner/Info.plist  # iOS permissions strings
```

## Tests

```bash
flutter test
```

The boot smoke test does not require a running backend.
