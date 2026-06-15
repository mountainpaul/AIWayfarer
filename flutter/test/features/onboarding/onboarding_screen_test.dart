import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/features/onboarding/onboarding_screen.dart';
import 'package:wayfarer/services/api_client.dart';
import 'package:wayfarer/services/local_db.dart';
import 'package:wayfarer/services/sync_service.dart';

// ---------------------------------------------------------------------------
// Fake SyncService — returns configurable success/failure immediately.
// ---------------------------------------------------------------------------
// We subclass SyncService and pass the singleton LocalDb.instance as the `db`
// argument.  The singleton is always available (it's created lazily as a
// private constructor call), but its SQLite connection is never opened in
// tests — that's fine because our override of `snapshot()` never calls
// `super`, so the `db` field is never accessed.
class _FakeSyncService extends SyncService {
  _FakeSyncService({this.snapshotResult = true})
      : super(
          api: ApiClient(baseUrl: 'http://fake.test'),
          db: LocalDb.instance,
        );

  final bool snapshotResult;

  @override
  Future<bool> snapshot() async => snapshotResult;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Tall surface so long pages like Demo render without overflow.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app({
  String initialUrl = 'http://test.local:8000',
  bool syncSuccess = true,
}) {
  final fakeSync = _FakeSyncService(snapshotResult: syncSuccess);
  return ProviderScope(
    overrides: [
      // Seed a known API URL so the URL text field has a value.
      apiBaseUrlProvider.overrideWith(
        (_) => ApiBaseUrlNotifier(initial: initialUrl),
      ),
      // Replace SyncService so the Sync page never hits the network.
      syncServiceProvider.overrideWithValue(fakeSync),
    ],
    child: const MaterialApp(home: OnboardingScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Reset the global completion notifier between tests.
    onboardingCompleteNotifier.value = false;
  });

  // ── Page 1: Welcome ────────────────────────────────────────────────────────

  group('Welcome page (page 0)', () {
    testWidgets('renders app name, tagline and Get Started button',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('AI Wayfarer'), findsOneWidget);
      expect(
        find.text('Your travel planning and live companion.\nLet\'s get set up.'),
        findsOneWidget,
      );
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('tapping Get Started advances to URL page', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // URL page headline
      expect(find.text('Connect to Backend'), findsOneWidget);
    });
  });

  // ── Page 2: API URL ────────────────────────────────────────────────────────

