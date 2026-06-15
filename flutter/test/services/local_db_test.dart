import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:wayfarer/models/briefing.dart';
import 'package:wayfarer/services/local_db.dart';

// ── helpers ────────────────────────────────────────────────────────────────

Map<String, dynamic> _trip({
  String id = 'trip-1',
  String name = 'Test Trip',
  String startDate = '2026-01-01',
  String endDate = '2026-01-31',
  String status = 'planning',
  String? updatedAt,
  String? deletedAt,
}) =>
    {
      'id': id,
      'name': name,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
      'created_at': '2026-01-01T00:00:00Z',
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    };

Map<String, dynamic> _leg({
  String id = 'leg-1',
  String tripId = 'trip-1',
  String slug = 'paris',
  String name = 'Paris',
  int sortOrder = 0,
  bool isSchengen = false,
  String? updatedAt,
  String? deletedAt,
}) =>
    {
      'id': id,
      'trip_id': tripId,
      'slug': slug,
      'name': name,
      'start_date': '2026-01-01',
      'end_date': '2026-01-10',
      'is_schengen': isSchengen,
      'sort_order': sortOrder,
      'currency': 'USD',
      'created_at': '2026-01-01T00:00:00Z',
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    };

Map<String, dynamic> _booking({
  String id = 'bk-1',
  String legId = 'leg-1',
  String? updatedAt,
  String? deletedAt,
}) =>
    {
      'id': id,
      'leg_id': legId,
      'type': 'flight',
      'name': 'Air Test',
      'status': 'confirmed',
      'currency': 'USD',
      'created_at': '2026-01-01T00:00:00Z',
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    };

Map<String, dynamic> _task({
  String id = 'task-1',
  String? legId = 'leg-1',
  bool isDone = false,
  String? dueDate,
  String? updatedAt,
  String? deletedAt,
}) =>
    {
      'id': id,
      if (legId != null) 'leg_id': legId,
      'title': 'Pack bags',
      'priority': 'high',
      'is_done': isDone,
      if (dueDate != null) 'due_date': dueDate,
      'created_at': '2026-01-01T00:00:00Z',
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    };

Map<String, dynamic> _packingItem({
  String id = 'pi-1',
  String tripId = 'trip-1',
  bool isPacked = false,
  String? updatedAt,
  String? deletedAt,
}) =>
    {
      'id': id,
      'trip_id': tripId,
      'category': 'clothes',
      'name': 'T-shirt',
      'is_packed': isPacked,
      'sort_order': 0,
      'created_at': '2026-01-01T00:00:00Z',
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    };

