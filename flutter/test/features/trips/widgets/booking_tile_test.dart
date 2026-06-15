import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/trips/widgets/booking_tile.dart';
import 'package:wayfarer/models/booking.dart';
import 'package:wayfarer/providers/trip_provider.dart';

// ---------------------------------------------------------------------------
// Fake TripMutations — records calls, returns configurable result.
// ---------------------------------------------------------------------------
class _FakeMutations extends TripMutations {
  _FakeMutations() : super(_fakeRef);

  // We never actually call super methods; track calls instead.
  static final _fakeRef = _NullRef();

  String? deletedBookingId;
  String? updatedBookingId;
  Map<String, dynamic>? updatedBookingPatch;
  bool returnValue = true;

  @override
  Future<bool> deleteBooking(String id) async {
    deletedBookingId = id;
    return returnValue;
  }

  @override
  Future<bool> updateBooking(String id, Map<String, dynamic> patch) async {
    updatedBookingId = id;
    updatedBookingPatch = patch;
    return returnValue;
  }
}

// Minimal Ref stub — TripMutations only uses it via super; _FakeMutations
// overrides every method we call, so _NullRef is never actually invoked.
class _NullRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const _flightBooking = Booking(
  id: 'bk-1',
  legId: 'leg-1',
  type: 'flight',
  name: 'JAL 001',
  status: 'booked',
  startDate: '2026-09-01',
  endDate: '2026-09-02',
  confirmation: 'ABC123',
  costCents: 85000,
  currency: 'USD',
  locationName: 'Narita Airport',
);

const _hotelBooking = Booking(
  id: 'bk-2',
  legId: 'leg-1',
  type: 'hotel',
  name: 'Park Hyatt',
  status: 'pending',
);

const _rifugioBooking = Booking(
  id: 'bk-3',
  legId: 'leg-1',
  type: 'rifugio',
  name: 'Rifugio Scarpa',
  status: 'needs_booking',
);

const _ferryBooking = Booking(
  id: 'bk-4',
  legId: 'leg-1',
  type: 'ferry',
  name: 'Corfu Ferry',
  status: 'researching',
);

const _carBooking = Booking(
  id: 'bk-5',
  legId: 'leg-1',
  type: 'car',
  name: 'Hertz Rental',
  status: 'booked',
);

const _trainBooking = Booking(
  id: 'bk-6',
  legId: 'leg-1',
  type: 'train',
  name: 'Shinkansen',
  status: 'booked',
);

const _activityBooking = Booking(
  id: 'bk-7',
  legId: 'leg-1',
  type: 'activity',
  name: 'Tea Ceremony',
  status: 'booked',
);

const _unknownTypeBooking = Booking(
  id: 'bk-8',
  legId: 'leg-1',
  type: 'other',
  name: 'Mystery',
  status: 'booked',
);

Widget _wrap(Booking booking, {TripMutations? mutations}) {
  return ProviderScope(
    overrides: [
      if (mutations != null)
        tripMutationsProvider.overrideWithValue(mutations),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: BookingTile(booking: booking),
      ),
    ),
  );
}

