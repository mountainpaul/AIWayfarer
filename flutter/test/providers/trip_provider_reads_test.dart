import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wayfarer/providers/trip_provider.dart';
import 'package:wayfarer/services/api_client.dart';
import 'package:wayfarer/services/local_db.dart';

// ── Fake ApiClient for server-computed providers ──────────────────────────

class _FakeApiOk extends ApiClient {
  _FakeApiOk() : super(baseUrl: 'http://test.local');

  @override
  Future<Map<String, dynamic>> getSchengen({
    String? asOf,
    String? tripId,
  }) async =>
      const {'days_used': 30, 'days_remaining': 60};

  @override
  Future<List<Map<String, dynamic>>> getCoverage({String? tripId}) async =>
      const [
        {'leg_id': 'leg-1', 'covered': true},
      ];

  @override
  Future<Map<String, dynamic>> getBudget({String? tripId}) async =>
      const {'total_planned_usd': 5000, 'total_actual_usd': 1200};
}

class _FakeApiThrows extends ApiClient {
  _FakeApiThrows() : super(baseUrl: 'http://test.local');

  @override
  Future<Map<String, dynamic>> getSchengen({String? asOf, String? tripId}) =>
      Future.error(ApiUnreachable('offline'));

  @override
  Future<List<Map<String, dynamic>>> getCoverage({String? tripId}) =>
      Future.error(ApiUnreachable('offline'));

  @override
  Future<Map<String, dynamic>> getBudget({String? tripId}) =>
      Future.error(ApiUnreachable('offline'));
}

// ── Fixture helpers (match row shapes from local_db_test.dart) ────────────

String _dayOffset(int days) {
  final n = DateTime.now().add(Duration(days: days));
  String two(int x) => x.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)}';
}

