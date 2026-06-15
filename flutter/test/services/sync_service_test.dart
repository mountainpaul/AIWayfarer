import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wayfarer/models/booking.dart';
import 'package:wayfarer/models/packing_item.dart';
import 'package:wayfarer/models/task.dart';
import 'package:wayfarer/models/trip.dart';
import 'package:wayfarer/services/api_client.dart';
import 'package:wayfarer/services/local_db.dart';
import 'package:wayfarer/services/sync_service.dart';

// ── Fake ApiClient ─────────────────────────────────────────────────────────

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');

  // Control what syncSnapshot returns / throws.
  Object? snapshotError;
  Map<String, dynamic> snapshotPayload = const {'server_time': '2026-01-01T00:00:00Z'};

  // Track which patch/delete calls were replayed.
  final List<String> calls = [];

  // Error to throw on replay (null = success).
  Object? replayError;

  @override
  Future<Map<String, dynamic>> syncSnapshot({String? since}) async {
    if (snapshotError != null) throw snapshotError!;
    return snapshotPayload;
  }

  @override
  Future<Booking> patchBooking(String id, Map<String, dynamic> patch) async {
    if (replayError != null) throw replayError!;
    calls.add('patchBooking:$id');
    return const Booking(
        id: 'bk', legId: 'leg', type: 'flight', name: 'x', status: 'confirmed');
  }

  @override
  Future<void> deleteBooking(String id) async {
    if (replayError != null) throw replayError!;
    calls.add('deleteBooking:$id');
  }

  @override
  Future<Task> patchTask(String id, Map<String, dynamic> patch) async {
    if (replayError != null) throw replayError!;
    calls.add('patchTask:$id');
    return const Task(id: 'tk', title: 'x', priority: 'low');
  }

  @override
  Future<void> deleteTask(String id) async {
    if (replayError != null) throw replayError!;
    calls.add('deleteTask:$id');
  }

  @override
  Future<Trip> patchTrip(String id, Map<String, dynamic> patch) async {
    if (replayError != null) throw replayError!;
    calls.add('patchTrip:$id');
    return const Trip(
        id: 'tr', name: 'x', startDate: '2026-01-01', endDate: '2026-01-31');
  }

  @override
  Future<void> deleteTrip(String id) async {
    if (replayError != null) throw replayError!;
    calls.add('deleteTrip:$id');
  }

  @override
  Future<PackingItem> patchPacking(String id, Map<String, dynamic> patch) async {
    if (replayError != null) throw replayError!;
    calls.add('patchPacking:$id');
    return const PackingItem(
        id: 'pk', tripId: 'trip', category: 'c', name: 'x', sortOrder: 0);
  }
}

// ── Helper to build a DioException with a real response (server rejection) ──

