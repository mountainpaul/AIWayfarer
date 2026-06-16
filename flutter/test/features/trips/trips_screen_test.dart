import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wayfarer/features/trips/trips_screen.dart';
import 'package:wayfarer/models/leg.dart';
import 'package:wayfarer/models/trip.dart';
import 'package:wayfarer/providers/trip_provider.dart';
import 'package:wayfarer/services/api_client.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _trip1 = Trip(
  id: 'trip-1',
  name: 'Europe 2026',
  startDate: '2026-06-01',
  endDate: '2026-08-05',
  status: 'active',
);

const _trip2 = Trip(
  id: 'trip-2',
  name: 'Japan Winter',
  startDate: '2026-12-01',
  endDate: '2026-12-21',
  status: 'planning',
);

const _leg1 = Leg(
  id: 'leg-1',
  tripId: 'trip-1',
  slug: 'italy',
  name: 'Italy',
  emoji: '🇮🇹',
  color: '#ef4444',
  startDate: '2026-06-01',
  endDate: '2026-06-30',
);

const _leg2 = Leg(
  id: 'leg-2',
  tripId: 'trip-1',
  slug: 'france',
  name: 'France',
  startDate: '2026-07-01',
  endDate: '2026-08-05',
);

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Tall surface so the full ListView renders without overflow.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Fake ApiClient used to satisfy apiClientProvider in the TripMutations path.
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');
}