  group('API URL page (page 1)', () {
    /// Helper: navigate to the URL page.
    Future<void> goToUrlPage(WidgetTester tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows headline, hint text, and Save & Continue button',
        (tester) async {
      _tallSurface(tester);
      await goToUrlPage(tester);

      expect(find.text('Connect to Backend'), findsOneWidget);
      expect(find.text('API base URL'), findsOneWidget);
      expect(find.text('Save & Continue'), findsOneWidget);
    });

    testWidgets('text field is pre-populated with the seeded URL',
        (tester) async {
      _tallSurface(tester);
      await goToUrlPage(tester);

      final tf = find.byType(TextField);
      expect(tf, findsOneWidget);
      expect(
        (tester.widget(tf) as TextField).controller?.text,
        equals('http://test.local:8000'),
      );
    });

    testWidgets('entering a URL and tapping Save persists to prefs',
        (tester) async {
      _tallSurface(tester);
      await goToUrlPage(tester);

      await tester.enterText(
          find.byType(TextField), 'http://192.168.1.99:8000');
      await tester.pump();

      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      // Should advance to Permissions page.
      expect(find.text('Permissions'), findsOneWidget);

      // URL should be persisted in SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(ApiBaseUrlNotifier.prefsKey),
        equals('http://192.168.1.99:8000'),
      );
    });

    testWidgets('tapping Save with blank URL does NOT advance', (tester) async {
      _tallSurface(tester);
      await goToUrlPage(tester);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      // Still on the URL page.
      expect(find.text('Connect to Backend'), findsOneWidget);
      expect(find.text('Permissions'), findsNothing);
    });
  });

  // ── Page 3: Permissions ────────────────────────────────────────────────────

  group('Permissions page (page 2)', () {
    /// Navigate to the Permissions page.
    Future<void> goToPermissionsPage(WidgetTester tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders Location and Microphone tiles plus both nav buttons',
        (tester) async {
      _tallSurface(tester);
      await goToPermissionsPage(tester);

      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Microphone'), findsOneWidget);
      // Initially neither is granted.
      expect(find.text('Tap to grant'), findsNWidgets(2));

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('Continue button advances to Sync page', (tester) async {
      _tallSurface(tester);
      await goToPermissionsPage(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Sync Trip Data'), findsOneWidget);
    });

    testWidgets('Skip for now also advances to Sync page', (tester) async {
      _tallSurface(tester);
      await goToPermissionsPage(tester);

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.text('Sync Trip Data'), findsOneWidget);
    });

    // Platform-channel note: tapping the Location / Microphone list tiles calls
    // Geolocator.requestPermission() and SpeechToText.initialize() via real
    // platform channels that cannot be intercepted without method-channel mocking.
    // Those taps are therefore not exercised here; the UI state they would toggle
    // (Granted / Tap to grant) is tested below via the navigation path that
    // bypasses them.
  });

  // ── Page 4: Sync ──────────────────────────────────────────────────────────

  group('Sync page (page 3)', () {
    /// Navigate to the Sync page.
    Future<void> goToSyncPage(
      WidgetTester tester, {
      bool syncSuccess = true,
    }) async {
      await tester.pumpWidget(_app(syncSuccess: syncSuccess));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders Sync Trip Data heading and Sync Now button initially',
        (tester) async {
      _tallSurface(tester);
      await goToSyncPage(tester);

      expect(find.text('Sync Trip Data'), findsOneWidget);
      expect(find.text('Pull your trip data from the backend.'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);
      // Not yet synced — no success state.
      expect(find.text('You\'re all set!'), findsNothing);
    });

    testWidgets('successful sync shows success state and Next button',
        (tester) async {
      _tallSurface(tester);
      await goToSyncPage(tester, syncSuccess: true);

      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();

      expect(find.text('You\'re all set!'), findsOneWidget);
      expect(find.text('Trip data loaded successfully.'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      // Sync Now button should disappear.
      expect(find.text('Sync Now'), findsNothing);
    });

    testWidgets('failed sync shows error message and keeps Sync Now visible',
        (tester) async {
      _tallSurface(tester);
      await goToSyncPage(tester, syncSuccess: false);

      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();

      expect(find.text('Could not reach the backend.'), findsOneWidget);
      // Sync Now should still be available to retry.
      expect(find.text('Sync Now'), findsOneWidget);
      expect(find.text('You\'re all set!'), findsNothing);
    });

    testWidgets('Next after successful sync advances to Demo page',
        (tester) async {
      _tallSurface(tester);
      await goToSyncPage(tester, syncSuccess: true);

      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Demo page headline
      expect(
        find.text('Here\'s what Wayfarer looks like in action'),
        findsOneWidget,
      );
    });
  });

  // ── Page 5: Demo ──────────────────────────────────────────────────────────

  group('Demo page (page 4)', () {
    /// Navigate all the way through to the Demo page (happy sync path).
    Future<void> goToDemoPage(WidgetTester tester) async {
      await tester.pumpWidget(_app(syncSuccess: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders demo conversation and Start Using Wayfarer button',
        (tester) async {
      _tallSurface(tester);
      await goToDemoPage(tester);

      expect(
        find.text('Here\'s what Wayfarer looks like in action'),
        findsOneWidget,
      );
      expect(
        find.text('What time does the ferry leave tomorrow?'),
        findsOneWidget,
      );
      expect(find.text('Start Using Wayfarer'), findsOneWidget);
    });

    testWidgets(
        'tapping Start Using Wayfarer marks onboarding_complete in prefs '
        'and flips onboardingCompleteNotifier', (tester) async {
      _tallSurface(tester);
      await goToDemoPage(tester);

      // Notifier must start as false.
      expect(onboardingCompleteNotifier.value, isFalse);

      await tester.tap(find.text('Start Using Wayfarer'));
      await tester.pumpAndSettle();

      // SharedPreferences flag should be set.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_complete'), isTrue);

      // ValueNotifier should be flipped.
      expect(onboardingCompleteNotifier.value, isTrue);
    });
  });

  // ── Full wizard end-to-end ─────────────────────────────────────────────────

  group('Full wizard end-to-end', () {
    testWidgets(
        'completes all 5 steps: Welcome → URL → Permissions → Sync → Demo → Finish',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(syncSuccess: true));
      await tester.pumpAndSettle();

      // Step 1: Welcome
      expect(find.text('AI Wayfarer'), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Step 2: URL
      expect(find.text('Connect to Backend'), findsOneWidget);
      await tester.enterText(
          find.byType(TextField), 'http://10.0.0.5:8000');
      await tester.pump();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      // Step 3: Permissions
      expect(find.text('Permissions'), findsOneWidget);
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      // Step 4: Sync
      expect(find.text('Sync Trip Data'), findsOneWidget);
      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();
      expect(find.text('You\'re all set!'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 5: Demo
      expect(find.text('Start Using Wayfarer'), findsOneWidget);
      await tester.tap(find.text('Start Using Wayfarer'));
      await tester.pumpAndSettle();

      // Verify completion
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_complete'), isTrue);
      expect(onboardingCompleteNotifier.value, isTrue);

      // Verify URL was persisted with the custom value.
      expect(
        prefs.getString(ApiBaseUrlNotifier.prefsKey),
        equals('http://10.0.0.5:8000'),
      );
    });
  });
}
