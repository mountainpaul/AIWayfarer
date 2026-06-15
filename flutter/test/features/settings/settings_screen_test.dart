import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/features/settings/settings_screen.dart';
import 'package:wayfarer/providers/quiet_mode_provider.dart';
import 'package:wayfarer/services/api_client.dart';
import 'package:wayfarer/services/award_search.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _tallSurface(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 4000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

/// Lightweight notifier stub: records the last value set, starts at [initial].
class _FakeUrlNotifier extends ApiBaseUrlNotifier {
  _FakeUrlNotifier(String initial) : super(initial: initial);

  String? lastSet;

  @override
  Future<void> set(String url) async {
    lastSet = url;
    state = url;
    // Skip SharedPreferences in tests.
  }
}

/// Fake airport notifier. We can't override the private `_load()` method,
/// so we seed the value through SharedPreferences.setMockInitialValues in each
/// test that needs a specific initial airport code. The `set()` override
/// skips the real prefs write to keep tests hermetic.
class _FakeAirportNotifier extends HomeAirportNotifier {
  _FakeAirportNotifier() : super();

  String? lastSet;

  @override
  Future<void> set(String code) async {
    lastSet = code;
    state = code;
  }
}

class _FakeQuietNotifier extends QuietModeNotifier {
  _FakeQuietNotifier({super.initial});

  bool? lastSet;

  @override
  Future<void> set(bool value) async {
    lastSet = value;
    state = value;
  }
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );

// go_router is used for context.go('/profile'); for tests we do NOT need a
// real router — we just verify the tile exists and is tappable. Tapping in a
// plain MaterialApp throws a navigation exception which we catch via
// onNavigationNotification returning true, or we simply do findOneWidget.
// We use a lenient approach: wrap in Router only when we need to verify tap.

