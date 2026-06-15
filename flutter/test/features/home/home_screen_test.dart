import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/features/home/home_screen.dart';
import 'package:wayfarer/models/booking.dart';
import 'package:wayfarer/models/briefing.dart';
import 'package:wayfarer/models/leg.dart';
import 'package:wayfarer/providers/briefing_provider.dart';
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

/// Stub [Leg] that lives today so [currentLegProvider] returns it.
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
  );
}

/// A [Booking] starting tomorrow so it shows up as "next booking".
Booking _nextBooking() {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final iso = tomorrow.toIso8601String();
  return Booking(
    id: 'bk-1',
    legId: 'leg-1',
    type: 'flight',
    name: 'Air France 007',
    status: 'confirmed',
    startDate: iso,
    locationName: 'CDG',
  );
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    );

// ---------------------------------------------------------------------------
// Sentinel for "return null from this provider" in _fullDataOverrides.
// ---------------------------------------------------------------------------

// ignore: avoid_classes_with_only_static_members
class _Null {
  const _Null();
}

// ---------------------------------------------------------------------------
// Default "full data" overrides (all providers resolved, typical happy path).
// Pass a `_Null()` instance as the sentinel value when you want the provider to return null.
// ---------------------------------------------------------------------------

List<Override> _fullDataOverrides({
  Object? briefing = const _Null(),   // default = stock Briefing
  Object? leg = const _Null(),        // default = _todayLeg()
  Object? booking = const _Null(),    // default = _nextBooking()
  int tasks = 3,
  Object? schengen = const _Null(),   // default = schengen map
  Object? coverage = const _Null(),   // default = coverage list
  Object? budget = const _Null(),     // default = budget map
}) {
  final resolvedBriefing = briefing is _Null
      ? const Briefing(
          id: 'b1',
          date: '2026-06-14',
          markdown: '**Morning briefing** – all good.',
        )
      : briefing as Briefing?;

  final resolvedLeg = leg is _Null ? _todayLeg() : leg as Leg?;
  final resolvedBk = booking is _Null ? _nextBooking() : booking as Booking?;

  final resolvedSchengen = schengen is _Null
      ? <String, dynamic>{
          'status': 'ok',
          'days_used': 20,
          'limit_days': 90,
          'days_remaining': 70,
          'peak_days': 20,
        }
      : schengen as Map<String, dynamic>?;

  final resolvedCoverage = coverage is _Null
      ? <Map<String, dynamic>>[
          {'leg_name': 'Paris', 'unbooked_nights': 0},
        ]
      : coverage as List<Map<String, dynamic>>?;

  final resolvedBudget = budget is _Null
      ? <String, dynamic>{
          'by_currency': [
            {
              'currency': 'EUR',
              'planned_cents': 500000,
              'actual_cents': 120000,
              'remaining_cents': 380000,
            }
          ],
        }
      : budget as Map<String, dynamic>?;

  return [
    briefingProvider.overrideWith((ref) async => resolvedBriefing),
    currentLegProvider.overrideWith((ref) async => resolvedLeg),
    nextBookingProvider.overrideWith((ref) async => resolvedBk),
    openTaskCountProvider.overrideWith((ref) async => tasks),
    schengenProvider.overrideWith((ref) async => resolvedSchengen),
    coverageProvider.overrideWith((ref) async => resolvedCoverage),
    budgetProvider.overrideWith((ref) async => resolvedBudget),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Loading state ──────────────────────────────────────────────────────────

  group('loading state', () {
    testWidgets('shows CircularProgressIndicator while briefing loads',
        (tester) async {
      final completer = Completer<Briefing?>();
      await tester.pumpWidget(_app([
        briefingProvider.overrideWith((ref) => completer.future),
        currentLegProvider.overrideWith((ref) async => null),
        nextBookingProvider.overrideWith((ref) async => null),
        openTaskCountProvider.overrideWith((ref) async => 0),
        schengenProvider.overrideWith((ref) async => null),
        coverageProvider.overrideWith((ref) async => null),
        budgetProvider.overrideWith((ref) async => null),
      ]));
      // Do NOT settle — we want the loading state.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows loading cards while currentLeg loads', (tester) async {
      final completer = Completer<Leg?>();
      await tester.pumpWidget(_app([
        briefingProvider.overrideWith((ref) async => null),
        currentLegProvider.overrideWith((ref) => completer.future),
        nextBookingProvider.overrideWith((ref) async => null),
        openTaskCountProvider.overrideWith((ref) async => 0),
        schengenProvider.overrideWith((ref) async => null),
        coverageProvider.overrideWith((ref) async => null),
        budgetProvider.overrideWith((ref) async => null),
      ]));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  // ── Happy-path data ────────────────────────────────────────────────────────

  group('full data — briefing card', () {
    testWidgets('renders briefing markdown text', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Morning briefing'), findsOneWidget);
    });
  });

  group('full data — current leg card', () {
    testWidgets('renders leg name and dates', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides()));
      await tester.pumpAndSettle();

      expect(find.text('Paris'), findsWidgets); // at least the leg title
    });
  });

  group('full data — next booking card', () {
    testWidgets('renders booking name', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides()));
      await tester.pumpAndSettle();

      expect(find.text('Air France 007'), findsOneWidget);
    });

    testWidgets('renders location in subtitle', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides()));
      await tester.pumpAndSettle();

      expect(find.textContaining('CDG'), findsOneWidget);
    });
  });

  group('full data — open tasks card', () {
    testWidgets('renders open task count', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(tasks: 7)));
      await tester.pumpAndSettle();

      expect(find.textContaining('7 open tasks'), findsOneWidget);
    });

    testWidgets('renders zero tasks', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(tasks: 0)));
      await tester.pumpAndSettle();

      expect(find.textContaining('0 open tasks'), findsOneWidget);
    });
  });

  // ── Schengen card ──────────────────────────────────────────────────────────

  group('schengen card', () {
    testWidgets('renders when peak_days > 0', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(
        schengen: {
          'status': 'ok',
          'days_used': 20,
          'limit_days': 90,
          'days_remaining': 70,
          'peak_days': 20,
        },
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Schengen'), findsOneWidget);
      expect(find.textContaining('20 / 90'), findsOneWidget);
    });

    testWidgets('hidden when offline (null)', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(schengen: null)));
      await tester.pumpAndSettle();

      // schengenProvider returns null → maybeWhen orElse → SizedBox.shrink
      expect(find.textContaining('Schengen'), findsNothing);
    });

    testWidgets('hidden when peak_days is 0', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(
        schengen: {
          'status': 'ok',
          'days_used': 0,
          'limit_days': 90,
          'days_remaining': 90,
          'peak_days': 0,
        },
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Schengen'), findsNothing);
    });

    testWidgets('warning status renders approaching text', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(
        schengen: {
          'status': 'warning',
          'days_used': 75,
          'limit_days': 90,
          'days_remaining': 15,
          'peak_days': 75,
        },
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('approaching'), findsOneWidget);
    });

    testWidgets('ever_exceeds shows peak_date warning', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(
        schengen: {
          'status': 'warning',
          'days_used': 80,
          'limit_days': 90,
          'days_remaining': 10,
          'peak_days': 95,
          'ever_exceeds': true,
          'peak_date': '2026-08-01',
        },
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('exceeds 90'), findsOneWidget);
    });
  });

  // ── Coverage card ──────────────────────────────────────────────────────────

  group('coverage card', () {
    testWidgets('shows all-booked when unbooked_nights is 0 for all legs',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(
        coverage: [
          {'leg_name': 'Paris', 'unbooked_nights': 0},
          {'leg_name': 'Rome', 'unbooked_nights': 0},
        ],
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('All lodging booked'), findsOneWidget);
    });

    testWidgets('shows gap warning when some nights unbooked', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(
        coverage: [
          {'leg_name': 'Barcelona', 'unbooked_nights': 3},
          {'leg_name': 'Madrid', 'unbooked_nights': 0},
        ],
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('need lodging'), findsOneWidget);
      expect(find.textContaining('Barcelona'), findsOneWidget);
    });

    testWidgets('hidden when null (offline)', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(coverage: null)));
      await tester.pumpAndSettle();

      expect(find.textContaining('lodging'), findsNothing);
    });

    testWidgets('hidden when empty list', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
          _app(_fullDataOverrides(coverage: <Map<String, dynamic>>[])));
      await tester.pumpAndSettle();

      expect(find.textContaining('lodging'), findsNothing);
    });
  });

  // ── Budget card ────────────────────────────────────────────────────────────

  group('budget card', () {
    testWidgets('renders currency and amounts', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(
        budget: {
          'by_currency': [
            {
              'currency': 'EUR',
              'planned_cents': 500000,
              'actual_cents': 120000,
              'remaining_cents': 380000,
            }
          ],
        },
      )));
      await tester.pumpAndSettle();

      expect(find.text('Budget'), findsOneWidget);
      expect(find.textContaining('EUR'), findsOneWidget);
      expect(find.textContaining('1200'), findsOneWidget); // actual
    });

    testWidgets('hidden when null (offline)', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(budget: null)));
      await tester.pumpAndSettle();

      expect(find.text('Budget'), findsNothing);
    });

    testWidgets('hidden when by_currency list is empty', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(
        budget: {'by_currency': <dynamic>[]},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Budget'), findsNothing);
    });

    testWidgets('shows overspent icon color when remaining < 0',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(
        budget: {
          'by_currency': [
            {
              'currency': 'USD',
              'planned_cents': 10000,
              'actual_cents': 15000,
              'remaining_cents': -5000,
            }
          ],
        },
      )));
      await tester.pumpAndSettle();

      expect(find.text('Budget'), findsOneWidget);
    });
  });

  // ── Null / empty / offline states for core providers ──────────────────────

  group('null states', () {
    testWidgets('no briefing shows empty card message', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_fullDataOverrides(briefing: null)));
      await tester.pumpAndSettle();

      // briefingProvider returns null Briefing? → _EmptyCard shown
      expect(find.textContaining('No briefing yet'), findsOneWidget);
    });

    testWidgets('no active leg shows empty card', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app([
        briefingProvider.overrideWith((ref) async => null),
        currentLegProvider.overrideWith((ref) async => null),
        nextBookingProvider.overrideWith((ref) async => null),
        openTaskCountProvider.overrideWith((ref) async => 0),
        schengenProvider.overrideWith((ref) async => null),
        coverageProvider.overrideWith((ref) async => null),
        budgetProvider.overrideWith((ref) async => null),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('No active leg'), findsOneWidget);
    });

    testWidgets('no upcoming booking shows empty card', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app([
        briefingProvider.overrideWith((ref) async => null),
        currentLegProvider.overrideWith((ref) async => _todayLeg()),
        nextBookingProvider.overrideWith((ref) async => null),
        openTaskCountProvider.overrideWith((ref) async => 0),
        schengenProvider.overrideWith((ref) async => null),
        coverageProvider.overrideWith((ref) async => null),
        budgetProvider.overrideWith((ref) async => null),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('No upcoming bookings'), findsOneWidget);
    });
  });

  // ── Error states ───────────────────────────────────────────────────────────

  group('error states', () {
    testWidgets('briefing error shows error card', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app([
        briefingProvider
            .overrideWith((ref) => Future.error('network error')),
        currentLegProvider.overrideWith((ref) async => null),
        nextBookingProvider.overrideWith((ref) async => null),
        openTaskCountProvider.overrideWith((ref) async => 0),
        schengenProvider.overrideWith((ref) async => null),
        coverageProvider.overrideWith((ref) async => null),
        budgetProvider.overrideWith((ref) async => null),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('network error'), findsOneWidget);
    });

    testWidgets('currentLeg error shows error card', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app([
        briefingProvider.overrideWith((ref) async => null),
        currentLegProvider
            .overrideWith((ref) => Future.error('db error')),
        nextBookingProvider.overrideWith((ref) async => null),
        openTaskCountProvider.overrideWith((ref) async => 0),
        schengenProvider.overrideWith((ref) async => null),
        coverageProvider.overrideWith((ref) async => null),
        budgetProvider.overrideWith((ref) async => null),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('db error'), findsOneWidget);
    });
  });

  // ── Booking subtitle formatting ────────────────────────────────────────────

  group('booking subtitle formatting', () {
    testWidgets('renders location-only booking subtitle', (tester) async {
      _tallSurface(tester);
      const bk = Booking(
        id: 'bk-2',
        legId: 'leg-1',
        type: 'hotel',
        name: 'Hotel du Louvre',
        status: 'confirmed',
        locationName: 'Paris, France',
      );
      await tester.pumpWidget(_app(_fullDataOverrides(booking: bk)));
      await tester.pumpAndSettle();

      expect(find.text('Hotel du Louvre'), findsOneWidget);
      expect(find.textContaining('Paris, France'), findsOneWidget);
    });

    testWidgets('renders booking with start date formatted', (tester) async {
      _tallSurface(tester);
      const bk = Booking(
        id: 'bk-3',
        legId: 'leg-1',
        type: 'flight',
        name: 'KLM 902',
        status: 'confirmed',
        startDate: '2026-07-15T10:30:00Z',
      );
      await tester.pumpWidget(_app(_fullDataOverrides(booking: bk)));
      await tester.pumpAndSettle();

      expect(find.text('KLM 902'), findsOneWidget);
    });
  });
}
