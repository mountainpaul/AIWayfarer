// Tests for showPackingForm dialog.
// Verifies: field rendering, required-name validation, payload on submit,
// category dropdown changes reflected in the returned map.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/trips/widgets/packing_form.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kTripId = 'trip-form-test';

void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pump a host widget with an [ElevatedButton] that opens the packing form
/// and collects every returned value into [results].
Future<void> _pumpHost(
  WidgetTester tester, {
  required List<Map<String, dynamic>?> results,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            child: const Text('Open'),
            onPressed: () async {
              final r = await showPackingForm(ctx, tripId: _kTripId);
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
  group('PackingForm', () {
    group('rendering', () {
      testWidgets('renders "Add packing item" title', (tester) async {
        _tallSurface(tester);
        await _pumpHost(tester, results: []);

        expect(find.text('Add packing item'), findsOneWidget);
      });

      testWidgets('renders Item TextFormField', (tester) async {
        _tallSurface(tester);
        await _pumpHost(tester, results: []);

        expect(find.widgetWithText(TextFormField, 'Item'), findsOneWidget);
      });

      testWidgets('renders Category DropdownButtonFormField', (tester) async {
        _tallSurface(tester);
        await _pumpHost(tester, results: []);

        // The label is shown via InputDecoration(labelText: 'Category')
        expect(find.text('Category'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      });

      testWidgets('renders Cancel and Add buttons', (tester) async {
        _tallSurface(tester);
        await _pumpHost(tester, results: []);

        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Add'), findsOneWidget);
      });
    });

    group('validation', () {
      testWidgets('shows Required error when name is empty on submit',
          (tester) async {
        _tallSurface(tester);
        final results = <Map<String, dynamic>?>[];
        await _pumpHost(tester, results: results);

        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        expect(find.text('Required'), findsOneWidget);
        expect(results, isEmpty);
      });

      testWidgets('dialog stays open when name is empty on submit',
          (tester) async {
        _tallSurface(tester);
        final results = <Map<String, dynamic>?>[];
        await _pumpHost(tester, results: results);

        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        // Dialog still visible (Add button is still present).
        expect(find.text('Add'), findsOneWidget);
        expect(results, isEmpty);
      });
    });

    group('submit', () {
      testWidgets('submit returns {trip_id, name, category} with default category',
          (tester) async {
        _tallSurface(tester);
        final results = <Map<String, dynamic>?>[];
        await _pumpHost(tester, results: results);

        await tester.enterText(
            find.widgetWithText(TextFormField, 'Item'), 'Rain jacket');
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        expect(results, hasLength(1));
        final payload = results.first!;
        expect(payload['trip_id'], equals(_kTripId));
        expect(payload['name'], equals('Rain jacket'));
        expect(payload['category'], equals('misc')); // default
      });

      testWidgets('Cancel returns null without adding to results', (tester) async {
        _tallSurface(tester);
        final results = <Map<String, dynamic>?>[];
        await _pumpHost(tester, results: results);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(results, hasLength(1));
        expect(results.first, isNull);
      });
    });

    group('category dropdown', () {
      testWidgets('changing category is reflected in the returned payload',
          (tester) async {
        _tallSurface(tester);
        final results = <Map<String, dynamic>?>[];
        await _pumpHost(tester, results: results);

        // Enter a name.
        await tester.enterText(
            find.widgetWithText(TextFormField, 'Item'), 'Tent');

        // Open the dropdown and pick 'gear'.
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('gear').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        expect(results, hasLength(1));
        expect(results.first!['category'], equals('gear'));
      });

      testWidgets('changing category to clothing is reflected in payload',
          (tester) async {
        _tallSurface(tester);
        final results = <Map<String, dynamic>?>[];
        await _pumpHost(tester, results: results);

        await tester.enterText(
            find.widgetWithText(TextFormField, 'Item'), 'T-shirt');

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('clothing').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        expect(results.first!['category'], equals('clothing'));
      });
    });
  });
}
