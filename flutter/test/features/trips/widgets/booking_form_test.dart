// These forms return a payload via Navigator.pop — no provider mutations are
// invoked by the form itself. We wrap in a minimal MaterialApp + Scaffold and
// collect the dialog result via showBookingForm().

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/trips/widgets/booking_form.dart';
import 'package:wayfarer/models/booking.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps a host Scaffold with one button that opens the booking dialog.
/// The dialog result (payload or null) is appended to [results].
Future<void> _pumpHost(
  WidgetTester tester, {
  required String legId,
  Booking? existing,
  required List<Map<String, dynamic>?> results,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            child: const Text('Open'),
            onPressed: () async {
              final r = await showBookingForm(ctx, legId: legId, existing: existing);
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
  group('BookingForm — create mode', () {
    testWidgets('renders New Booking title and Create / Cancel buttons', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, legId: 'leg1', results: []);

      expect(find.text('New Booking'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('shows Required error when name is empty on submit', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', results: results);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
      // Dialog still open — no payload.
      expect(results, isEmpty);
    });

    testWidgets('submitting a valid name returns payload with leg_id and name', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg-42', results: results);

      await tester.enterText(find.byType(TextFormField).first, 'Hotel Roma');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final payload = results.first!;
      expect(payload['leg_id'], equals('leg-42'));
      expect(payload['name'], equals('Hotel Roma'));
      expect(payload['type'], isA<String>());
      expect(payload['status'], isA<String>());
    });

    testWidgets('location and notes are absent from payload when left blank', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', results: results);

      await tester.enterText(find.byType(TextFormField).first, 'My Booking');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final p = results.first!;
      expect(p.containsKey('location_name'), isFalse);
      expect(p.containsKey('notes'), isFalse);
    });

    testWidgets('location and notes appear in payload when filled', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', results: results);

      final fields = find.byType(TextFormField);
      // fields: 0=Name, 1=Location, 2=Notes
      await tester.enterText(fields.at(0), 'My Hotel');
      await tester.enterText(fields.at(1), 'Rome, Italy');
      await tester.enterText(fields.at(2), 'Quiet floor please');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final p = results.first!;
      expect(p['location_name'], equals('Rome, Italy'));
      expect(p['notes'], equals('Quiet floor please'));
    });

    testWidgets('Cancel dismisses dialog and returns null', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', results: results);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.first, isNull);
    });

    testWidgets('default type is hotel — award button absent', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, legId: 'leg1', results: []);
      // Default type is hotel, so award button must NOT appear.
      expect(find.text('Check award availability'), findsNothing);
    });

    testWidgets('award button appears after changing type to flight', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, legId: 'leg1', results: []);

      // Tap the Type dropdown (first DropdownButtonFormField).
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      // 'flight' appears multiple times in menu; tap the last (in overlay).
      await tester.tap(find.text('flight').last);
      await tester.pumpAndSettle();

      // Default status is needs_booking — award button should now appear.
      expect(find.text('Check award availability'), findsOneWidget);
    });
  });

  group('BookingForm — edit mode', () {
    const existingBooking = Booking(
      id: 'b-1',
      legId: 'leg1',
      type: 'hotel',
      name: 'Grand Hotel',
      status: 'booked',
      locationName: 'Milan',
      notes: 'Late check-in',
      startDate: '2026-09-01',
      endDate: '2026-09-05',
    );

    testWidgets('renders Edit Booking title prefilled with existing values', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, legId: 'leg1', existing: existingBooking, results: []);

      expect(find.text('Edit Booking'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Grand Hotel'), findsOneWidget);
      expect(find.text('Milan'), findsOneWidget);
      expect(find.text('Late check-in'), findsOneWidget);
      expect(find.text('2026-09-01'), findsOneWidget);
      expect(find.text('2026-09-05'), findsOneWidget);
    });

    testWidgets('editing the name produces an updated payload', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', existing: existingBooking, results: results);

      await tester.enterText(find.byType(TextFormField).first, 'Updated Hotel');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final p = results.first!;
      expect(p['name'], equals('Updated Hotel'));
      expect(p['location_name'], equals('Milan'));
      expect(p['notes'], equals('Late check-in'));
      expect(p['start_date'], equals('2026-09-01'));
      expect(p['end_date'], equals('2026-09-05'));
    });

    testWidgets('validation fires in edit mode when name is cleared', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', existing: existingBooking, results: results);

      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('award button absent for hotel status booked in edit mode', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, legId: 'leg1', existing: existingBooking, results: []);
      // type=hotel, so award button must not appear regardless of status.
      expect(find.text('Check award availability'), findsNothing);
    });
  });
}
