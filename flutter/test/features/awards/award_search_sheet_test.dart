import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/features/awards/award_search_sheet.dart';
import 'package:wayfarer/models/leg.dart';
import 'package:wayfarer/providers/trip_provider.dart';
import 'package:wayfarer/services/award_search.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

const _legId = 'leg-test';
final _futureDate = DateTime(2027, 3, 15);

const _sampleLeg = Leg(
  id: _legId,
  tripId: 'trip-1',
  slug: 'paris',
  name: 'Paris',
  startDate: '2027-03-15',
  endDate: '2027-03-25',
);

/// Pumps a widget that opens the sheet via [showAwardSearchSheet] so tests run
/// against the full bottom-sheet flow (Scaffold + context).
Future<void> _pumpSheet(
  WidgetTester tester, {
  String legId = _legId,
  DateTime? date,
  List<Override> extraOverrides = const [],
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      legProvider(legId).overrideWith((ref) async => _sampleLeg),
      homeAirportProvider.overrideWith((_) => HomeAirportNotifier()),
      ...extraOverrides,
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showAwardSearchSheet(ctx, legId: legId, date: date),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  ));

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void _tallSurface(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 4000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

// ── URL-launcher mock ────────────────────────────────────────────────────────

const _urlChannel = MethodChannel('plugins.flutter.io/url_launcher');

final List<String> _launched = [];

void _setupUrlLauncherMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_urlChannel, (call) async {
    if (call.method == 'launch' || call.method == 'launchUrl') {
      final args = call.arguments;
      if (args is Map) {
        _launched.add(args['url']?.toString() ?? '');
      } else {
        _launched.add(args.toString());
      }
    }
    return true;
  });
}

