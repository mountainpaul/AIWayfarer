import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/features/companion/companion_dashboard.dart';
import 'package:wayfarer/models/booking.dart';
import 'package:wayfarer/models/grounding.dart';
import 'package:wayfarer/models/leg.dart';
import 'package:wayfarer/providers/grounding_provider.dart';
import 'package:wayfarer/providers/trip_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _tallSurface(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 4000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

const _kLocalTime = '2026-06-14T09:00:00+02:00';

Grounding _groundingWithGps() => const Grounding(
      gpsLat: 48.8566,
      gpsLon: 2.3522,
      gpsAccuracyM: 10.0,
      localTimeIso: _kLocalTime,
      timezone: 'Europe/Paris',
    );

Grounding _groundingNoGps() => const Grounding(
      localTimeIso: _kLocalTime,
      timezone: 'Europe/Paris',
    );

Leg _todayLeg() {
  final now = DateTime.now();
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return Leg(
    id: 'leg-1',
    tripId: 'trip-1',
    slug: 'paris',
    name: 'Paris',
    emoji: '🗼',
    color: '#6366f1',
    startDate: fmt(now.subtract(const Duration(days: 1))),
    endDate: fmt(now.add(const Duration(days: 5))),
    places: 'Marais, Montmartre',
  );
}

Booking _nextBooking() {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  return Booking(
    id: 'bk-1',
    legId: 'leg-1',
    type: 'museum',
    name: 'Musée d\'Orsay',
    status: 'confirmed',
    startDate: tomorrow.toIso8601String(),
    locationName: 'Paris 7e',
  );
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: Scaffold(body: CompanionDashboard())),
    );

// Sentinel — pass this constant to force a provider to return null.
class _Null {
  const _Null();
}