/// Wraps TripsScreen in a tiny GoRouter so context.go() works.
Widget _appWithRouter(List<Override> overrides) {
  final router = GoRouter(
    initialLocation: '/trips',
    routes: [
      GoRoute(
        path: '/trips',
        builder: (_, __) => const TripsScreen(),
      ),
      GoRoute(
        path: '/trips/scan-email',
        builder: (_, __) => const Scaffold(body: Text('scan-email')),
      ),
      GoRoute(
        path: '/trips/awards',
        builder: (_, __) => const Scaffold(body: Text('awards')),
      ),
      GoRoute(
        path: '/trips/leg/:id',
        builder: (_, __) => const Scaffold(body: Text('leg-detail')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      // Provide a no-op fake API so tripMutationsProvider doesn't need network.
      apiClientProvider.overrideWithValue(_FakeApi()),
      ...overrides,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ── Fake TripMutations ────────────────────────────────────────────────────────

/// Records calls instead of talking to API/DB.
class _RecordingMutations extends TripMutations {
  _RecordingMutations(super.ref);

  String? deletedTripId;
  String? updatedTripId;
  Map<String, dynamic>? updatedPatch;

  @override
  Future<bool> deleteTrip(String id) async {
    deletedTripId = id;
    return true;
  }

  @override
  Future<bool> updateTrip(String id, Map<String, dynamic> patch) async {
    updatedTripId = id;
    updatedPatch = patch;
    return true;
  }

  @override
  Future<bool> createTrip(Map<String, dynamic> payload) async => true;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('TripsScreen – loading state', () {
    testWidgets('shows spinner while legsProvider is loading', (tester) async {
      final legsCompleter = Completer<List<Leg>>();

      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) => legsCompleter.future),
          tripsProvider.overrideWith((_) async => []),
        ]),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows spinner while tripsProvider is loading', (tester) async {
      final tripsCompleter = Completer<List<Trip>>();

      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) => tripsCompleter.future),
        ]),
      );

      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('TripsScreen – error state', () {
    testWidgets('shows error text when legsProvider throws', (tester) async {
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider
              .overrideWith((_) async => throw Exception('DB offline')),
          tripsProvider.overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('DB offline'), findsOneWidget);
    });

    testWidgets('shows error text when tripsProvider throws', (tester) async {
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider
              .overrideWith((_) async => throw Exception('Trips failed')),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Trips failed'), findsOneWidget);
    });
  });

  group('TripsScreen – empty state', () {
    testWidgets('shows empty prompt when trips list is empty', (tester) async {
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No trips yet'), findsOneWidget);
    });
  });

  group('TripsScreen – data state', () {
    testWidgets('renders trip names and status chips', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => [_leg1, _leg2]),
          tripsProvider.overrideWith((_) async => [_trip1, _trip2]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Europe 2026'), findsOneWidget);
      expect(find.text('Japan Winter'), findsOneWidget);
      expect(find.text('active'), findsOneWidget);
      expect(find.text('planning'), findsOneWidget);
    });

    testWidgets('renders legs nested under their trip', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => [_leg1, _leg2]),
          tripsProvider.overrideWith((_) async => [_trip1, _trip2]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Italy'), findsOneWidget);
      expect(find.text('France'), findsOneWidget);
    });

    testWidgets('shows date range for a leg', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => [_leg1]),
          tripsProvider.overrideWith((_) async => [_trip1]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2026-06-01'), findsWidgets);
    });

    testWidgets('FAB is present with Trip label', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [_trip1]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Trip'), findsOneWidget);
    });

    testWidgets('email scan icon button is present when trips exist',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [_trip1]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    });

    testWidgets('loyalty awards icon button is present when trips exist',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [_trip1]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.loyalty_outlined), findsOneWidget);
    });

    testWidgets('popup menu shows status change and delete options',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [_trip1]),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      expect(find.text('Mark planning'), findsOneWidget);
      expect(find.text('Mark active'), findsOneWidget);
      expect(find.text('Mark completed'), findsOneWidget);
      expect(find.text('Delete trip'), findsOneWidget);
    });

    testWidgets('popup menu includes "Edit trip" item', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [_trip1]),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      expect(find.text('Edit trip'), findsOneWidget);
    });

    testWidgets('tapping delete trip opens confirmation dialog', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [_trip1]),
          tripMutationsProvider
              .overrideWith((ref) => _RecordingMutations(ref)),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete trip'));
      await tester.pumpAndSettle();

      expect(find.text('Delete trip?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('cancelling delete dialog does not call deleteTrip',
        (tester) async {
      _tallSurface(tester);
      _RecordingMutations? captured;
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [_trip1]),
          tripMutationsProvider.overrideWith((ref) {
            captured = _RecordingMutations(ref);
            return captured!;
          }),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(captured?.deletedTripId, isNull);
    });

    testWidgets('confirming delete calls deleteTrip with correct id',
        (tester) async {
      _tallSurface(tester);
      _RecordingMutations? captured;
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [_trip1]),
          tripMutationsProvider.overrideWith((ref) {
            captured = _RecordingMutations(ref);
            return captured!;
          }),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(captured?.deletedTripId, 'trip-1');
    });

    testWidgets('selecting Mark active calls updateTrip with active status',
        (tester) async {
      _tallSurface(tester);
      _RecordingMutations? captured;
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [_trip2]), // planning → active
          tripMutationsProvider.overrideWith((ref) {
            captured = _RecordingMutations(ref);
            return captured!;
          }),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark active'));
      await tester.pumpAndSettle();

      expect(captured?.updatedTripId, 'trip-2');
      expect(captured?.updatedPatch, {'status': 'active'});
    });

    testWidgets('tapping a leg navigates to leg detail', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => [_leg1]),
          tripsProvider.overrideWith((_) async => [_trip1]),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Italy'));
      await tester.pumpAndSettle();

      expect(find.text('leg-detail'), findsOneWidget);
    });

    testWidgets('email scan button navigates to scan-email', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [_trip1]),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.email_outlined));
      await tester.pumpAndSettle();

      expect(find.text('scan-email'), findsOneWidget);
    });

    testWidgets('awards button navigates to awards screen', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [_trip1]),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.loyalty_outlined));
      await tester.pumpAndSettle();

      expect(find.text('awards'), findsOneWidget);
    });

    testWidgets('multiple trips render all headers and legs', (tester) async {
      _tallSurface(tester);
      const legJapan = Leg(
        id: 'leg-jp',
        tripId: 'trip-2',
        slug: 'tokyo',
        name: 'Tokyo',
        startDate: '2026-12-01',
        endDate: '2026-12-21',
      );
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => [_leg1, _leg2, legJapan]),
          tripsProvider.overrideWith((_) async => [_trip1, _trip2]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Europe 2026'), findsOneWidget);
      expect(find.text('Japan Winter'), findsOneWidget);
      expect(find.text('Italy'), findsOneWidget);
      expect(find.text('France'), findsOneWidget);
      expect(find.text('Tokyo'), findsOneWidget);
    });

    testWidgets('leg emoji is displayed in CircleAvatar', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => [_leg1]),
          tripsProvider.overrideWith((_) async => [_trip1]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('🇮🇹'), findsOneWidget);
    });

    testWidgets('leg without emoji shows first letter of name', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => [_leg2]),
          tripsProvider.overrideWith((_) async => [_trip1]),
        ]),
      );
      await tester.pumpAndSettle();

      // leg2 has no emoji; name = 'France' → 'F'
      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('completed status renders chip', (tester) async {
      _tallSurface(tester);
      const completedTrip = Trip(
        id: 'trip-done',
        name: 'Done Trip',
        startDate: '2025-01-01',
        endDate: '2025-03-01',
        status: 'completed',
      );
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [completedTrip]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('completed'), findsOneWidget);
    });
  });

  group('Add leg button', () {
    testWidgets('renders an Add leg button for a single trip', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => []),
          tripsProvider.overrideWith((_) async => [_trip1]),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add leg'), findsOneWidget);
    });

    testWidgets('renders an Add leg button for each trip', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _appWithRouter([
          legsProvider.overrideWith((_) async => [_leg1, _leg2]),
          tripsProvider.overrideWith((_) async => [_trip1, _trip2]),
        ]),
      );
      await tester.pumpAndSettle();

      // One Add leg button per trip (two trips → two buttons).
      expect(find.text('Add leg'), findsNWidgets(2));
    });
  });
}
