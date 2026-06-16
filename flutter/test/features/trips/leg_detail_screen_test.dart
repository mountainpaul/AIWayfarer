import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wayfarer/features/trips/leg_detail_screen.dart';
import 'package:wayfarer/models/booking.dart';
import 'package:wayfarer/models/journal_entry.dart';
import 'package:wayfarer/models/leg.dart';
import 'package:wayfarer/models/packing_item.dart';
import 'package:wayfarer/models/task.dart';
import 'package:wayfarer/providers/trip_provider.dart';
import 'package:wayfarer/services/api_client.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _legId = 'leg-test-1';
const _tripId = 'trip-test-1';

const _leg = Leg(
  id: _legId,
  tripId: _tripId,
  slug: 'italy',
  name: 'Italy',
  emoji: '🇮🇹',
  color: '#ef4444',
  startDate: '2026-06-01',
  endDate: '2026-06-30',
  places: 'Rome, Florence, Venice',
);

const _booking1 = Booking(
  id: 'b-1',
  legId: _legId,
  type: 'flight',
  name: 'DEN → FCO',
  status: 'booked',
  startDate: '2026-06-01',
  confirmation: 'ABC123',
);

const _booking2 = Booking(
  id: 'b-2',
  legId: _legId,
  type: 'hotel',
  name: 'Hotel Quirinale',
  status: 'pending',
  locationName: 'Rome',
);

const _task1 = Task(
  id: 't-1',
  legId: _legId,
  title: 'Book train to Florence',
  priority: 'high',
);

const _task2 = Task(
  id: 't-2',
  legId: _legId,
  title: 'Get travel insurance',
  priority: 'critical',
  isDone: true,
);

const _packingItem1 = PackingItem(
  id: 'p-1',
  tripId: _tripId,
  category: 'Clothing',
  name: 'Hiking boots',
);

const _packingItem2 = PackingItem(
  id: 'p-2',
  tripId: _tripId,
  category: 'Documents',
  name: 'Passport',
  isPacked: true,
);

const _journalEntry1 = JournalEntry(
  id: 'j-1',
  legId: _legId,
  content: 'Arrived in Rome, amazing!',
  entryType: 'note',
  createdAt: '2026-06-01T18:00:00Z',
);

const _journalEntry2 = JournalEntry(
  id: 'j-2',
  legId: _legId,
  content: 'Visited the Colosseum today.',
  entryType: 'reflection',
);

// ── Helpers ───────────────────────────────────────────────────────────────────

void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');
}

/// Recording TripMutations — captures updateLeg / deleteLeg calls.
class _RecordingMutations extends TripMutations {
  _RecordingMutations(super.ref);

  String? updatedLegId;
  Map<String, dynamic>? updatedPatch;
  String? deletedLegId;
  bool returnValue = true;

  @override
  Future<bool> updateLeg(String id, Map<String, dynamic> patch) async {
    updatedLegId = id;
    updatedPatch = patch;
    return returnValue;
  }

  @override
  Future<bool> deleteLeg(String id) async {
    deletedLegId = id;
    return returnValue;
  }
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApi()),
        ...overrides,
      ],
      child: const MaterialApp(home: LegDetailScreen(legId: _legId)),
    );