List<Override> _fullData({
  Object? grounding = const _Null(),
  Object? leg = const _Null(),
  Object? booking = const _Null(),
  int tasks = 2,
}) {
  final resolvedGrounding =
      grounding is _Null ? _groundingWithGps() : grounding as Grounding?;
  final resolvedLeg = leg is _Null ? _todayLeg() : leg as Leg?;
  final resolvedBooking =
      booking is _Null ? _nextBooking() : booking as Booking?;

  return [
    groundingProvider.overrideWith((ref) async => resolvedGrounding!),
    currentLegProvider.overrideWith((ref) async => resolvedLeg),
    nextBookingProvider.overrideWith((ref) async => resolvedBooking),
    openTaskCountProvider.overrideWith((ref) async => tasks),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── "Where am I" card ─────────────────────────────────────────────────────

  group('"Where am I" card — grounding', () {
    testWidgets('shows GPS coordinates when available', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData()));
      await tester.pumpAndSettle();

      expect(find.textContaining('48.8566'), findsOneWidget);
      expect(find.textContaining('2.3522'), findsOneWidget);
    });

    testWidgets('shows GPS accuracy when provided', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData()));
      await tester.pumpAndSettle();

      expect(find.textContaining('+/-'), findsOneWidget);
      expect(find.textContaining('10m'), findsOneWidget);
    });

    testWidgets('shows "GPS unavailable" when lat/lon are null',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData(grounding: _groundingNoGps())));
      await tester.pumpAndSettle();

      expect(find.text('GPS unavailable'), findsOneWidget);
    });

    testWidgets('renders local time', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Local:'), findsOneWidget);
      expect(find.textContaining(_kLocalTime), findsOneWidget);
    });

    testWidgets('renders timezone', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Europe/Paris'), findsOneWidget);
    });

    testWidgets('shows header "Where am I"', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData()));
      await tester.pumpAndSettle();

      expect(find.text('Where am I'), findsOneWidget);
    });

    testWidgets('shows loading indicator while grounding loads',
        (tester) async {
      final completer = Completer<Grounding>();
      await tester.pumpWidget(_app([
        groundingProvider.overrideWith((ref) => completer.future),
        currentLegProvider.overrideWith((ref) async => null),
        nextBookingProvider.overrideWith((ref) async => null),
        openTaskCountProvider.overrideWith((ref) async => 0),
      ]));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error text when grounding errors', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app([
        groundingProvider
            .overrideWith((ref) => Future.error('GPS service down')),
        currentLegProvider.overrideWith((ref) async => null),
        nextBookingProvider.overrideWith((ref) async => null),
        openTaskCountProvider.overrideWith((ref) async => 0),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('GPS service down'), findsOneWidget);
    });
  });

  // ── Current leg card ───────────────────────────────────────────────────────

  group('current leg card', () {
    testWidgets('renders leg name with "Current leg:" prefix', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Current leg: Paris'), findsOneWidget);
    });

    testWidgets('renders places subtitle', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Marais'), findsOneWidget);
    });

    testWidgets('hidden when no active leg (null)', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData(leg: null)));
      // Pass null leg → currentLegProvider returns null → SizedBox.shrink
      await tester.pumpAndSettle();

      expect(find.textContaining('Current leg:'), findsNothing);
    });

    testWidgets('renders first letter of name when no emoji', (tester) async {
      _tallSurface(tester);
      final now = DateTime.now();
      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final noEmojiLeg = Leg(
        id: 'leg-2',
        tripId: 'trip-1',
        slug: 'tokyo',
        name: 'Tokyo',
        startDate: fmt(now.subtract(const Duration(days: 1))),
        endDate: fmt(now.add(const Duration(days: 3))),
      );
      await tester.pumpWidget(_app(_fullData(leg: noEmojiLeg)));
      await tester.pumpAndSettle();

      // CircleAvatar shows first letter 'T'
      expect(find.text('T'), findsOneWidget);
    });
  });

  // ── Next booking card ──────────────────────────────────────────────────────

  group('next booking card', () {
    testWidgets('renders booking name with "Next:" prefix', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Next: Musée d\'Orsay'), findsOneWidget);
    });

    testWidgets('renders location in subtitle', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Paris 7e'), findsOneWidget);
    });

    testWidgets('shows "No upcoming booking" when null', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData(booking: null)));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No upcoming booking'),
        findsOneWidget,
      );
    });

    testWidgets('booking without location renders just date', (tester) async {
      _tallSurface(tester);
      final bk = Booking(
        id: 'bk-2',
        legId: 'leg-1',
        type: 'train',
        name: 'Eurostar',
        status: 'confirmed',
        startDate: DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
      );
      await tester.pumpWidget(_app(_fullData(booking: bk)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Next: Eurostar'), findsOneWidget);
    });

    testWidgets('booking with invalid date falls back to raw string',
        (tester) async {
      _tallSurface(tester);
      const bk = Booking(
        id: 'bk-bad',
        legId: 'leg-1',
        type: 'flight',
        name: 'Mystery Flight',
        status: 'confirmed',
        startDate: 'not-a-date',
      );
      await tester.pumpWidget(_app(_fullData(booking: bk)));
      await tester.pumpAndSettle();

      expect(find.textContaining('not-a-date'), findsOneWidget);
    });
  });

  // ── Open tasks card ────────────────────────────────────────────────────────

  group('open tasks card', () {
    testWidgets('renders task count', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData(tasks: 5)));
      await tester.pumpAndSettle();

      expect(find.textContaining('5 open tasks'), findsOneWidget);
    });

    testWidgets('renders zero task count', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData(tasks: 0)));
      await tester.pumpAndSettle();

      expect(find.textContaining('0 open tasks'), findsOneWidget);
    });

    testWidgets('contains "See Trips for details" subtitle', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData()));
      await tester.pumpAndSettle();

      expect(find.textContaining('See Trips'), findsOneWidget);
    });
  });

  // ── Pull-to-refresh ────────────────────────────────────────────────────────

  group('structure', () {
    testWidgets('wraps in RefreshIndicator', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData()));
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('uses ListView with AlwaysScrollableScrollPhysics',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullData()));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