Map<String, dynamic> _tripRow({
  String id = 'trip-1',
  String name = 'Japan 2026',
  String startDate = '2026-01-01',
  String endDate = '2026-12-31',
}) =>
    {
      'id': id,
      'name': name,
      'start_date': startDate,
      'end_date': endDate,
      'status': 'planning',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> _legRow({
  String id = 'leg-1',
  String tripId = 'trip-1',
  String slug = 'paris',
  String name = 'Paris',
  String? startDate,
  String? endDate,
  int sortOrder = 0,
}) =>
    {
      'id': id,
      'trip_id': tripId,
      'slug': slug,
      'name': name,
      'start_date': startDate ?? '2026-01-01',
      'end_date': endDate ?? '2026-01-10',
      'is_schengen': 0,
      'sort_order': sortOrder,
      'currency': 'USD',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> _bookingRow({
  String id = 'bk-1',
  String legId = 'leg-1',
  String? startDate,
}) =>
    {
      'id': id,
      'leg_id': legId,
      'type': 'flight',
      'name': 'Air Test',
      'status': 'confirmed',
      'currency': 'USD',
      if (startDate != null) 'start_date': startDate,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> _taskRow({
  String id = 'task-1',
  String? legId = 'leg-1',
  bool isDone = false,
}) =>
    {
      'id': id,
      if (legId != null) 'leg_id': legId,
      'title': 'Pack bags',
      'priority': 'high',
      'is_done': isDone ? 1 : 0,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> _packingRow({
  String id = 'pi-1',
  String tripId = 'trip-1',
}) =>
    {
      'id': id,
      'trip_id': tripId,
      'category': 'clothes',
      'name': 'T-shirt',
      'is_packed': 0,
      'sort_order': 0,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> _journalRow({
  String id = 'je-1',
  String? legId = 'leg-1',
}) =>
    {
      'id': id,
      if (legId != null) 'leg_id': legId,
      'content': 'Great day!',
      'entry_type': 'note',
      'created_at': '2026-01-05T12:00:00Z',
      'updated_at': '2026-01-05T12:00:00Z',
    };

// ── Container factory ─────────────────────────────────────────────────────

Future<(ProviderContainer, LocalDb)> _makeContainer({
  ApiClient? api,
}) async {
  final db = LocalDb.newForTest();
  await db.init(pathOverride: inMemoryDatabasePath);

  final container = ProviderContainer(overrides: [
    // Skip real network sync — just resolve immediately.
    initialSyncProvider.overrideWith((ref) async => true),
    localDbProvider.overrideWithValue(db),
    if (api != null) apiClientProvider.overrideWithValue(api),
  ]);
  addTearDown(container.dispose);
  addTearDown(db.close);
  return (container, db);
}

// ─────────────────────────────────────────────────────────────────────────────
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ── tripsProvider ─────────────────────────────────────────────────────────

  group('tripsProvider', () {
    test('returns empty list when db is empty', () async {
      final (c, _) = await _makeContainer();
      final trips = await c.read(tripsProvider.future);
      expect(trips, isEmpty);
    });

    test('returns seeded trips', () async {
      final (c, db) = await _makeContainer();
      await db.upsertAll('trip', [
        _tripRow(id: 'trip-1', name: 'Japan 2026'),
        _tripRow(id: 'trip-2', name: 'Greece 2027',
            startDate: '2027-06-01', endDate: '2027-06-30'),
      ]);
      final trips = await c.read(tripsProvider.future);
      expect(trips, hasLength(2));
      expect(trips.map((t) => t.id), containsAll(['trip-1', 'trip-2']));
    });
  });

  // ── legsProvider ─────────────────────────────────────────────────────────

  group('legsProvider', () {
    test('returns empty list when db is empty', () async {
      final (c, _) = await _makeContainer();
      expect(await c.read(legsProvider.future), isEmpty);
    });

    test('returns all seeded legs ordered by sort_order', () async {
      final (c, db) = await _makeContainer();
      await db.upsertAll('leg', [
        _legRow(id: 'leg-b', slug: 'rome', name: 'Rome', sortOrder: 2),
        _legRow(id: 'leg-a', slug: 'paris', name: 'Paris', sortOrder: 1),
      ]);
      final legs = await c.read(legsProvider.future);
      expect(legs, hasLength(2));
      expect(legs.first.id, 'leg-a');
    });
  });

  // ── legProvider (family) ──────────────────────────────────────────────────

  group('legProvider(id)', () {
    test('returns null for unknown id', () async {
      final (c, _) = await _makeContainer();
      expect(await c.read(legProvider('no-such-leg').future), isNull);
    });

    test('returns the correct leg by id', () async {
      final (c, db) = await _makeContainer();
      await db.upsertAll('leg', [
        _legRow(id: 'leg-x', slug: 'tokyo', name: 'Tokyo'),
      ]);
      final leg = await c.read(legProvider('leg-x').future);
      expect(leg, isNotNull);
      expect(leg!.name, 'Tokyo');
    });
  });

  // ── currentLegProvider ────────────────────────────────────────────────────

  group('currentLegProvider', () {
    test('returns null when no legs exist', () async {
      final (c, _) = await _makeContainer();
      expect(await c.read(currentLegProvider.future), isNull);
    });

    test('returns null when no leg spans today', () async {
      final (c, db) = await _makeContainer();
      // Leg entirely in the past.
      await db.upsertAll('leg', [
        _legRow(
          id: 'past-leg',
          slug: 'past',
          startDate: '2020-01-01',
          endDate: '2020-01-10',
        ),
      ]);
      expect(await c.read(currentLegProvider.future), isNull);
    });

    test('returns leg whose date range spans today', () async {
      final (c, db) = await _makeContainer();
      // Build a leg that includes today.
      final yesterday = _dayOffset(-1);
      final tomorrow = _dayOffset(1);
      await db.upsertAll('leg', [
        _legRow(
          id: 'current-leg',
          slug: 'current',
          name: 'Current Leg',
          startDate: yesterday,
          endDate: tomorrow,
        ),
      ]);
      final leg = await c.read(currentLegProvider.future);
      expect(leg, isNotNull);
      expect(leg!.id, 'current-leg');
    });

    test('does not return a future leg as current', () async {
      final (c, db) = await _makeContainer();
      final nextWeek = _dayOffset(7);
      final nextWeekPlus = _dayOffset(14);
      await db.upsertAll('leg', [
        _legRow(
          id: 'future-leg',
          slug: 'future',
          startDate: nextWeek,
          endDate: nextWeekPlus,
        ),
      ]);
      expect(await c.read(currentLegProvider.future), isNull);
    });
  });

  // ── bookingsForLegProvider (family) ───────────────────────────────────────

  group('bookingsForLegProvider(legId)', () {
    test('returns empty list when no bookings for leg', () async {
      final (c, _) = await _makeContainer();
      expect(await c.read(bookingsForLegProvider('leg-1').future), isEmpty);
    });

    test('returns only bookings for the given leg', () async {
      final (c, db) = await _makeContainer();
      await db.upsertAll('booking', [
        _bookingRow(id: 'bk-1', legId: 'leg-1'),
        _bookingRow(id: 'bk-2', legId: 'leg-2'),
      ]);
      final bookings = await c.read(bookingsForLegProvider('leg-1').future);
      expect(bookings, hasLength(1));
      expect(bookings.first.id, 'bk-1');
    });
  });

  // ── tasksForLegProvider (family) ──────────────────────────────────────────

  group('tasksForLegProvider(legId)', () {
    test('returns tasks for a specific leg', () async {
      final (c, db) = await _makeContainer();
      await db.upsertAll('task', [
        _taskRow(id: 'tk-1', legId: 'leg-1'),
        _taskRow(id: 'tk-2', legId: 'leg-2'),
      ]);
      final tasks = await c.read(tasksForLegProvider('leg-1').future);
      expect(tasks, hasLength(1));
      expect(tasks.first.id, 'tk-1');
    });

    test('returns all tasks when legId is null', () async {
      final (c, db) = await _makeContainer();
      await db.upsertAll('task', [
        _taskRow(id: 'tk-1', legId: 'leg-1'),
        _taskRow(id: 'tk-2', legId: null),
      ]);
      final tasks = await c.read(tasksForLegProvider(null).future);
      expect(tasks, hasLength(2));
    });

    test('returns empty list when no tasks', () async {
      final (c, _) = await _makeContainer();
      expect(await c.read(tasksForLegProvider('leg-x').future), isEmpty);
    });
  });

  // ── openTaskCountProvider ────────────────────────────────────────────────

  group('openTaskCountProvider', () {
    test('returns 0 when no tasks', () async {
      final (c, _) = await _makeContainer();
      expect(await c.read(openTaskCountProvider.future), 0);
    });

    test('counts only undone tasks', () async {
      final (c, db) = await _makeContainer();
      await db.upsertAll('task', [
        _taskRow(id: 'tk-1', isDone: false),
        _taskRow(id: 'tk-2', isDone: false),
        _taskRow(id: 'tk-3', isDone: true),
      ]);
      expect(await c.read(openTaskCountProvider.future), 2);
    });
  });

  // ── packingForTripProvider (family) ───────────────────────────────────────

  group('packingForTripProvider(tripId)', () {
    test('returns empty list when no packing items for trip', () async {
      final (c, _) = await _makeContainer();
      expect(await c.read(packingForTripProvider('trip-1').future), isEmpty);
    });

    test('returns only items for the given trip', () async {
      final (c, db) = await _makeContainer();
      await db.upsertAll('packing_item', [
        _packingRow(id: 'pi-1', tripId: 'trip-1'),
        _packingRow(id: 'pi-2', tripId: 'trip-2'),
      ]);
      final items = await c.read(packingForTripProvider('trip-1').future);
      expect(items, hasLength(1));
      expect(items.first.id, 'pi-1');
    });
  });

  // ── journalForLegProvider (family) ────────────────────────────────────────

  group('journalForLegProvider(legId)', () {
    test('returns empty list when no journal entries', () async {
      final (c, _) = await _makeContainer();
      expect(await c.read(journalForLegProvider('leg-1').future), isEmpty);
    });

    test('returns entries for the given leg', () async {
      final (c, db) = await _makeContainer();
      await db.upsertAll('journal_entry', [
        _journalRow(id: 'je-1', legId: 'leg-1'),
        _journalRow(id: 'je-2', legId: 'leg-2'),
      ]);
      final entries = await c.read(journalForLegProvider('leg-1').future);
      expect(entries, hasLength(1));
      expect(entries.first.id, 'je-1');
    });

    test('returns all entries when legId is null', () async {
      final (c, db) = await _makeContainer();
      await db.upsertAll('journal_entry', [
        _journalRow(id: 'je-1', legId: 'leg-1'),
        _journalRow(id: 'je-2', legId: null),
      ]);
      final entries = await c.read(journalForLegProvider(null).future);
      expect(entries, hasLength(2));
    });
  });

  // ── nextBookingProvider ───────────────────────────────────────────────────

  group('nextBookingProvider', () {
    test('returns null when there is no current leg', () async {
      final (c, _) = await _makeContainer();
      // No legs seeded → currentLeg is null → nextBooking is null.
      expect(await c.read(nextBookingProvider.future), isNull);
    });

    test('returns null when current leg has no future bookings', () async {
      final (c, db) = await _makeContainer();
      final yesterday = _dayOffset(-1);
      final tomorrow = _dayOffset(1);
      await db.upsertAll('leg', [
        _legRow(
          id: 'leg-cur',
          slug: 'current',
          startDate: yesterday,
          endDate: tomorrow,
        ),
      ]);
      // Booking in the past — should not be returned.
      await db.upsertAll('booking', [
        _bookingRow(id: 'bk-past', legId: 'leg-cur', startDate: '2020-01-01'),
      ]);
      expect(await c.read(nextBookingProvider.future), isNull);
    });

    test('returns the soonest future booking for the current leg', () async {
      final (c, db) = await _makeContainer();
      final yesterday = _dayOffset(-1);
      final inTwoWeeks = _dayOffset(14);
      final inOneWeek = _dayOffset(7);
      final inThreeWeeks = _dayOffset(21);
      await db.upsertAll('leg', [
        _legRow(
          id: 'leg-cur',
          slug: 'current',
          startDate: yesterday,
          endDate: inThreeWeeks,
        ),
      ]);
      // Two future bookings — the closer one should win.
      await db.upsertAll('booking', [
        _bookingRow(id: 'bk-far', legId: 'leg-cur', startDate: inTwoWeeks),
        _bookingRow(id: 'bk-near', legId: 'leg-cur', startDate: inOneWeek),
      ]);
      final next = await c.read(nextBookingProvider.future);
      expect(next, isNotNull);
      expect(next!.id, 'bk-near');
    });
  });

  // ── schengenProvider ──────────────────────────────────────────────────────

  group('schengenProvider', () {
    test('returns map from api when backend reachable', () async {
      final (c, _) = await _makeContainer(api: _FakeApiOk());
      final result = await c.read(schengenProvider.future);
      expect(result, isNotNull);
      expect(result!['days_used'], 30);
    });

    test('returns null when backend throws', () async {
      final (c, _) = await _makeContainer(api: _FakeApiThrows());
      final result = await c.read(schengenProvider.future);
      expect(result, isNull);
    });
  });

  // ── coverageProvider ──────────────────────────────────────────────────────

  group('coverageProvider', () {
    test('returns list from api when backend reachable', () async {
      final (c, _) = await _makeContainer(api: _FakeApiOk());
      final result = await c.read(coverageProvider.future);
      expect(result, isNotNull);
      expect(result, hasLength(1));
      expect(result!.first['leg_id'], 'leg-1');
    });

    test('returns null when backend throws', () async {
      final (c, _) = await _makeContainer(api: _FakeApiThrows());
      final result = await c.read(coverageProvider.future);
      expect(result, isNull);
    });
  });

  // ── budgetProvider ────────────────────────────────────────────────────────

  group('budgetProvider', () {
    test('returns map from api when backend reachable', () async {
      final (c, _) = await _makeContainer(api: _FakeApiOk());
      final result = await c.read(budgetProvider.future);
      expect(result, isNotNull);
      expect(result!['total_planned_usd'], 5000);
    });

    test('returns null when backend throws', () async {
      final (c, _) = await _makeContainer(api: _FakeApiThrows());
      final result = await c.read(budgetProvider.future);
      expect(result, isNull);
    });
  });
}