/// App wrapper that uses GoRouter so context.go('/trips') works when
/// deleteLeg succeeds and the screen navigates away.
Widget _appWithRouter(List<Override> overrides) {
  final router = GoRouter(
    initialLocation: '/leg',
    routes: [
      GoRoute(
        path: '/leg',
        builder: (_, __) => const LegDetailScreen(legId: _legId),
      ),
      GoRoute(
        path: '/trips',
        builder: (_, __) => const Scaffold(body: Text('trips-list')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(_FakeApi()),
      ...overrides,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('LegDetailScreen – loading state', () {
    testWidgets('shows CircularProgressIndicator while legProvider loads',
        (tester) async {
      final completer = Completer<Leg?>();
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) => completer.future),
        ]),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('LegDetailScreen – error state', () {
    testWidgets('shows error text when legProvider throws', (tester) async {
      await tester.pumpWidget(
        _app([
          legProvider(_legId)
              .overrideWith((_) async => throw Exception('Leg load error')),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Leg load error'), findsOneWidget);
    });
  });

  group('LegDetailScreen – null leg', () {
    testWidgets('shows Leg not found when legProvider returns null',
        (tester) async {
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => null),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Leg not found'), findsOneWidget);
    });
  });

  group('LegDetailScreen – header', () {
    testWidgets('renders leg name, emoji, dates and places', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Italy'), findsWidgets);
      expect(find.textContaining('🇮🇹'), findsOneWidget);
      expect(find.textContaining('2026-06-01'), findsWidgets);
      expect(find.text('Rome, Florence, Venice'), findsOneWidget);
    });

    testWidgets('award search icon button is present in header', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.loyalty_outlined), findsOneWidget);
    });

    testWidgets('four tabs are shown: Bookings, Tasks, Packing, Journal',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Packing'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
    });
  });

  group('LegDetailScreen – Bookings tab', () {
    testWidgets('shows spinner while bookings load', (tester) async {
      _tallSurface(tester);
      final bookingsCompleter = Completer<List<Booking>>();
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId)
              .overrideWith((_) => bookingsCompleter.future),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows error when bookings provider throws', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId)
              .overrideWith((_) async => throw Exception('bookings error')),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('bookings error'), findsOneWidget);
    });

    testWidgets('shows empty message when no bookings', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('No bookings yet.'), findsOneWidget);
    });

    testWidgets('renders booking tiles when data is present', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId)
              .overrideWith((_) async => [_booking1, _booking2]),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('DEN → FCO'), findsOneWidget);
      expect(find.text('Hotel Quirinale'), findsOneWidget);
    });

    testWidgets('add booking FAB is present in Bookings tab', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      // FAB with heroTag 'add_booking'
      expect(
        find.byWidgetPredicate((w) =>
            w is FloatingActionButton && w.heroTag == 'add_booking'),
        findsOneWidget,
      );
    });
  });

  group('LegDetailScreen – Tasks tab', () {
    testWidgets('shows empty message when no tasks', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      // Navigate to Tasks tab
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      expect(find.text('No tasks for this leg.'), findsOneWidget);
    });

    testWidgets('renders task tiles when tasks exist', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId)
              .overrideWith((_) async => [_task1, _task2]),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      expect(find.text('Book train to Florence'), findsOneWidget);
      expect(find.text('Get travel insurance'), findsOneWidget);
    });

    testWidgets('shows error when tasks provider throws', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId)
              .overrideWith((_) async => throw Exception('tasks error')),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      expect(find.textContaining('tasks error'), findsOneWidget);
    });

    testWidgets('add task FAB is present in Tasks tab', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
            (w) => w is FloatingActionButton && w.heroTag == 'add_task'),
        findsOneWidget,
      );
    });
  });

  group('LegDetailScreen – Packing tab', () {
    testWidgets('shows empty message when no packing items', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Packing'));
      await tester.pumpAndSettle();

      expect(find.text('No packing items.'), findsOneWidget);
    });

    testWidgets('renders packing tiles when items exist', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId)
              .overrideWith((_) async => [_packingItem1, _packingItem2]),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Packing'));
      await tester.pumpAndSettle();

      expect(find.text('Hiking boots'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);
    });

    testWidgets('shows error when packingForTripProvider throws',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId)
              .overrideWith((_) async => throw Exception('packing error')),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Packing'));
      await tester.pumpAndSettle();

      expect(find.textContaining('packing error'), findsOneWidget);
    });
  });

  group('LegDetailScreen – Journal tab', () {
    testWidgets('shows empty message when no journal entries', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      expect(find.text('No journal entries yet.'), findsOneWidget);
    });

    testWidgets('renders journal tiles when entries exist', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId)
              .overrideWith((_) async => [_journalEntry1, _journalEntry2]),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      expect(find.text('Arrived in Rome, amazing!'), findsOneWidget);
      expect(find.text('Visited the Colosseum today.'), findsOneWidget);
    });

    testWidgets('shows error when journalForLegProvider throws', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId)
              .overrideWith((_) async => throw Exception('journal error')),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      expect(find.textContaining('journal error'), findsOneWidget);
    });

    testWidgets('Add note FAB is present in Journal tab', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      expect(find.text('Add note'), findsOneWidget);
    });

    testWidgets('tapping Add note shows the dialog', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add note'));
      await tester.pumpAndSettle();

      expect(find.text('New journal entry'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('cancelling journal dialog dismisses without saving',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add note'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('New journal entry'), findsNothing);
    });
  });

  // ── LegDetailScreen – header popup menu (Edit / Delete) ───────────────────

  group('LegDetailScreen – header popup menu', () {
    testWidgets('popup menu contains "Edit leg" and "Delete leg" items',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      // Open the popup menu in the header.
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Edit leg'), findsOneWidget);
      expect(find.text('Delete leg'), findsOneWidget);
    });

    testWidgets('tapping "Delete leg" shows confirm dialog with "Delete leg?" title',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
          tripMutationsProvider
              .overrideWith((ref) => _RecordingMutations(ref)),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete leg'));
      await tester.pumpAndSettle();

      expect(find.text('Delete leg?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('cancelling the delete dialog does not call deleteLeg',
        (tester) async {
      _tallSurface(tester);
      _RecordingMutations? captured;
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
          tripMutationsProvider.overrideWith((ref) {
            captured = _RecordingMutations(ref);
            return captured!;
          }),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete leg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(captured?.deletedLegId, isNull);
    });

    testWidgets('confirming delete calls deleteLeg and navigates to /trips',
        (tester) async {
      _tallSurface(tester);
      _RecordingMutations? captured;
      await tester.pumpWidget(
        _appWithRouter([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
          tripMutationsProvider.overrideWith((ref) {
            captured = _RecordingMutations(ref);
            return captured!;
          }),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete leg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(captured?.deletedLegId, _legId);
      // Navigated to /trips stub.
      expect(find.text('trips-list'), findsOneWidget);
    });
  });

  // ── LegDetailScreen – Packing tab add FAB ─────────────────────────────────

  group('LegDetailScreen – Packing tab add FAB', () {
    testWidgets('Packing tab has an add_packing FloatingActionButton',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(
        _app([
          legProvider(_legId).overrideWith((_) async => _leg),
          bookingsForLegProvider(_legId).overrideWith((_) async => []),
          tasksForLegProvider(_legId).overrideWith((_) async => []),
          packingForTripProvider(_tripId).overrideWith((_) async => []),
          journalForLegProvider(_legId).overrideWith((_) async => []),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Packing'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
            (w) => w is FloatingActionButton && w.heroTag == 'add_packing'),
        findsOneWidget,
      );
    });
  });
}
