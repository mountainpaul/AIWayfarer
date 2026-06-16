import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wayfarer/models/booking.dart';
import 'package:wayfarer/models/journal_entry.dart';
import 'package:wayfarer/models/leg.dart';
import 'package:wayfarer/models/packing_item.dart';
import 'package:wayfarer/models/task.dart';
import 'package:wayfarer/models/trip.dart';
import 'package:wayfarer/providers/trip_provider.dart';
import 'package:wayfarer/services/api_client.dart';
import 'package:wayfarer/services/local_db.dart';

// ── Fake ApiClient ─────────────────────────────────────────────────────────

/// Tracks which mutating methods were called and with what arguments.
/// Returns minimal valid model objects so TripMutations can succeed.
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');

  final List<String> calls = [];

  // Override to capture calls and optionally throw.
  Object? throwOn; // set to an exception to make ALL mutating calls throw it

  // syncSnapshot always succeeds with an empty payload (no-op merge).
  @override
  Future<Map<String, dynamic>> syncSnapshot({String? since}) async =>
      const {'server_time': '2026-01-01T00:00:00Z'};

  // ── Trips ──────────────────────────────────────────────────────────────

  @override
  Future<Trip> createTrip(Map<String, dynamic> body) async {
    _maybeThrow('createTrip');
    calls.add('createTrip');
    return Trip(
      id: 'new-trip',
      name: body['name'] as String? ?? 'New Trip',
      startDate: body['start_date'] as String? ?? '2026-07-01',
      endDate: body['end_date'] as String? ?? '2026-08-31',
    );
  }

  @override
  Future<Trip> patchTrip(String id, Map<String, dynamic> patch) async {
    _maybeThrow('patchTrip');
    calls.add('patchTrip:$id');
    return Trip(
      id: id,
      name: patch['name'] as String? ?? 'Trip',
      startDate: '2026-07-01',
      endDate: '2026-08-31',
    );
  }

  @override
  Future<void> deleteTrip(String id) async {
    _maybeThrow('deleteTrip');
    calls.add('deleteTrip:$id');
  }

  // ── Bookings ──────────────────────────────────────────────────────────

  @override
  Future<Booking> createBooking(Map<String, dynamic> body) async {
    _maybeThrow('createBooking');
    calls.add('createBooking');
    return Booking(
      id: 'new-bk',
      legId: body['leg_id'] as String? ?? 'leg-1',
      type: body['type'] as String? ?? 'accommodation',
      name: body['name'] as String? ?? 'Hotel',
      status: 'confirmed',
    );
  }

  @override
  Future<Booking> patchBooking(String id, Map<String, dynamic> patch) async {
    _maybeThrow('patchBooking');
    calls.add('patchBooking:$id');
    return Booking(
      id: id,
      legId: 'leg-1',
      type: 'accommodation',
      name: patch['name'] as String? ?? 'Hotel',
      status: 'confirmed',
    );
  }

  @override
  Future<void> deleteBooking(String id) async {
    _maybeThrow('deleteBooking');
    calls.add('deleteBooking:$id');
  }

  // ── Tasks ──────────────────────────────────────────────────────────────

  @override
  Future<Task> createTask(Map<String, dynamic> body) async {
    _maybeThrow('createTask');
    calls.add('createTask');
    return Task(
      id: 'new-tk',
      title: body['title'] as String? ?? 'Task',
      priority: body['priority'] as String? ?? 'medium',
    );
  }

  @override
  Future<Task> patchTask(String id, Map<String, dynamic> patch) async {
    _maybeThrow('patchTask');
    calls.add('patchTask:$id');
    return Task(
      id: id,
      title: patch['title'] as String? ?? 'Task',
      priority: 'medium',
    );
  }

  @override
  Future<void> deleteTask(String id) async {
    _maybeThrow('deleteTask');
    calls.add('deleteTask:$id');
  }

  @override
  Future<Task> toggleTaskDone(String id) async {
    _maybeThrow('toggleTaskDone');
    calls.add('toggleTaskDone:$id');
    return Task(id: id, title: 'Task', priority: 'medium', isDone: true);
  }

  // ── Packing ────────────────────────────────────────────────────────────

  @override
  Future<PackingItem> togglePacked(String id) async {
    _maybeThrow('togglePacked');
    calls.add('togglePacked:$id');
    return PackingItem(
      id: id,
      tripId: 'trip-1',
      category: 'clothes',
      name: 'T-shirt',
      isPacked: true,
      sortOrder: 0,
    );
  }

  // ── Journal ────────────────────────────────────────────────────────────

  @override
  Future<JournalEntry> createJournal(Map<String, dynamic> body) async {
    _maybeThrow('createJournal');
    calls.add('createJournal');
    return JournalEntry(
      id: 'new-je',
      content: body['content'] as String? ?? '',
      entryType: body['entry_type'] as String? ?? 'note',
    );
  }

  // ── Legs ───────────────────────────────────────────────────────────────

  @override
  Future<Leg> createLeg(Map<String, dynamic> body) async {
    _maybeThrow('createLeg');
    calls.add('createLeg');
    return Leg(
      id: 'new-leg',
      tripId: body['trip_id'] as String? ?? 'trip-1',
      slug: 'new-leg',
      name: body['name'] as String? ?? 'New Leg',
      startDate: body['start_date'] as String? ?? '2026-06-01',
      endDate: body['end_date'] as String? ?? '2026-06-30',
    );
  }

  void _maybeThrow(String method) {
    final e = throwOn;
    if (e != null) throw e;
  }
}

