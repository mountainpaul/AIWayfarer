// Tests for the LegForm dialog (showLegForm).
// The form returns a create/update payload or null when cancelled.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/trips/widgets/date_range_field.dart';
import 'package:wayfarer/features/trips/widgets/leg_form.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kTripId = 'trip-abc';
const _kSortOrder = 0;

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
              final r = await showLegForm(
                ctx,
                tripId: _kTripId,
                sortOrder: _kSortOrder,
                existing: existing,
              );
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
  group('LegForm — create mode', () {
    testWidgets('renders New leg title with Save and Cancel buttons',
        (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, results: []);

      expect(find.text('New leg'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('renders Leg name field', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, results: []);

      expect(find.widgetWithText(TextFormField, 'Leg name'), findsOneWidget);
    });

    testWidgets('renders Pick dates DateRangeField', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, results: []);

      expect(find.byType(DateRangeField), findsOneWidget);
      expect(find.text('Pick dates'), findsOneWidget);
    });

    testWidgets('renders Places (optional) field', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, results: []);

      expect(find.widgetWithText(TextFormField, 'Places (optional)'),
          findsOneWidget);
    });

    testWidgets('renders Schengen area switch', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, results: []);

      expect(find.text('Schengen area'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('renders Notes (optional) field', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, results: []);

      expect(find.widgetWithText(TextFormField, 'Notes (optional)'),
          findsOneWidget);
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

      await tester.enterText(find.byType(TextFormField).first, 'Italy');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Pick a date range'), findsOneWidget);
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

  group('LegForm — edit mode', () {
    final existingLeg = {
      'name': 'Italy',
      'start_date': '2026-06-23',
      'end_date': '2026-06-24',
      'is_schengen': true,
      'places': 'Rome, Florence',
      'notes': 'Amazing food',
    };

    testWidgets('renders Edit leg title', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, existing: existingLeg, results: []);

      expect(find.text('Edit leg'), findsOneWidget);
    });

    testWidgets('pre-fills name from existing', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, existing: existingLeg, results: []);

      expect(find.text('Italy'), findsOneWidget);
    });

    testWidgets('pre-fills dates in DateRangeField', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, existing: existingLeg, results: []);

      expect(find.textContaining('2026-06-23'), findsOneWidget);
      expect(find.textContaining('2026-06-24'), findsOneWidget);
    });

    testWidgets('submit returns correct payload with all required fields',
        (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, existing: existingLeg, results: results);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final p = results.first!;
      expect(p['trip_id'], equals(_kTripId));
      expect(p['name'], equals('Italy'));
      expect(p['start_date'], equals('2026-06-23'));
      expect(p['end_date'], equals('2026-06-24'));
      expect(p['is_schengen'], isTrue);
      expect(p['sort_order'], equals(_kSortOrder));
    });

    testWidgets('submit includes places when filled', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, existing: existingLeg, results: results);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final p = results.first!;
      expect(p['places'], equals('Rome, Florence'));
    });

    testWidgets('submit includes notes when filled', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, existing: existingLeg, results: results);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final p = results.first!;
      expect(p['notes'], equals('Amazing food'));
    });

    testWidgets('submit omits places when empty', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      final noPlaces = Map<String, dynamic>.from(existingLeg)
        ..remove('places');
      await _pumpHost(tester, existing: noPlaces, results: results);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final p = results.first!;
      expect(p.containsKey('places'), isFalse);
    });

    testWidgets('submit omits notes when empty', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      final noNotes = Map<String, dynamic>.from(existingLeg)..remove('notes');
      await _pumpHost(tester, existing: noNotes, results: results);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final p = results.first!;
      expect(p.containsKey('notes'), isFalse);
    });

    testWidgets('toggling Schengen switch reflects false in payload',
        (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, existing: existingLeg, results: results);

      // Existing has is_schengen: true; toggle it off.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final p = results.first!;
      expect(p['is_schengen'], isFalse);
    });

    testWidgets('toggling Schengen switch reflects true in payload when started false',
        (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      final noSchengen = Map<String, dynamic>.from(existingLeg)
        ..['is_schengen'] = false;
      await _pumpHost(tester, existing: noSchengen, results: results);

      // Toggle it on.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final p = results.first!;
      expect(p['is_schengen'], isTrue);
    });

    testWidgets('Cancel in edit mode returns null', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, existing: existingLeg, results: results);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.first, isNull);
    });
  });
}