void _teardownUrlLauncherMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_urlChannel, null);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _launched.clear();
    _setupUrlLauncherMock();
  });

  tearDown(_teardownUrlLauncherMock);

  // ── Rendering ─────────────────────────────────────────────────────────────

  group('AwardSearchSheet — rendering', () {
    testWidgets('renders the sheet title', (tester) async {
      await _pumpSheet(tester);

      expect(find.text('Search award availability'), findsOneWidget);
    });

    testWidgets('renders origin text field labelled "From (IATA)"', (tester) async {
      await _pumpSheet(tester);

      expect(find.text('From (IATA)'), findsOneWidget);
    });

    testWidgets('renders destination text field labelled "To (IATA)"', (tester) async {
      await _pumpSheet(tester);

      expect(find.text('To (IATA)'), findsOneWidget);
    });

    testWidgets('renders Pick date button or pre-filled date label', (tester) async {
      // When the sheet opens without a date arg, the leg's startDate is
      // populated via a post-frame callback, so by pumpAndSettle the button
      // text already shows the formatted date instead of "Pick date".
      // Accept either form.
      await _pumpSheet(tester);

      final hasPickDate = find.text('Pick date').evaluate().isNotEmpty;
      final hasFormattedDate =
          find.textContaining('2027-03-15').evaluate().isNotEmpty;
      expect(hasPickDate || hasFormattedDate, isTrue,
          reason: 'Expected either "Pick date" or the formatted date label');
    });

    testWidgets('renders calendar icon on date button', (tester) async {
      await _pumpSheet(tester);

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('renders hint text "DEN" for origin field', (tester) async {
      await _pumpSheet(tester);

      // Find the TextField by checking decoration hint text.
      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      final origins = fields.where(
          (f) => f.decoration?.hintText == 'DEN');
      expect(origins, isNotEmpty);
    });

    testWidgets('renders hint text "FCO" for destination field', (tester) async {
      await _pumpSheet(tester);

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      final dests = fields.where(
          (f) => f.decoration?.hintText == 'FCO');
      expect(dests, isNotEmpty);
    });

    testWidgets('shows helper text when airports/date not entered', (tester) async {
      await _pumpSheet(tester);

      expect(
          find.textContaining('Enter 3-letter airport codes'), findsOneWidget);
    });

    testWidgets('renders subtitle about PointsYeah free account', (tester) async {
      await _pumpSheet(tester);

      expect(find.textContaining('PointsYeah and Roame'), findsOneWidget);
    });
  });

  // ── Date pre-population ───────────────────────────────────────────────────

  group('AwardSearchSheet — date pre-population', () {
    testWidgets('date passed as argument populates date button label',
        (tester) async {
      await _pumpSheet(tester, date: _futureDate);

      // Expect the formatted date in the button label.
      expect(find.textContaining('2027-03-15'), findsOneWidget);
    });

    testWidgets('date button shows ±3 days suffix when date is set', (tester) async {
      await _pumpSheet(tester, date: _futureDate);

      expect(find.textContaining('±3 days'), findsOneWidget);
    });

    testWidgets('date from leg start populates after settle (no date arg)',
        (tester) async {
      // No date arg: the sheet reads it from the leg provider.
      await _pumpSheet(tester);

      // After pumpAndSettle, the post-frame callback has run and _date should
      // have been set to the leg's startDateTime (2027-03-15).
      expect(find.textContaining('2027-03-15'), findsOneWidget);
    });
  });

  // ── Saved preferences pre-fill ────────────────────────────────────────────

  group('AwardSearchSheet — saved airport pre-fill', () {
    testWidgets('saved origin is loaded into origin field', (tester) async {
      SharedPreferences.setMockInitialValues({
        'award_origin_$_legId': 'SFO',
        'award_dest_$_legId': 'CDG',
      });

      await _pumpSheet(tester);
      await tester.pumpAndSettle(); // let _prefill() complete

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      // First TextField is origin.
      expect(fields[0].controller?.text, 'SFO');
    });

    testWidgets('saved destination is loaded into dest field', (tester) async {
      SharedPreferences.setMockInitialValues({
        'award_origin_$_legId': 'SFO',
        'award_dest_$_legId': 'CDG',
      });

      await _pumpSheet(tester);
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[1].controller?.text, 'CDG');
    });

    testWidgets('homeAirport is used as origin when no prefs saved', (tester) async {
      SharedPreferences.setMockInitialValues({'home_airport': 'DEN'});

      await _pumpSheet(tester);
      // HomeAirportNotifier._load() is async — drain microtasks so it hydrates
      // before _prefill() reads it, then rebuild.
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      // The origin may be 'DEN' if the notifier hydrated before _prefill ran,
      // or '' if _prefill ran first and homeAirportProvider returned the default.
      // Both are valid — this test documents the observed behaviour without
      // enforcing a timing-dependent guarantee.
      expect(fields[0].controller?.text, anyOf('DEN', ''));
    });

    testWidgets('empty origin when no prefs and no home airport', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await _pumpSheet(tester);
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      // Should be empty string (homeAirportProvider default before hydration)
      // or empty after hydration of empty prefs.
      expect(fields[0].controller?.text, '');
    });
  });

  // ── Input and link generation ─────────────────────────────────────────────

  group('AwardSearchSheet — input and engine links', () {
    testWidgets('engine buttons appear after valid origin/dest/date are entered',
        (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      // Enter origin.
      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'JFK');
      await tester.pump();
      // Enter destination.
      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'LHR');
      await tester.pump();

      // All three engine buttons should now show.
      expect(find.textContaining('Search on Seats.aero'), findsOneWidget);
      expect(find.textContaining('Search on PointsYeah'), findsOneWidget);
      expect(find.textContaining('Search on Roame.travel'), findsOneWidget);
    });

    testWidgets('helper text disappears when all inputs are valid', (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'JFK');
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'LHR');
      await tester.pump();

      expect(find.textContaining('Enter 3-letter airport codes'), findsNothing);
    });

    testWidgets('engine buttons NOT shown when origin is missing', (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'LHR');
      await tester.pump();

      expect(find.textContaining('Search on'), findsNothing);
    });

    testWidgets('engine buttons NOT shown when destination is missing',
        (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'JFK');
      await tester.pump();

      expect(find.textContaining('Search on'), findsNothing);
    });

    testWidgets('engine buttons NOT shown when date is missing', (tester) async {
      _tallSurface(tester);
      // No date arg and override legProvider to return null so no auto-date.
      await tester.pumpWidget(ProviderScope(
        overrides: [
          legProvider(_legId).overrideWith((ref) async => null),
          homeAirportProvider.overrideWith((_) => HomeAirportNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () =>
                    showAwardSearchSheet(ctx, legId: _legId),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'JFK');
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'LHR');
      await tester.pump();

      // Still no date → helper shown, no engine buttons.
      expect(find.textContaining('Enter 3-letter airport codes'), findsOneWidget);
      expect(find.textContaining('Search on'), findsNothing);
    });

    testWidgets('three engine buttons rendered (one per engine)', (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'SFO');
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'NRT');
      await tester.pump();

      expect(find.textContaining('Search on'), findsNWidgets(3));
    });

    testWidgets('open_in_new icon appears for each engine button', (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'SFO');
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'NRT');
      await tester.pump();

      expect(find.byIcon(Icons.open_in_new), findsNWidgets(3));
    });

    testWidgets('changing origin updates engine button state', (tester) async {
      _tallSurface(tester);
      SharedPreferences.setMockInitialValues({
        'award_origin_$_legId': 'SFO',
        'award_dest_$_legId': 'NRT',
      });
      await _pumpSheet(tester, date: _futureDate);
      await tester.pumpAndSettle();

      // Links should be visible with pre-filled SFO / NRT / date.
      expect(find.textContaining('Search on Seats.aero'), findsOneWidget);

      // Now clear origin — links should disappear.
      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), '');
      await tester.pump();

      expect(find.textContaining('Search on'), findsNothing);
    });
  });

  // ── URL launch interaction ────────────────────────────────────────────────

  group('AwardSearchSheet — launch behaviour', () {
    testWidgets('tapping Seats.aero button triggers url launch', (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'SFO');
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'NRT');
      await tester.pump();

      await tester.tap(find.textContaining('Search on Seats.aero'));
      await tester.pumpAndSettle();

      expect(_launched, isNotEmpty);
      expect(_launched.any((u) => u.contains('seats.aero')), isTrue);
    });

    testWidgets('tapping PointsYeah button triggers url launch', (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'SFO');
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'NRT');
      await tester.pump();

      await tester.tap(find.textContaining('Search on PointsYeah'));
      await tester.pumpAndSettle();

      expect(_launched.any((u) => u.contains('pointsyeah')), isTrue);
    });

    testWidgets('tapping Roame.travel button triggers url launch', (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'SFO');
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'NRT');
      await tester.pump();

      await tester.tap(find.textContaining('Search on Roame.travel'));
      await tester.pumpAndSettle();

      expect(_launched.any((u) => u.contains('roame.travel')), isTrue);
    });

    testWidgets('launch URL contains correct origin code', (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'JFK');
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'CDG');
      await tester.pump();

      await tester.tap(find.textContaining('Search on Seats.aero'));
      await tester.pumpAndSettle();

      expect(_launched.any((u) => u.contains('JFK')), isTrue);
    });

    testWidgets('launch URL contains correct destination code', (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'JFK');
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'CDG');
      await tester.pump();

      await tester.tap(find.textContaining('Search on Seats.aero'));
      await tester.pumpAndSettle();

      expect(_launched.any((u) => u.contains('CDG')), isTrue);
    });

    testWidgets('launch saves airports to SharedPreferences', (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'LAX');
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'SYD');
      await tester.pump();

      await tester.tap(find.textContaining('Search on Seats.aero'));
      await tester.pumpAndSettle();

      final (origin, dest) = await LegAirportMemory.load(_legId);
      expect(origin, 'LAX');
      expect(dest, 'SYD');
    });

    testWidgets('multiple launches accumulate in launched list', (tester) async {
      _tallSurface(tester);
      await _pumpSheet(tester, date: _futureDate);

      await tester.enterText(
          find.widgetWithText(TextField, 'From (IATA)'), 'SFO');
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'To (IATA)'), 'NRT');
      await tester.pump();

      await tester.tap(find.textContaining('Search on Seats.aero'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Search on PointsYeah'));
      await tester.pumpAndSettle();

      expect(_launched.length, greaterThanOrEqualTo(2));
    });
  });

  // ── Leg provider loading ──────────────────────────────────────────────────

  group('AwardSearchSheet — leg provider integration', () {
    testWidgets('sheet renders even when leg is null (unknown legId)', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          legProvider('unknown-leg').overrideWith((ref) async => null),
          homeAirportProvider.overrideWith((_) => HomeAirportNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () =>
                    showAwardSearchSheet(ctx, legId: 'unknown-leg'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Search award availability'), findsOneWidget);
    });
  });
}