DioException _serverRejection(int statusCode) {
  final response = Response<void>(
    requestOptions: RequestOptions(path: '/test'),
    statusCode: statusCode,
  );
  return DioException(
    requestOptions: response.requestOptions,
    response: response,
    type: DioExceptionType.badResponse,
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // SyncService.snapshot() reads the delta cursor from SharedPreferences;
    // seed an empty in-memory store so it works without a platform channel.
    SharedPreferences.setMockInitialValues({});
  });

  Future<LocalDb> makeDb() async {
    final db = LocalDb.newForTest();
    await db.init(pathOverride: inMemoryDatabasePath);
    return db;
  }

  SyncService makeService(_FakeApi api, LocalDb db) =>
      SyncService(api: api, db: db);

  // ── snapshot() – happy path ──────────────────────────────────────────────

  group('SyncService.snapshot() happy path', () {
    test('returns true when backend responds', () async {
      final db = await makeDb();
      addTearDown(db.close);
      final api = _FakeApi()
        ..snapshotPayload = const {
          'server_time': '2026-06-01T12:00:00Z',
          'trips': <dynamic>[],
          'bookings': <dynamic>[],
        };
      final svc = makeService(api, db);

      final result = await svc.snapshot();

      expect(result, isTrue);
    });

    test('merges incoming rows into local DB', () async {
      final db = await makeDb();
      addTearDown(db.close);
      final api = _FakeApi()
        ..snapshotPayload = {
          'server_time': '2026-06-01T12:00:00Z',
          'trips': [
            {
              'id': 'trip-1',
              'name': 'Europe 2026',
              'start_date': '2026-07-01',
              'end_date': '2026-08-31',
              'status': 'planning',
              'updated_at': '2026-06-01T00:00:00Z',
            }
          ],
        };
      final svc = makeService(api, db);

      await svc.snapshot();

      final trips = await db.trips();
      expect(trips.length, 1);
      expect(trips.first.name, 'Europe 2026');
    });

    test('ignores unknown snapshot keys gracefully', () async {
      final db = await makeDb();
      addTearDown(db.close);
      final api = _FakeApi()
        ..snapshotPayload = const {
          'server_time': '2026-06-01T12:00:00Z',
          'unknown_future_table': [
            {'id': 'x'}
          ],
        };
      final svc = makeService(api, db);

      // Should not throw.
      expect(await svc.snapshot(), isTrue);
    });
  });

  // ── snapshot() – offline ─────────────────────────────────────────────────

  group('SyncService.snapshot() offline', () {
    test('returns false when backend is unreachable', () async {
      final db = await makeDb();
      addTearDown(db.close);
      final api = _FakeApi()
        ..snapshotError = ApiUnreachable('down');
      final svc = makeService(api, db);

      final result = await svc.snapshot();

      expect(result, isFalse);
    });
  });

  // ── _flushOutbox: replays queued ops then clears them ──────────────────

  group('SyncService._flushOutbox via snapshot()', () {
    test('replays a queued booking.update op and removes it', () async {
      final db = await makeDb();
      addTearDown(db.close);
      final api = _FakeApi();
      final svc = makeService(api, db);

      await db.enqueueOp(
        entity: 'booking',
        entityId: 'bk-1',
        op: 'update',
        payloadJson: '{"notes":"queued edit"}',
        queuedAt: '2026-06-01T10:00:00Z',
      );

      expect(await db.pendingOpCount(), 1);

      await svc.snapshot();

      expect(api.calls, contains('patchBooking:bk-1'));
      expect(await db.pendingOpCount(), 0);
    });

    test('replays a queued task.delete op and removes it', () async {
      final db = await makeDb();
      addTearDown(db.close);
      final api = _FakeApi();
      final svc = makeService(api, db);

      await db.enqueueOp(
        entity: 'task',
        entityId: 'tk-99',
        op: 'delete',
        payloadJson: null,
        queuedAt: '2026-06-01T10:00:00Z',
      );

      await svc.snapshot();

      expect(api.calls, contains('deleteTask:tk-99'));
      expect(await db.pendingOpCount(), 0);
    });

    test('replays a queued trip.update op and removes it', () async {
      final db = await makeDb();
      addTearDown(db.close);
      final api = _FakeApi();
      final svc = makeService(api, db);

      await db.enqueueOp(
        entity: 'trip',
        entityId: 'tr-1',
        op: 'update',
        payloadJson: '{"name":"Updated Trip"}',
        queuedAt: '2026-06-01T10:00:00Z',
      );

      await svc.snapshot();

      expect(api.calls, contains('patchTrip:tr-1'));
      expect(await db.pendingOpCount(), 0);
    });

    test('replays multiple queued ops in order', () async {
      final db = await makeDb();
      addTearDown(db.close);
      final api = _FakeApi();
      final svc = makeService(api, db);

      await db.enqueueOp(
        entity: 'booking',
        entityId: 'bk-1',
        op: 'update',
        payloadJson: '{}',
        queuedAt: '2026-06-01T10:00:00Z',
      );
      await db.enqueueOp(
        entity: 'booking',
        entityId: 'bk-2',
        op: 'delete',
        payloadJson: null,
        queuedAt: '2026-06-01T10:01:00Z',
      );

      await svc.snapshot();

      expect(api.calls, ['patchBooking:bk-1', 'deleteBooking:bk-2']);
      expect(await db.pendingOpCount(), 0);
    });

    test('keeps queued op when backend is unreachable during replay', () async {
      final db = await makeDb();
      addTearDown(db.close);
      // Throws ApiUnreachable on replay but succeeds on syncSnapshot.
      // We need to simulate: replay throws unreachable → snapshot also throws.
      // In practice snapshot() catches all errors from _flushOutbox too.
      // We simulate by making the API unreachable entirely (so snapshot returns false).
      final api = _FakeApi()
        ..replayError = DioException(
          requestOptions: RequestOptions(path: '/bookings/bk-1'),
          type: DioExceptionType.connectionError,
          // No response → mapDioError returns ApiUnreachable
        );

      await db.enqueueOp(
        entity: 'booking',
        entityId: 'bk-1',
        op: 'update',
        payloadJson: '{"notes":"offline edit"}',
        queuedAt: '2026-06-01T10:00:00Z',
      );

      // Also make syncSnapshot fail so snapshot() returns false.
      api.snapshotError = ApiUnreachable('down');

      final svc = makeService(api, db);
      final result = await svc.snapshot();

      // Snapshot fails overall.
      expect(result, isFalse);
      // Op was NOT removed — still in outbox.
      expect(await db.pendingOpCount(), 1);
    });

    test('drops op when server actively rejects it (4xx)', () async {
      final db = await makeDb();
      addTearDown(db.close);
      final api = _FakeApi()
        ..replayError = _serverRejection(404);
      final svc = makeService(api, db);

      await db.enqueueOp(
        entity: 'task',
        entityId: 'tk-gone',
        op: 'delete',
        payloadJson: null,
        queuedAt: '2026-06-01T10:00:00Z',
      );

      // snapshot() calls _flushOutbox first; the op is rejected (404 → server
      // responded → not ApiUnreachable) so it's dropped. Then syncSnapshot
      // proceeds normally.
      await svc.snapshot();

      expect(await db.pendingOpCount(), 0);
    });

    test('stops flush at first unreachable op, keeping it and later ops', () async {
      final db = await makeDb();
      addTearDown(db.close);

      // Both replay calls fail with a connection error (no response →
      // ApiUnreachable). The flush loop breaks on the first failure, so bk-2
      // is never even attempted. Both ops remain in the outbox.
      final api = _FakeApi()
        ..replayError = DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        )
        ..snapshotError = ApiUnreachable('down');

      await db.enqueueOp(
        entity: 'booking',
        entityId: 'bk-1',
        op: 'update',
        payloadJson: '{}',
        queuedAt: '2026-06-01T10:00:00Z',
      );
      await db.enqueueOp(
        entity: 'booking',
        entityId: 'bk-2',
        op: 'delete',
        payloadJson: null,
        queuedAt: '2026-06-01T10:01:00Z',
      );

      final svc = makeService(api, db);
      await svc.snapshot();

      // Both ops are retained — the first fails as unreachable, which breaks
      // the loop before bk-2 is even attempted.
      expect(await db.pendingOpCount(), 2);
    });
  });
}