Map<String, dynamic> _journalEntry({
  String id = 'je-1',
  String? legId = 'leg-1',
  String createdAt = '2026-01-05T12:00:00Z',
  String? deletedAt,
}) =>
    {
      'id': id,
      if (legId != null) 'leg_id': legId,
      'content': 'Great day!',
      'entry_type': 'note',
      'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    };

Map<String, dynamic> _briefingRow({
  String id = 'br-1',
  String date = '2026-01-01',
  String? deletedAt,
}) =>
    {
      'id': id,
      'date': date,
      'markdown': '## Today\nHave fun.',
      'created_at': '2026-01-01T06:00:00Z',
      if (deletedAt != null) 'deleted_at': deletedAt,
    };

// ── test suite ─────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalDb db;

  setUp(() async {
    db = LocalDb.newForTest();
    await db.init(pathOverride: inMemoryDatabasePath);
  });

  tearDown(() async => db.close());

  // ── 1. Schema / init ────────────────────────────────────────────────────

  group('schema / init', () {
    test('trips() returns empty list on fresh DB', () async {
      expect(await db.trips(), isEmpty);
    });

    test('legs() returns empty list on fresh DB', () async {
      expect(await db.legs(), isEmpty);
    });

    test('bookings() returns empty list on fresh DB', () async {
      expect(await db.bookings(), isEmpty);
    });

    test('tasks() returns empty list on fresh DB', () async {
      expect(await db.tasks(), isEmpty);
    });

    test('packing() returns empty list on fresh DB', () async {
      expect(await db.packing(), isEmpty);
    });

    test('journal() returns empty list on fresh DB', () async {
      expect(await db.journal(), isEmpty);
    });

    test('latestBriefing() returns null on fresh DB', () async {
      expect(await db.latestBriefing(), isNull);
    });

    test('pendingOpCount() is 0 on fresh DB', () async {
      expect(await db.pendingOpCount(), 0);
    });

    test('init is idempotent (second call is a no-op)', () async {
      // Should not throw or reset the DB.
      await db.init(pathOverride: inMemoryDatabasePath);
      await db.upsertAll('trip', [_trip()]);
      await db.init(pathOverride: inMemoryDatabasePath);
      expect(await db.trips(), hasLength(1));
    });
  });

  // ── 2. upsertAll + typed read APIs ─────────────────────────────────────

  group('upsertAll + read APIs', () {
    test('upsertAll trips — trips() returns typed models', () async {
      await db.upsertAll('trip', [_trip(id: 'trip-1', name: 'Japan 2026')]);
      final result = await db.trips();
      expect(result, hasLength(1));
      expect(result.first.id, 'trip-1');
      expect(result.first.name, 'Japan 2026');
      expect(result.first.startDate, '2026-01-01');
    });

    test('trips() ordered by start_date', () async {
      await db.upsertAll('trip', [
        _trip(id: 'b', startDate: '2026-06-01', endDate: '2026-06-30'),
        _trip(id: 'a', startDate: '2026-01-01', endDate: '2026-01-31'),
      ]);
      final result = await db.trips();
      expect(result.map((t) => t.id).toList(), ['a', 'b']);
    });

    test('legs() returns all legs without tripId filter', () async {
      await db.upsertAll('leg', [
        _leg(id: 'l1', tripId: 'trip-1', slug: 'paris', sortOrder: 0),
        _leg(id: 'l2', tripId: 'trip-2', slug: 'rome', sortOrder: 1),
      ]);
      expect(await db.legs(), hasLength(2));
    });

    test('legs(tripId:) filters by trip', () async {
      await db.upsertAll('leg', [
        _leg(id: 'l1', tripId: 'trip-1', slug: 'paris', sortOrder: 0),
        _leg(id: 'l2', tripId: 'trip-2', slug: 'rome', sortOrder: 0),
      ]);
      final result = await db.legs(tripId: 'trip-1');
      expect(result, hasLength(1));
      expect(result.first.id, 'l1');
    });

    test('legs(tripId:) ordered by sort_order', () async {
      await db.upsertAll('leg', [
        _leg(id: 'l2', tripId: 'trip-1', slug: 'rome', sortOrder: 2),
        _leg(id: 'l1', tripId: 'trip-1', slug: 'paris', sortOrder: 1),
      ]);
      final result = await db.legs(tripId: 'trip-1');
      expect(result.map((l) => l.id).toList(), ['l1', 'l2']);
    });

    test('leg(id) returns single leg', () async {
      await db.upsertAll('leg', [_leg(id: 'l1')]);
      final result = await db.leg('l1');
      expect(result, isNotNull);
      expect(result!.id, 'l1');
    });

    test('leg(id) returns null for unknown id', () async {
      expect(await db.leg('no-such-id'), isNull);
    });

    test('bookings(legId:) filters by leg', () async {
      await db.upsertAll('booking', [
        _booking(id: 'bk-1', legId: 'leg-1'),
        _booking(id: 'bk-2', legId: 'leg-2'),
      ]);
      final result = await db.bookings(legId: 'leg-1');
      expect(result, hasLength(1));
      expect(result.first.id, 'bk-1');
    });

    test('bookings() without filter returns all', () async {
      await db.upsertAll('booking', [
        _booking(id: 'bk-1', legId: 'leg-1'),
        _booking(id: 'bk-2', legId: 'leg-2'),
      ]);
      expect(await db.bookings(), hasLength(2));
    });

    test('tasks(legId:) filters by leg', () async {
      await db.upsertAll('task', [
        _task(id: 't1', legId: 'leg-1'),
        _task(id: 't2', legId: 'leg-2'),
      ]);
      final result = await db.tasks(legId: 'leg-1');
      expect(result, hasLength(1));
      expect(result.first.id, 't1');
    });

    test('tasks(done: false) returns only undone tasks', () async {
      await db.upsertAll('task', [
        _task(id: 't1', isDone: false),
        _task(id: 't2', isDone: true),
      ]);
      final result = await db.tasks(done: false);
      expect(result, hasLength(1));
      expect(result.first.id, 't1');
    });

    test('tasks(done: true) returns only done tasks', () async {
      await db.upsertAll('task', [
        _task(id: 't1', isDone: false),
        _task(id: 't2', isDone: true),
      ]);
      final result = await db.tasks(done: true);
      expect(result, hasLength(1));
      expect(result.first.id, 't2');
    });

    test('tasks() with legId+done filters both', () async {
      await db.upsertAll('task', [
        _task(id: 't1', legId: 'leg-1', isDone: false),
        _task(id: 't2', legId: 'leg-1', isDone: true),
        _task(id: 't3', legId: 'leg-2', isDone: false),
      ]);
      final result = await db.tasks(legId: 'leg-1', done: false);
      expect(result, hasLength(1));
      expect(result.first.id, 't1');
    });

    test('packing(tripId:) filters by trip', () async {
      await db.upsertAll('packing_item', [
        _packingItem(id: 'pi-1', tripId: 'trip-1'),
        _packingItem(id: 'pi-2', tripId: 'trip-2'),
      ]);
      final result = await db.packing(tripId: 'trip-1');
      expect(result, hasLength(1));
      expect(result.first.id, 'pi-1');
    });

    test('packing() without filter returns all', () async {
      await db.upsertAll('packing_item', [
        _packingItem(id: 'pi-1', tripId: 'trip-1'),
        _packingItem(id: 'pi-2', tripId: 'trip-2'),
      ]);
      expect(await db.packing(), hasLength(2));
    });

    test('journal(legId:) filters by leg', () async {
      await db.upsertAll('journal_entry', [
        _journalEntry(id: 'je-1', legId: 'leg-1'),
        _journalEntry(id: 'je-2', legId: 'leg-2'),
      ]);
      final result = await db.journal(legId: 'leg-1');
      expect(result, hasLength(1));
      expect(result.first.id, 'je-1');
    });

    test('journal() ordered DESC by created_at', () async {
      await db.upsertAll('journal_entry', [
        _journalEntry(id: 'je-early', createdAt: '2026-01-01T08:00:00Z'),
        _journalEntry(id: 'je-late', createdAt: '2026-01-05T20:00:00Z'),
      ]);
      final result = await db.journal();
      expect(result.first.id, 'je-late');
      expect(result.last.id, 'je-early');
    });

    test('latestBriefing() returns most recent by date', () async {
      await db.upsertAll('briefing', [
        _briefingRow(id: 'br-old', date: '2026-01-01'),
        _briefingRow(id: 'br-new', date: '2026-01-10'),
      ]);
      final result = await db.latestBriefing();
      expect(result, isNotNull);
      expect(result!.id, 'br-new');
    });

    test('upsertBriefing then latestBriefing returns the row', () async {
      const briefing = Briefing(
        id: 'br-typed',
        date: '2026-06-14',
        markdown: '## Morning\nAll good.',
        createdAt: '2026-06-14T06:00:00Z',
      );
      await db.upsertBriefing(briefing);
      final result = await db.latestBriefing();
      expect(result, isNotNull);
      expect(result!.id, 'br-typed');
      expect(result.markdown, '## Morning\nAll good.');
    });

    test('upsertBriefing overwrites same date', () async {
      await db.upsertBriefing(const Briefing(
        id: 'br-1',
        date: '2026-06-14',
        markdown: 'v1',
        createdAt: '2026-06-14T06:00:00Z',
      ));
      await db.upsertBriefing(const Briefing(
        id: 'br-1',
        date: '2026-06-14',
        markdown: 'v2',
        createdAt: '2026-06-14T07:00:00Z',
      ));
      final result = await db.latestBriefing();
      expect(result!.markdown, 'v2');
    });
  });

  // ── 3. Soft-delete hiding ────────────────────────────────────────────────

  group('soft-delete hiding', () {
    test('deleted trip is excluded from trips()', () async {
      await db.upsertAll('trip', [
        _trip(id: 'live'),
        _trip(id: 'dead', deletedAt: '2026-01-05T00:00:00Z'),
      ]);
      final result = await db.trips();
      expect(result.map((t) => t.id), contains('live'));
      expect(result.map((t) => t.id), isNot(contains('dead')));
    });

    test('deleted leg excluded from legs()', () async {
      await db.upsertAll('leg', [
        _leg(id: 'live', slug: 'live'),
        _leg(id: 'dead', slug: 'dead', deletedAt: '2026-01-05T00:00:00Z'),
      ]);
      final result = await db.legs();
      expect(result.map((l) => l.id), isNot(contains('dead')));
    });

    test('deleted leg excluded from leg(id)', () async {
      await db.upsertAll('leg', [
        _leg(id: 'dead', slug: 'dead', deletedAt: '2026-01-05T00:00:00Z'),
      ]);
      expect(await db.leg('dead'), isNull);
    });

    test('deleted booking excluded from bookings()', () async {
      await db.upsertAll('booking', [
        _booking(id: 'live'),
        _booking(id: 'dead', deletedAt: '2026-01-05T00:00:00Z'),
      ]);
      final result = await db.bookings();
      expect(result.map((b) => b.id), isNot(contains('dead')));
    });

    test('deleted task excluded from tasks()', () async {
      await db.upsertAll('task', [
        _task(id: 'live'),
        _task(id: 'dead', deletedAt: '2026-01-05T00:00:00Z'),
      ]);
      final result = await db.tasks();
      expect(result.map((t) => t.id), isNot(contains('dead')));
    });

    test('deleted packing item excluded from packing()', () async {
      await db.upsertAll('packing_item', [
        _packingItem(id: 'live'),
        _packingItem(id: 'dead', deletedAt: '2026-01-05T00:00:00Z'),
      ]);
      final result = await db.packing();
      expect(result.map((p) => p.id), isNot(contains('dead')));
    });

    test('deleted journal entry excluded from journal()', () async {
      await db.upsertAll('journal_entry', [
        _journalEntry(id: 'live'),
        _journalEntry(id: 'dead', deletedAt: '2026-01-05T00:00:00Z'),
      ]);
      final result = await db.journal();
      expect(result.map((j) => j.id), isNot(contains('dead')));
    });

    test('deleted briefing excluded from latestBriefing()', () async {
      await db.upsertAll('briefing', [
        _briefingRow(id: 'dead', deletedAt: '2026-01-05T00:00:00Z'),
      ]);
      expect(await db.latestBriefing(), isNull);
    });
  });

  // ── 4. Bool conversion (0/1 ↔ bool round-trip) ───────────────────────────

  group('bool conversion', () {
    test('is_schengen stored as 1 round-trips to true', () async {
      await db.upsertAll('leg', [_leg(isSchengen: true)]);
      final result = await db.leg('leg-1');
      expect(result!.isSchengen, isTrue);
    });

    test('is_schengen stored as false round-trips to false', () async {
      await db.upsertAll('leg', [_leg(isSchengen: false)]);
      final result = await db.leg('leg-1');
      expect(result!.isSchengen, isFalse);
    });

    test('is_done stored as 1 round-trips to true', () async {
      await db.upsertAll('task', [_task(isDone: true)]);
      final result = await db.tasks();
      expect(result.first.isDone, isTrue);
    });

    test('is_done stored as 0 round-trips to false', () async {
      await db.upsertAll('task', [_task(isDone: false)]);
      final result = await db.tasks();
      expect(result.first.isDone, isFalse);
    });

    test('is_packed stored as 1 round-trips to true', () async {
      await db.upsertAll('packing_item', [_packingItem(isPacked: true)]);
      final result = await db.packing();
      expect(result.first.isPacked, isTrue);
    });

    test('is_packed stored as 0 round-trips to false', () async {
      await db.upsertAll('packing_item', [_packingItem(isPacked: false)]);
      final result = await db.packing();
      expect(result.first.isPacked, isFalse);
    });

    test('bool true input to upsertAll is normalised to 1 then read back as true',
        () async {
      // Passing raw `bool` to upsertAll tests `_toSqlite` path.
      await db.upsertAll('task', [
        {
          'id': 'bool-task',
          'title': 'Bool test',
          'priority': 'low',
          'is_done': true, // bool, not int
          'created_at': '2026-01-01T00:00:00Z',
        }
      ]);
      final result = await db.tasks();
      expect(result.first.isDone, isTrue);
    });
  });

  // ── 5. mergeAll last-write-wins ─────────────────────────────────────────

  group('mergeAll', () {
    test('incoming row with NEWER updated_at overwrites local', () async {
      // Seed a local row with old timestamp.
      await db.upsertAll('trip', [
        _trip(id: 'trip-1', name: 'Old Name', updatedAt: '2026-01-01T00:00:00Z'),
      ]);
      // Merge with newer incoming.
      await db.mergeAll({
        'trip': [
          _trip(
              id: 'trip-1',
              name: 'New Name',
              updatedAt: '2026-01-02T00:00:00Z'),
        ],
      });
      final trips = await db.trips();
      expect(trips.first.name, 'New Name');
    });

    test('incoming row with OLDER updated_at is rejected (local kept)', () async {
      await db.upsertAll('trip', [
        _trip(id: 'trip-1', name: 'Local Name', updatedAt: '2026-01-05T00:00:00Z'),
      ]);
      await db.mergeAll({
        'trip': [
          _trip(
              id: 'trip-1',
              name: 'Stale Server',
              updatedAt: '2026-01-01T00:00:00Z'),
        ],
      });
      final trips = await db.trips();
      expect(trips.first.name, 'Local Name');
    });

    test('incoming row with EQUAL updated_at is accepted (server echo lands)',
        () async {
      const ts = '2026-01-03T00:00:00Z';
      await db.upsertAll('trip', [
        _trip(id: 'trip-1', name: 'Local', updatedAt: ts),
      ]);
      await db.mergeAll({
        'trip': [
          _trip(id: 'trip-1', name: 'Echo', updatedAt: ts),
        ],
      });
      final trips = await db.trips();
      expect(trips.first.name, 'Echo');
    });

    test('brand-new id from server is inserted', () async {
      await db.mergeAll({
        'trip': [
          _trip(id: 'brand-new', name: 'Fresh', updatedAt: '2026-01-01T00:00:00Z'),
        ],
      });
      final trips = await db.trips();
      expect(trips.any((t) => t.id == 'brand-new'), isTrue);
    });

    test('local-only row not mentioned by server is left untouched', () async {
      await db.upsertAll('trip', [
        _trip(id: 'local-only', name: 'Mine', updatedAt: '2026-01-01T00:00:00Z'),
      ]);
      // Server sends a different id — local-only must survive.
      await db.mergeAll({
        'trip': [
          _trip(id: 'server-trip', name: 'Theirs', updatedAt: '2026-01-01T00:00:00Z'),
        ],
      });
      final trips = await db.trips();
      expect(trips.any((t) => t.id == 'local-only'), isTrue);
    });

    test('mergeAll inserts row with no updated_at using created_at fallback',
        () async {
      final incoming = Map<String, dynamic>.from(_trip(id: 'no-ts', name: 'No TS'));
      incoming.remove('updated_at');
      await db.mergeAll({
        'trip': [incoming],
      });
      final trips = await db.trips();
      expect(trips.any((t) => t.id == 'no-ts'), isTrue);
    });

    test('mergeAll skips rows with null id', () async {
      await db.mergeAll({
        'trip': [
          {'name': 'No ID', 'start_date': '2026-01-01', 'end_date': '2026-01-31'},
        ],
      });
      expect(await db.trips(), isEmpty);
    });
  });

  // ── 6. Optimistic helpers ───────────────────────────────────────────────

  group('optimistic helpers', () {
    test('localUpsert inserts a new row', () async {
      await db.localUpsert('trip', _trip(id: 'new-trip'));
      expect(await db.trips(), hasLength(1));
    });

    test('localUpsert replaces an existing row', () async {
      await db.upsertAll('trip', [_trip(id: 't1', name: 'Before')]);
      await db.localUpsert('trip', _trip(id: 't1', name: 'After'));
      final trips = await db.trips();
      expect(trips.first.name, 'After');
    });

    test('localTombstone sets deleted_at so read APIs hide the row', () async {
      await db.upsertAll('trip', [_trip(id: 'del-me')]);
      await db.localTombstone('trip', 'del-me', '2026-01-10T00:00:00Z');
      expect(await db.trips(), isEmpty);
    });

    test('localTombstone bumps updated_at so mergeAll keeps the tombstone',
        () async {
      const tombTs = '2026-01-10T00:00:00Z';
      await db.upsertAll('trip', [_trip(id: 'del-me')]);
      await db.localTombstone('trip', 'del-me', tombTs);
      // Server sends older version — tombstone should be kept.
      await db.mergeAll({
        'trip': [
          _trip(id: 'del-me', name: 'Resurrected', updatedAt: '2026-01-01T00:00:00Z'),
        ],
      });
      // Still hidden — tombstone survived.
      expect(await db.trips(), isEmpty);
    });

    test('localPatch merges fields and bumps updated_at', () async {
      const oldTs = '2026-01-01T00:00:00Z';
      const newTs = '2026-01-02T12:00:00Z';
      await db.upsertAll('trip', [
        _trip(id: 't1', name: 'Original', updatedAt: oldTs),
      ]);
      await db.localPatch('trip', 't1', {'name': 'Patched'}, newTs);
      final trips = await db.trips();
      expect(trips.first.name, 'Patched');
    });

    test('localPatch bumped updated_at beats stale server in subsequent mergeAll',
        () async {
      const patchTs = '2026-01-05T00:00:00Z';
      await db.upsertAll('trip', [_trip(id: 't1', name: 'Original')]);
      await db.localPatch('trip', 't1', {'name': 'Patched'}, patchTs);
      // Server sends older timestamp — patch should survive.
      await db.mergeAll({
        'trip': [
          _trip(id: 't1', name: 'Server', updatedAt: '2026-01-01T00:00:00Z'),
        ],
      });
      final trips = await db.trips();
      expect(trips.first.name, 'Patched');
    });

    test('localPatch is a no-op when row does not exist', () async {
      // Should not throw.
      await db.localPatch(
          'trip', 'ghost-id', {'name': 'Ghost'}, '2026-01-01T00:00:00Z');
      expect(await db.trips(), isEmpty);
    });
  });

  // ── 7. Outbox ────────────────────────────────────────────────────────────

  group('outbox', () {
    test('enqueueOp inserts a pending op and returns its id', () async {
      final id = await db.enqueueOp(
        entity: 'booking',
        entityId: 'bk-1',
        op: 'create',
        payloadJson: '{"name":"Test"}',
        queuedAt: '2026-01-01T00:00:00Z',
      );
      expect(id, greaterThan(0));
    });

    test('pendingOpCount reflects queued operations', () async {
      expect(await db.pendingOpCount(), 0);
      await db.enqueueOp(
        entity: 'task',
        entityId: 't1',
        op: 'update',
        queuedAt: '2026-01-01T00:00:00Z',
      );
      await db.enqueueOp(
        entity: 'task',
        entityId: 't2',
        op: 'delete',
        queuedAt: '2026-01-02T00:00:00Z',
      );
      expect(await db.pendingOpCount(), 2);
    });

    test('pendingOps() returns rows ordered by op_id ASC', () async {
      await db.enqueueOp(
        entity: 'booking',
        entityId: 'bk-1',
        op: 'create',
        queuedAt: '2026-01-01T00:00:00Z',
      );
      await db.enqueueOp(
        entity: 'booking',
        entityId: 'bk-2',
        op: 'update',
        queuedAt: '2026-01-02T00:00:00Z',
      );
      final ops = await db.pendingOps();
      expect(ops.length, 2);
      // First inserted has lower op_id, should come first.
      expect(ops.first['entity_id'], 'bk-1');
      expect(ops.last['entity_id'], 'bk-2');
    });

    test('removeOp deletes by op_id', () async {
      final id = await db.enqueueOp(
        entity: 'packing',
        entityId: 'pi-1',
        op: 'delete',
        queuedAt: '2026-01-01T00:00:00Z',
      );
      await db.removeOp(id);
      expect(await db.pendingOpCount(), 0);
    });

    test('removeOp with unknown op_id does not throw', () async {
      await db.removeOp(999999); // no-op
      expect(await db.pendingOpCount(), 0);
    });

    test('pendingOps() includes payload', () async {
      await db.enqueueOp(
        entity: 'task',
        entityId: 't-x',
        op: 'create',
        payloadJson: '{"title":"Buy tickets"}',
        queuedAt: '2026-01-01T00:00:00Z',
      );
      final ops = await db.pendingOps();
      expect(ops.first['payload'], '{"title":"Buy tickets"}');
    });

    test('enqueueOp without payload stores null', () async {
      await db.enqueueOp(
        entity: 'task',
        entityId: 't-y',
        op: 'delete',
        queuedAt: '2026-01-01T00:00:00Z',
      );
      final ops = await db.pendingOps();
      expect(ops.first['payload'], isNull);
    });
  });
}