void main() {
  group('BookingTile', () {
    // ── Rendering ────────────────────────────────────────────────────────────

    testWidgets('renders booking name', (tester) async {
      await tester.pumpWidget(_wrap(_flightBooking));
      expect(find.text('JAL 001'), findsOneWidget);
    });

    testWidgets('renders start and end dates', (tester) async {
      await tester.pumpWidget(_wrap(_flightBooking));
      expect(find.textContaining('2026-09-01'), findsOneWidget);
      expect(find.textContaining('2026-09-02'), findsOneWidget);
    });

    testWidgets('renders location name when present', (tester) async {
      await tester.pumpWidget(_wrap(_flightBooking));
      expect(find.text('Narita Airport'), findsOneWidget);
    });

    testWidgets('hides location when absent', (tester) async {
      await tester.pumpWidget(_wrap(_hotelBooking));
      // No locationName set on hotelBooking — should not crash or show noise.
      expect(find.text('Park Hyatt'), findsOneWidget);
    });

    testWidgets('renders confirmation number when present', (tester) async {
      await tester.pumpWidget(_wrap(_flightBooking));
      expect(find.textContaining('ABC123'), findsOneWidget);
    });

    testWidgets('renders status label', (tester) async {
      await tester.pumpWidget(_wrap(_flightBooking));
      expect(find.text('booked'), findsOneWidget);
    });

    testWidgets('renders formattedCost when costCents is set', (tester) async {
      await tester.pumpWidget(_wrap(_flightBooking));
      // $850.00 — just verify the dollar sign and amount fragment exist.
      expect(find.textContaining(r'$'), findsOneWidget);
      expect(find.textContaining('850'), findsOneWidget);
    });

    testWidgets('hides cost when costCents is null', (tester) async {
      await tester.pumpWidget(_wrap(_hotelBooking));
      expect(find.textContaining(r'$'), findsNothing);
    });

    // ── Icons for each booking type ─────────────────────────────────────────

    testWidgets('flight type shows flight icon', (tester) async {
      await tester.pumpWidget(_wrap(_flightBooking));
      expect(find.byIcon(Icons.flight), findsOneWidget);
    });

    testWidgets('hotel type shows hotel icon', (tester) async {
      await tester.pumpWidget(_wrap(_hotelBooking));
      expect(find.byIcon(Icons.hotel), findsOneWidget);
    });

    testWidgets('rifugio type shows hotel icon', (tester) async {
      await tester.pumpWidget(_wrap(_rifugioBooking));
      expect(find.byIcon(Icons.hotel), findsOneWidget);
    });

    testWidgets('ferry type shows boat icon', (tester) async {
      await tester.pumpWidget(_wrap(_ferryBooking));
      expect(find.byIcon(Icons.directions_boat), findsOneWidget);
    });

    testWidgets('car type shows car icon', (tester) async {
      await tester.pumpWidget(_wrap(_carBooking));
      expect(find.byIcon(Icons.directions_car), findsOneWidget);
    });

    testWidgets('train type shows train icon', (tester) async {
      await tester.pumpWidget(_wrap(_trainBooking));
      expect(find.byIcon(Icons.train), findsOneWidget);
    });

    testWidgets('activity type shows attractions icon', (tester) async {
      await tester.pumpWidget(_wrap(_activityBooking));
      expect(find.byIcon(Icons.attractions), findsOneWidget);
    });

    testWidgets('unknown type shows bookmark icon', (tester) async {
      await tester.pumpWidget(_wrap(_unknownTypeBooking));
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    // ── Status colours (via coloured chip container) ─────────────────────────
    // We assert the status text renders (colour is internal; structural checks
    // via text are the reliable cross-platform approach).

    testWidgets('pending status renders pending text', (tester) async {
      await tester.pumpWidget(_wrap(_hotelBooking));
      expect(find.text('pending'), findsOneWidget);
    });

    testWidgets('needs_booking status renders text', (tester) async {
      await tester.pumpWidget(_wrap(_rifugioBooking));
      expect(find.text('needs_booking'), findsOneWidget);
    });

    testWidgets('researching status renders text', (tester) async {
      await tester.pumpWidget(_wrap(_ferryBooking));
      expect(find.text('researching'), findsOneWidget);
    });

    // ── Popup menu ───────────────────────────────────────────────────────────

    testWidgets('popup menu shows Edit and Delete options', (tester) async {
      await tester.pumpWidget(_wrap(_flightBooking));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    // ── Delete flow ──────────────────────────────────────────────────────────

    testWidgets('delete: confirm dialog appears and cancel aborts', (tester) async {
      final mutations = _FakeMutations();
      await tester.pumpWidget(_wrap(_flightBooking, mutations: mutations));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Dialog should be visible.
      expect(find.text('Delete booking?'), findsOneWidget);
      expect(find.textContaining('"JAL 001"'), findsOneWidget);

      // Cancel — mutation should NOT be called.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(mutations.deletedBookingId, isNull);
    });

    testWidgets('delete: confirming calls deleteBooking with booking id',
        (tester) async {
      final mutations = _FakeMutations();
      await tester.pumpWidget(_wrap(_flightBooking, mutations: mutations));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete').last); // the FilledButton
      await tester.pumpAndSettle();

      expect(mutations.deletedBookingId, 'bk-1');
    });

    testWidgets('delete failure shows snackbar', (tester) async {
      final mutations = _FakeMutations()..returnValue = false;
      await tester.pumpWidget(_wrap(_flightBooking, mutations: mutations));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('Failed to delete booking'), findsOneWidget);
    });

    // ── No date line rendered when both dates absent ─────────────────────────

    testWidgets('hides date line when both dates are absent', (tester) async {
      await tester.pumpWidget(_wrap(_hotelBooking));
      // No arrow sequence should be present.
      expect(find.textContaining('->'), findsNothing);
    });
  });
}