List<Override> _overrides({
  String url = 'http://localhost:8000',
  bool quietMode = false,
  _FakeUrlNotifier? urlNotifier,
  _FakeAirportNotifier? airportNotifier,
  _FakeQuietNotifier? quietNotifier,
}) {
  final urlN = urlNotifier ?? _FakeUrlNotifier(url);
  final airN = airportNotifier ?? _FakeAirportNotifier();
  final qN = quietNotifier ?? _FakeQuietNotifier(initial: quietMode);
  return [
    apiBaseUrlProvider.overrideWith((_) => urlN),
    homeAirportProvider.overrideWith((_) => airN),
    quietModeProvider.overrideWith((_) => qN),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Static structure ───────────────────────────────────────────────────────

  group('static structure', () {
    testWidgets('renders "Backend" section header', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      expect(find.text('Backend'), findsOneWidget);
    });

    testWidgets('renders "API base URL" label', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      expect(find.text('API base URL'), findsOneWidget);
    });

    testWidgets('renders "Travel" section header', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      expect(find.text('Travel'), findsOneWidget);
    });

    testWidgets('renders "Home airport (IATA)" label', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      expect(find.text('Home airport (IATA)'), findsOneWidget);
    });

    testWidgets('renders "Travel profile" ListTile', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      expect(find.text('Travel profile'), findsOneWidget);
    });

    testWidgets('travel profile tile has chevron_right icon', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('renders "Voice" section header', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      expect(find.text('Voice'), findsOneWidget);
    });

    testWidgets('renders "Wake-word mode" switch', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Wake-word mode'), findsOneWidget);
    });

    testWidgets('renders "Presentation" section header', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      expect(find.text('Presentation'), findsOneWidget);
    });

    testWidgets('renders "Quiet mode" switch', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      expect(find.text('Quiet mode'), findsOneWidget);
    });

    testWidgets('renders server-side model hint text', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      expect(find.textContaining('ANTHROPIC_MODEL'), findsOneWidget);
    });
  });

  // ── Initial values ─────────────────────────────────────────────────────────

  group('initial values', () {
    testWidgets('URL field seeded from provider', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
          _app(_overrides(url: 'http://my-server.example.com:9000')));
      await tester.pumpAndSettle();

      final field =
          tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text, 'http://my-server.example.com:9000');
    });

    testWidgets('airport field seeded from SharedPreferences', (tester) async {
      _tallSurface(tester);
      // Seed the prefs key that HomeAirportNotifier._load() reads.
      SharedPreferences.setMockInitialValues({'home_airport': 'DEN'});
      await tester.pumpWidget(_app(_overrides()));
      // pumpAndSettle lets _load() async finish.
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      final airportField = fields.elementAt(1);
      expect(airportField.controller!.text, 'DEN');
    });

    testWidgets('quiet mode switch reflects false initially', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
          _app(_overrides(quietMode: false)));
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch));
      // Quiet mode is the second switch (wake-word is first)
      expect(switches.last.value, isFalse);
    });

    testWidgets('quiet mode switch reflects true when seeded', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides(quietMode: true)));
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch));
      expect(switches.last.value, isTrue);
    });
  });

  // ── API URL field ──────────────────────────────────────────────────────────

  group('API URL field', () {
    testWidgets('submitting calls notifier.set and shows SnackBar',
        (tester) async {
      _tallSurface(tester);
      final urlN = _FakeUrlNotifier('http://localhost:8000');
      await tester.pumpWidget(_app([
        apiBaseUrlProvider.overrideWith((_) => urlN),
        homeAirportProvider.overrideWith((_) => _FakeAirportNotifier()),
        quietModeProvider
            .overrideWith((_) => _FakeQuietNotifier(initial: false)),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).first);
      await tester.enterText(
          find.byType(TextField).first, 'http://192.168.1.10:8000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(urlN.lastSet, 'http://192.168.1.10:8000');
      expect(find.text('API base URL saved'), findsOneWidget);
    });

    testWidgets('trims whitespace before saving', (tester) async {
      _tallSurface(tester);
      final urlN = _FakeUrlNotifier('http://localhost:8000');
      await tester.pumpWidget(_app([
        apiBaseUrlProvider.overrideWith((_) => urlN),
        homeAirportProvider.overrideWith((_) => _FakeAirportNotifier()),
        quietModeProvider
            .overrideWith((_) => _FakeQuietNotifier(initial: false)),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).first);
      await tester.enterText(
          find.byType(TextField).first, '  http://trimmed.example.com  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(urlN.lastSet, 'http://trimmed.example.com');
    });
  });

  // ── Home airport field ─────────────────────────────────────────────────────

  group('home airport field', () {
    testWidgets('submitting calls notifier.set and shows SnackBar',
        (tester) async {
      _tallSurface(tester);
      final airN = _FakeAirportNotifier();
      await tester.pumpWidget(_app([
        apiBaseUrlProvider
            .overrideWith((_) => _FakeUrlNotifier('http://localhost:8000')),
        homeAirportProvider.overrideWith((_) => airN),
        quietModeProvider
            .overrideWith((_) => _FakeQuietNotifier(initial: false)),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).at(1));
      await tester.enterText(find.byType(TextField).at(1), 'LAX');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(airN.lastSet, 'LAX');
      expect(find.text('Home airport saved'), findsOneWidget);
    });
  });

  // ── Wake-word switch (local state) ─────────────────────────────────────────

  group('wake-word switch', () {
    testWidgets('starts off and can be toggled on', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      final wakeWordSwitch =
          tester.widgetList<Switch>(find.byType(Switch)).first;
      expect(wakeWordSwitch.value, isFalse);

      await tester.tap(
          find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();

      final after =
          tester.widgetList<Switch>(find.byType(Switch)).first;
      expect(after.value, isTrue);
    });

    testWidgets('toggling twice returns to false', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();

      final after =
          tester.widgetList<Switch>(find.byType(Switch)).first;
      expect(after.value, isFalse);
    });
  });

  // ── Quiet mode switch ──────────────────────────────────────────────────────

  group('quiet mode switch', () {
    testWidgets('toggling on calls notifier.set(true)', (tester) async {
      _tallSurface(tester);
      final qN = _FakeQuietNotifier(initial: false);
      await tester.pumpWidget(_app([
        apiBaseUrlProvider
            .overrideWith((_) => _FakeUrlNotifier('http://localhost:8000')),
        homeAirportProvider.overrideWith((_) => _FakeAirportNotifier()),
        quietModeProvider.overrideWith((_) => qN),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile).last);
      await tester.pumpAndSettle();

      expect(qN.lastSet, isTrue);
    });

    testWidgets('toggling off calls notifier.set(false)', (tester) async {
      _tallSurface(tester);
      final qN = _FakeQuietNotifier(initial: true);
      await tester.pumpWidget(_app([
        apiBaseUrlProvider
            .overrideWith((_) => _FakeUrlNotifier('http://localhost:8000')),
        homeAirportProvider.overrideWith((_) => _FakeAirportNotifier()),
        quietModeProvider.overrideWith((_) => qN),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile).last);
      await tester.pumpAndSettle();

      expect(qN.lastSet, isFalse);
    });

    testWidgets('switch reflects provider state after toggle', (tester) async {
      _tallSurface(tester);
      final qN = _FakeQuietNotifier(initial: false);
      await tester.pumpWidget(_app([
        apiBaseUrlProvider
            .overrideWith((_) => _FakeUrlNotifier('http://localhost:8000')),
        homeAirportProvider.overrideWith((_) => _FakeAirportNotifier()),
        quietModeProvider.overrideWith((_) => qN),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile).last);
      await tester.pumpAndSettle();

      final sw = tester.widgetList<Switch>(find.byType(Switch)).last;
      expect(sw.value, isTrue);
    });
  });

  // ── Travel profile tile ────────────────────────────────────────────────────

  group('travel profile tile', () {
    testWidgets('tile is present and tappable', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides()));
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(ListTile, 'Travel profile');
      expect(tile, findsOneWidget);

      // Tapping will throw a navigation error (no go_router in plain
      // MaterialApp) but the tile existence + onTap wiring is what we verify.
      // We just confirm it is tappable (has an onTap callback).
      final lt = tester.widget<ListTile>(tile);
      expect(lt.onTap, isNotNull);
    });
  });
}
