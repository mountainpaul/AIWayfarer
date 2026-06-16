// trip_form shows a dialog that returns a payload map via Navigator.pop.
// No provider mutations are called by the form directly.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/trips/widgets/date_range_field.dart';
import 'package:wayfarer/features/trips/widgets/trip_form.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpHost(
  WidgetTester tester, {
  Map<String, dynamic>? existing,
  required List<Map<String, dynamic>?> results,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            child: const Text('Open'),
            onPressed: () async {
              final r = await showTripForm(ctx, existing: existing);
              results.add(r);
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TripForm — create mode', () {
    testWidgets('renders New trip title with Save and Cancel buttons',
        (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, results: []);

      expect(find.text('New trip'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('renders DateRangeField with Pick dates label',
        (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, results: []);

      // DateRangeField renders as an OutlinedButton.
      expect(find.byType(DateRangeField), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      // The label defaults to 'Pick dates' in create mode when no dates are set.
      expect(find.text('Pick dates'), findsOneWidget);
    });

    testWidgets('shows Required error when name is empty on submit',
        (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, results: results);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets(
        'shows Pick a date range error and does not pop when name filled but no dates',
        (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, results: results);

      await tester.enterText(find.byType(TextFormField).first, 'Italy 2026');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Shows the dates-missing error message.
      expect(find.text('Pick a date range'), findsOneWidget);
      // Dialog still open (not popped).
      expect(results, isEmpty);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Cancel dismisses dialog and returns null', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, results: results);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.first, isNull);
    });
  });

  group('TripForm — edit mode', () {
    final existingTrip = {
      'name': 'Alps 2025',
      'start_date': '2025-07-10',
      'end_date': '2025-07-25',
    };

    testWidgets('renders Edit trip title prefilled with existing data',
        (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, existing: existingTrip, results: []);

      expect(find.text('Edit trip'), findsOneWidget);
      expect(find.text('Alps 2025'), findsOneWidget);
    });

    testWidgets('pre-filled dates render in DateRangeField button label',
        (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, existing: existingTrip, results: []);

      // DateRangeField renders "start  →  end" when dates are set.
      expect(find.textContaining('2025-07-10'), findsOneWidget);
      expect(find.textContaining('2025-07-25'), findsOneWidget);
    });

    testWidgets(
        'save in edit mode returns payload with correct name, start_date, end_date',
        (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, existing: existingTrip, results: results);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final p = results.first!;
      expect(p['name'], equals('Alps 2025'));
      expect(p['start_date'], equals('2025-07-10'));
      expect(p['end_date'], equals('2025-07-25'));
    });

    testWidgets('save with updated name returns new name and original dates',
        (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, existing: existingTrip, results: results);

      await tester.enterText(find.byType(TextFormField).first, 'Alps 2025 Updated');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final p = results.first!;
      expect(p['name'], equals('Alps 2025 Updated'));
      expect(p['start_date'], equals('2025-07-10'));
      expect(p['end_date'], equals('2025-07-25'));
    });

    testWidgets('validation fires in edit mode when name is cleared',
        (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, existing: existingTrip, results: results);

      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('Cancel in edit mode returns null', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, existing: existingTrip, results: results);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.first, isNull);
    });

    testWidgets('save returns payload with all three required keys',
        (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, existing: existingTrip, results: results);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final p = results.first!;
      expect(p.containsKey('name'), isTrue);
      expect(p.containsKey('start_date'), isTrue);
      expect(p.containsKey('end_date'), isTrue);
    });
  });
}