// ── DioException factory (server rejection) ──────────────────────────────

DioException _serverRejection(int statusCode) {
  final opts = RequestOptions(path: '/test');
  return DioException(
    requestOptions: opts,
    response: Response<void>(requestOptions: opts, statusCode: statusCode),
    type: DioExceptionType.badResponse,
  );
}

// ── DioException factory (unreachable) ───────────────────────────────────

DioException _connectionError() => DioException(
      requestOptions: RequestOptions(path: '/test'),
      type: DioExceptionType.connectionError,
    );

// ── Test container factory ───────────────────────────────────────────────

Future<(ProviderContainer, LocalDb)> _makeContainer(_FakeApi api) async {
  final db = LocalDb.newForTest();
  await db.init(pathOverride: inMemoryDatabasePath);

  final container = ProviderContainer(overrides: [
    apiClientProvider.overrideWithValue(api),
    localDbProvider.overrideWithValue(db),
  ]);
  addTearDown(container.dispose);
  addTearDown(db.close);
  return (container, db);
}

TripMutations _mutations(ProviderContainer c) => c.read(tripMutationsProvider);

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ── TripMutations – happy paths ──────────────────────────────────────────

  group('TripMutations happy paths', () {
    group('Trip CRUD', () {
      test('createTrip calls API and returns true', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok = await _mutations(c).createTrip({
          'name': 'Greece 2026',
          'start_date': '2026-09-01',
          'end_date': '2026-09-30',
        });
        expect(ok, isTrue);
        expect(api.calls, contains('createTrip'));
      });

      test('updateTrip calls patchTrip and returns true', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok = await _mutations(c).updateTrip('trip-1', {'name': 'Updated'});
        expect(ok, isTrue);
        expect(api.calls, contains('patchTrip:trip-1'));
      });

      test('deleteTrip calls deleteTrip API and returns true', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok = await _mutations(c).deleteTrip('trip-1');
        expect(ok, isTrue);
        expect(api.calls, contains('deleteTrip:trip-1'));
      });
    });

    group('Booking CRUD', () {
      test('createBooking calls API and returns true', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok = await _mutations(c).createBooking({
          'leg_id': 'leg-1',
          'type': 'accommodation',
          'name': 'Hilton',
          'status': 'confirmed',
        });
        expect(ok, isTrue);
        expect(api.calls, contains('createBooking'));
      });

      test('updateBooking calls patchBooking and returns true', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok =
            await _mutations(c).updateBooking('bk-1', {'notes': 'pool view'});
        expect(ok, isTrue);
        expect(api.calls, contains('patchBooking:bk-1'));
      });

      test('deleteBooking calls deleteBooking API and returns true', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok = await _mutations(c).deleteBooking('bk-1');
        expect(ok, isTrue);
        expect(api.calls, contains('deleteBooking:bk-1'));
      });
    });

    group('Task CRUD', () {
      test('createTask calls API and returns true', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok = await _mutations(c).createTask({
          'title': 'Pack bags',
          'priority': 'high',
        });
        expect(ok, isTrue);
        expect(api.calls, contains('createTask'));
      });

      test('updateTask calls patchTask and returns true', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok =
            await _mutations(c).updateTask('tk-1', {'title': 'Pack light bags'});
        expect(ok, isTrue);
        expect(api.calls, contains('patchTask:tk-1'));
      });

      test('deleteTask calls deleteTask API and returns true', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok = await _mutations(c).deleteTask('tk-1');
        expect(ok, isTrue);
        expect(api.calls, contains('deleteTask:tk-1'));
      });
    });

    group('Toggles', () {
      test('toggleTaskDone calls API and returns true', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok = await _mutations(c).toggleTaskDone('tk-1');
        expect(ok, isTrue);
        expect(api.calls, contains('toggleTaskDone:tk-1'));
      });

      test('togglePacked calls API and returns true', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok = await _mutations(c).togglePacked('pk-1');
        expect(ok, isTrue);
        expect(api.calls, contains('togglePacked:pk-1'));
      });
    });

    group('Journal', () {
      test('addJournal calls createJournal and returns true', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok = await _mutations(c).addJournal(
          legId: 'leg-1',
          content: 'Beautiful sunset',
          entryType: 'highlight',
        );
        expect(ok, isTrue);
        expect(api.calls, contains('createJournal'));
      });

      test('addJournal works without legId', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final ok =
            await _mutations(c).addJournal(content: 'General note');
        expect(ok, isTrue);
        expect(api.calls, contains('createJournal'));
      });
    });

    group('syncTrigger is bumped on success', () {
      test('updateTrip bumps syncTrigger', () async {
        final api = _FakeApi();
        final (c, _) = await _makeContainer(api);
        final before = c.read(syncTriggerProvider);
        await _mutations(c).updateTrip('trip-1', {'name': 'Updated'});
        expect(c.read(syncTriggerProvider), greaterThan(before));
      });
    });
  });

  // ── TripMutations – online-only mutations return false on any error ───────

  group('TripMutations online-only ops return false on failure', () {
    test('createTrip returns false when offline', () async {
      final api = _FakeApi()..throwOn = ApiUnreachable('down');
      final (c, _) = await _makeContainer(api);
      final ok = await _mutations(c).createTrip({'name': 'x'});
      expect(ok, isFalse);
    });

    test('createBooking returns false when offline', () async {
      final api = _FakeApi()..throwOn = ApiUnreachable('down');
      final (c, _) = await _makeContainer(api);
      final ok = await _mutations(c).createBooking({'name': 'x'});
      expect(ok, isFalse);
    });

    test('createTask returns false when offline', () async {
      final api = _FakeApi()..throwOn = ApiUnreachable('down');
      final (c, _) = await _makeContainer(api);
      final ok = await _mutations(c).createTask({'title': 'x', 'priority': 'low'});
      expect(ok, isFalse);
    });

    test('toggleTaskDone returns false when offline', () async {
      final api = _FakeApi()..throwOn = ApiUnreachable('down');
      final (c, _) = await _makeContainer(api);
      final ok = await _mutations(c).toggleTaskDone('tk-1');
      expect(ok, isFalse);
    });

    test('togglePacked returns false when offline', () async {
      final api = _FakeApi()..throwOn = ApiUnreachable('down');
      final (c, _) = await _makeContainer(api);
      final ok = await _mutations(c).togglePacked('pk-1');
      expect(ok, isFalse);
    });

    test('addJournal returns false when offline', () async {
      final api = _FakeApi()..throwOn = ApiUnreachable('down');
      final (c, _) = await _makeContainer(api);
      final ok = await _mutations(c).addJournal(content: 'note');
      expect(ok, isFalse);
    });
  });

  // ── _queueIfOffline: updateTrip ──────────────────────────────────────────

  group('_queueIfOffline — updateTrip', () {
    test(
        'offline update applies local patch, enqueues op, bumps trigger, returns true',
        () async {
      final api = _FakeApi()..throwOn = _connectionError();
      final (c, db) = await _makeContainer(api);

      // Seed a trip in local DB so localPatch has a row to update.
      await db.upsertAll('trip', [
        {
          'id': 'trip-1',
          'name': 'Old Name',
          'start_date': '2026-07-01',
          'end_date': '2026-08-31',
          'status': 'planning',
          'updated_at': '2026-01-01T00:00:00Z',
        }
      ]);

      final before = c.read(syncTriggerProvider);
      final ok =
          await _mutations(c).updateTrip('trip-1', {'name': 'New Name'});

      expect(ok, isTrue);

      // Local patch was applied.
      final trips = await db.trips();
      expect(trips.any((t) => t.id == 'trip-1' && t.name == 'New Name'),
          isTrue);

      // Op is in the outbox.
      final ops = await db.pendingOps();
      expect(ops.length, 1);
      expect(ops.first['entity'], 'trip');
      expect(ops.first['op'], 'update');
      expect(ops.first['entity_id'], 'trip-1');
      final payload =
          jsonDecode(ops.first['payload'] as String) as Map<String, dynamic>;
      expect(payload['name'], 'New Name');

      // Sync trigger bumped.
      expect(c.read(syncTriggerProvider), greaterThan(before));
    });

    test('server rejection on updateTrip returns false, nothing queued',
        () async {
      final api = _FakeApi()..throwOn = _serverRejection(422);
      final (c, db) = await _makeContainer(api);

      final ok =
          await _mutations(c).updateTrip('trip-1', {'name': 'Whatever'});

      expect(ok, isFalse);
      expect(await db.pendingOpCount(), 0);
    });
  });

  // ── _queueIfOffline — deleteTrip ─────────────────────────────────────────

  group('_queueIfOffline — deleteTrip', () {
    test(
        'offline delete tombstones locally, enqueues delete op, bumps trigger, returns true',
        () async {
      final api = _FakeApi()..throwOn = _connectionError();
      final (c, db) = await _makeContainer(api);

      // Seed the row.
      await db.upsertAll('trip', [
        {
          'id': 'trip-del',
          'name': 'To Delete',
          'start_date': '2026-07-01',
          'end_date': '2026-07-31',
          'status': 'planning',
          'updated_at': '2026-01-01T00:00:00Z',
        }
      ]);

      final before = c.read(syncTriggerProvider);
      final ok = await _mutations(c).deleteTrip('trip-del');

      expect(ok, isTrue);

      // Row is soft-deleted locally (trips() hides deleted_at IS NOT NULL).
      final trips = await db.trips();
      expect(trips.any((t) => t.id == 'trip-del'), isFalse);

      // Delete op enqueued.
      final ops = await db.pendingOps();
      expect(ops.length, 1);
      expect(ops.first['entity'], 'trip');
      expect(ops.first['op'], 'delete');

      // Trigger bumped.
      expect(c.read(syncTriggerProvider), greaterThan(before));
    });

    test('server rejection on deleteTrip returns false, nothing queued',
        () async {
      final api = _FakeApi()..throwOn = _serverRejection(403);
      final (c, db) = await _makeContainer(api);

      final ok = await _mutations(c).deleteTrip('trip-1');

      expect(ok, isFalse);
      expect(await db.pendingOpCount(), 0);
    });
  });

  // ── _queueIfOffline — updateBooking ──────────────────────────────────────

  group('_queueIfOffline — updateBooking', () {
    test('offline updateBooking enqueues and returns true', () async {
      final api = _FakeApi()..throwOn = _connectionError();
      final (c, db) = await _makeContainer(api);

      await db.upsertAll('booking', [
        {
          'id': 'bk-1',
          'leg_id': 'leg-1',
          'type': 'accommodation',
          'name': 'Old Hotel',
          'status': 'confirmed',
          'updated_at': '2026-01-01T00:00:00Z',
        }
      ]);

      final ok =
          await _mutations(c).updateBooking('bk-1', {'name': 'New Hotel'});

      expect(ok, isTrue);

      final ops = await db.pendingOps();
      expect(ops.length, 1);
      expect(ops.first['entity'], 'booking');
      expect(ops.first['op'], 'update');

      final bookings = await db.bookings(legId: 'leg-1');
      expect(bookings.any((b) => b.name == 'New Hotel'), isTrue);
    });

    test('server rejection on updateBooking returns false', () async {
      final api = _FakeApi()..throwOn = _serverRejection(500);
      final (c, db) = await _makeContainer(api);

      final ok = await _mutations(c).updateBooking('bk-1', {'name': 'x'});
      expect(ok, isFalse);
      expect(await db.pendingOpCount(), 0);
    });
  });

  // ── _queueIfOffline — deleteBooking ──────────────────────────────────────

  group('_queueIfOffline — deleteBooking', () {
    test('offline deleteBooking tombstones locally and enqueues', () async {
      final api = _FakeApi()..throwOn = _connectionError();
      final (c, db) = await _makeContainer(api);

      await db.upsertAll('booking', [
        {
          'id': 'bk-del',
          'leg_id': 'leg-1',
          'type': 'flight',
          'name': 'Flight AA001',
          'status': 'confirmed',
          'updated_at': '2026-01-01T00:00:00Z',
        }
      ]);

      final ok = await _mutations(c).deleteBooking('bk-del');

      expect(ok, isTrue);
      expect(await db.pendingOpCount(), 1);

      final bookings = await db.bookings(legId: 'leg-1');
      expect(bookings.any((b) => b.id == 'bk-del'), isFalse);
    });
  });

  // ── _queueIfOffline — updateTask / deleteTask ─────────────────────────────

  group('_queueIfOffline — updateTask', () {
    test('offline updateTask enqueues and returns true', () async {
      final api = _FakeApi()..throwOn = _connectionError();
      final (c, db) = await _makeContainer(api);

      await db.upsertAll('task', [
        {
          'id': 'tk-1',
          'title': 'Old title',
          'priority': 'medium',
          'is_done': 0,
          'updated_at': '2026-01-01T00:00:00Z',
        }
      ]);

      final ok =
          await _mutations(c).updateTask('tk-1', {'title': 'New title'});

      expect(ok, isTrue);

      final ops = await db.pendingOps();
      expect(ops.length, 1);
      expect(ops.first['entity'], 'task');
      expect(ops.first['op'], 'update');

      final tasks = await db.tasks();
      expect(tasks.any((t) => t.title == 'New title'), isTrue);
    });

    test('offline deleteTask tombstones and enqueues', () async {
      final api = _FakeApi()..throwOn = _connectionError();
      final (c, db) = await _makeContainer(api);

      await db.upsertAll('task', [
        {
          'id': 'tk-del',
          'title': 'Going away',
          'priority': 'low',
          'is_done': 0,
          'updated_at': '2026-01-01T00:00:00Z',
        }
      ]);

      final ok = await _mutations(c).deleteTask('tk-del');

      expect(ok, isTrue);
      expect(await db.pendingOpCount(), 1);

      final tasks = await db.tasks();
      expect(tasks.any((t) => t.id == 'tk-del'), isFalse);
    });
  });

  // ── Multiple offline edits accumulate in outbox ───────────────────────────

  group('multiple offline edits accumulate in outbox', () {
    test('two offline updates produce two pending ops', () async {
      final api = _FakeApi()..throwOn = _connectionError();
      final (c, db) = await _makeContainer(api);

      await db.upsertAll('booking', [
        {
          'id': 'bk-a',
          'leg_id': 'leg-1',
          'type': 'accommodation',
          'name': 'Hotel A',
          'status': 'confirmed',
          'updated_at': '2026-01-01T00:00:00Z',
        },
        {
          'id': 'bk-b',
          'leg_id': 'leg-1',
          'type': 'accommodation',
          'name': 'Hotel B',
          'status': 'confirmed',
          'updated_at': '2026-01-01T00:00:00Z',
        }
      ]);

      await _mutations(c).updateBooking('bk-a', {'notes': 'edit 1'});
      await _mutations(c).updateBooking('bk-b', {'notes': 'edit 2'});

      expect(await db.pendingOpCount(), 2);
    });
  });

  // ── TripMutations.createLeg ───────────────────────────────────────────────

  group('TripMutations.createLeg', () {
    test('success: calls createLeg API, bumps syncTrigger, returns true',
        () async {
      final api = _FakeApi();
      final (c, _) = await _makeContainer(api);
      final before = c.read(syncTriggerProvider);

      final ok = await _mutations(c).createLeg({
        'trip_id': 'trip-1',
        'name': 'Austria',
        'start_date': '2026-08-06',
        'end_date': '2026-08-20',
        'is_schengen': true,
        'sort_order': 1,
      });

      expect(ok, isTrue);
      expect(api.calls, contains('createLeg'));
      expect(c.read(syncTriggerProvider), greaterThan(before));
    });

    test('failure: fake throws → returns false', () async {
      final api = _FakeApi()..throwOn = ApiUnreachable('down');
      final (c, _) = await _makeContainer(api);

      final ok = await _mutations(c).createLeg({
        'trip_id': 'trip-1',
        'name': 'Austria',
        'start_date': '2026-08-06',
        'end_date': '2026-08-20',
        'sort_order': 1,
      });

      expect(ok, isFalse);
      expect(api.calls, isNot(contains('createLeg')));
    });

    test('server rejection returns false', () async {
      final api = _FakeApi()..throwOn = _serverRejection(422);
      final (c, _) = await _makeContainer(api);

      final ok = await _mutations(c).createLeg({'name': 'x', 'trip_id': 't'});

      expect(ok, isFalse);
    });
  });
}
