import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../config/env.dart';
import '../models/booking.dart';
import '../models/briefing.dart';
import '../models/journal_entry.dart';
import '../models/leg.dart';
import '../models/packing_item.dart';
import '../models/task.dart';
import '../models/trip.dart';

/// Local SQLite cache. Schema mirrors backend/db/schema.sql (singular table
/// names per BEST_PRACTICES.md §3.1).
///
/// Sync model (see docs/sync-redesign.md): the backend is NOT treated as
/// authoritative. Incoming rows are MERGED by `updated_at` (last-write-wins),
/// soft-deletes are tombstones (`deleted_at`), and local-only / newer-local
/// rows are never destroyed. Local edits made while offline are queued in
/// `pending_ops` and pushed on reconnect.
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  /// Bump when the local schema changes; see [_onUpgrade].
  static const _schemaVersion = 3;

  Database? _db;
  Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('LocalDb not initialized - call init() in main()');
    }
    return d;
  }

  Future<void> init() async {
    if (_db != null) return;
    late final String path;
    if (kIsWeb) {
      path = Env.dbFileName;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, Env.dbFileName);
    }
    _db = await openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2: soft-delete tombstones + the timestamps and outbox the merge
    // sync needs. Tables are still PLURAL at this point. Additive only.
    if (oldVersion < 2) {
      for (final t in [
        'trips',
        'legs',
        'bookings',
        'tasks',
        'packing_items',
        'journal_entries',
        'briefings',
      ]) {
        await _addColumnIfMissing(db, t, 'deleted_at', 'TEXT');
      }
      await _addColumnIfMissing(db, 'journal_entries', 'updated_at', 'TEXT');
      await _addColumnIfMissing(db, 'briefings', 'updated_at', 'TEXT');
      await db.execute(
          'UPDATE journal_entries SET updated_at = created_at WHERE updated_at IS NULL');
      await db.execute(
          'UPDATE briefings SET updated_at = created_at WHERE updated_at IS NULL');
      await _createOutbox(db);
    }
    // v2 -> v3: rename tables to singular (BEST_PRACTICES.md §3.1). RENAME
    // preserves all data and moves indexes with the table.
    if (oldVersion < 3) {
      const renames = {
        'trips': 'trip',
        'legs': 'leg',
        'bookings': 'booking',
        'tasks': 'task',
        'packing_items': 'packing_item',
        'journal_entries': 'journal_entry',
        'briefings': 'briefing',
      };
      for (final e in renames.entries) {
        await _renameTableIfPresent(db, e.key, e.value);
      }
    }
  }

  Future<void> _addColumnIfMissing(
      Database db, String table, String column, String type) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final exists = cols.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> _renameTableIfPresent(
      Database db, String from, String to) async {
    final present = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        [from]);
    if (present.isNotEmpty) {
      await db.execute('ALTER TABLE $from RENAME TO $to');
    }
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trip (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        start_date  TEXT NOT NULL,
        end_date    TEXT NOT NULL,
        created_at  TEXT,
        updated_at  TEXT,
        deleted_at  TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS leg (
        id            TEXT PRIMARY KEY,
        trip_id       TEXT NOT NULL,
        slug          TEXT NOT NULL UNIQUE,
        name          TEXT NOT NULL,
        emoji         TEXT,
        color         TEXT,
        start_date    TEXT NOT NULL,
        end_date      TEXT NOT NULL,
        is_schengen   INTEGER NOT NULL DEFAULT 0,
        budget_cents  INTEGER,
        currency      TEXT NOT NULL DEFAULT 'USD',
        places        TEXT,
        notes         TEXT,
        sort_order    INTEGER NOT NULL,
        created_at    TEXT,
        updated_at    TEXT,
        deleted_at    TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_leg_trip ON leg(trip_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_leg_dates ON leg(start_date, end_date)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS booking (
        id              TEXT PRIMARY KEY,
        leg_id          TEXT NOT NULL,
        type            TEXT NOT NULL,
        name            TEXT NOT NULL,
        status          TEXT NOT NULL,
        start_date      TEXT,
        end_date        TEXT,
        confirmation    TEXT,
        cost_cents      INTEGER,
        currency        TEXT NOT NULL DEFAULT 'USD',
        location_name   TEXT,
        location_lat    REAL,
        location_lon    REAL,
        notes           TEXT,
        created_at      TEXT,
        updated_at      TEXT,
        deleted_at      TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_booking_leg ON booking(leg_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_booking_dates ON booking(start_date, end_date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_booking_type ON booking(type)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_booking_status ON booking(status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS task (
        id          TEXT PRIMARY KEY,
        leg_id      TEXT,
        title       TEXT NOT NULL,
        priority    TEXT NOT NULL,
        due_date    TEXT,
        is_done     INTEGER NOT NULL DEFAULT 0,
        notes       TEXT,
        created_at  TEXT,
        updated_at  TEXT,
        deleted_at  TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_task_leg ON task(leg_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_task_priority ON task(priority)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_task_done ON task(is_done)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS packing_item (
        id          TEXT PRIMARY KEY,
        trip_id     TEXT NOT NULL,
        category    TEXT NOT NULL,
        name        TEXT NOT NULL,
        is_packed   INTEGER NOT NULL DEFAULT 0,
        sort_order  INTEGER NOT NULL,
        created_at  TEXT,
        updated_at  TEXT,
        deleted_at  TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_packing_item_trip ON packing_item(trip_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_entry (
        id              TEXT PRIMARY KEY,
        leg_id          TEXT,
        content         TEXT NOT NULL,
        entry_type      TEXT NOT NULL DEFAULT 'note',
        location_name   TEXT,
        location_lat    REAL,
        location_lon    REAL,
        created_at      TEXT,
        updated_at      TEXT,
        deleted_at      TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_journal_entry_leg ON journal_entry(leg_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_journal_entry_type ON journal_entry(entry_type)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_journal_entry_created ON journal_entry(created_at)');

    // Briefing - local cache only; backend canonical.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS briefing (
        id          TEXT PRIMARY KEY,
        date        TEXT NOT NULL UNIQUE,
        markdown    TEXT NOT NULL,
        created_at  TEXT,
        updated_at  TEXT,
        deleted_at  TEXT
      )
    ''');

    await _createOutbox(db);
  }

  /// Outbox of local mutations that still need to reach the backend. A write
  /// made while offline is applied to the local cache immediately AND recorded
  /// here, then flushed by SyncService on the next successful connection. This
  /// is what keeps an edit-while-offline from vanishing.
  Future<void> _createOutbox(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_ops (
        op_id       INTEGER PRIMARY KEY AUTOINCREMENT,
        entity      TEXT NOT NULL,   -- 'booking' | 'task' | 'packing'
        entity_id   TEXT NOT NULL,
        op          TEXT NOT NULL,   -- 'create' | 'update' | 'delete'
        payload     TEXT,            -- JSON body for create/update
        queued_at   TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pending_ops_queued ON pending_ops(queued_at)');
  }

  // ── Generic write helpers ──────────────────────────────────

  // SQLite stores 0/1 for booleans, but the Freezed models declare `bool`.
  static const _boolColumns = {'is_done', 'is_packed', 'is_schengen'};

  Future<void> upsertAll(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final batch = db.batch();
    for (final r in rows) {
      batch.insert(table, _toSqlite(r),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Merge a server snapshot into local tables WITHOUT destroying local data.
  ///
  /// Per row: upsert only when the incoming `updated_at` is >= the local one
  /// (last-write-wins; ISO-8601 strings compare correctly). Tombstoned rows
  /// (deleted_at set) are upserted like any other — the read APIs filter them
  /// out. Crucially, local rows the server did NOT mention are left untouched,
  /// so an offline-created or newer-local record is never silently deleted.
  Future<void> mergeAll(Map<String, List<Map<String, dynamic>>> tables) async {
    await db.transaction((txn) async {
      for (final entry in tables.entries) {
        final table = entry.key;
        for (final incoming in entry.value) {
          final id = incoming['id'];
          if (id == null) continue;
          final incomingTs =
              (incoming['updated_at'] ?? incoming['created_at'] ?? '')
                  .toString();
          final existing = await txn.query(table,
              columns: ['updated_at'],
              where: 'id = ?',
              whereArgs: [id],
              limit: 1);
          if (existing.isEmpty) {
            await txn.insert(table, _toSqlite(incoming),
                conflictAlgorithm: ConflictAlgorithm.replace);
          } else {
            final localTs = (existing.first['updated_at'] ?? '').toString();
            // >= so a server echo of our own write (equal timestamp) still lands.
            if (incomingTs.compareTo(localTs) >= 0) {
              await txn.insert(table, _toSqlite(incoming),
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
            // else: local copy is newer — keep it (last-write-wins).
          }
        }
      }
    });
  }

  /// Optimistically write a single row locally (used so an edit shows up
  /// immediately even while offline).
  Future<void> localUpsert(String table, Map<String, dynamic> row) async {
    await db.insert(table, _toSqlite(row),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Optimistically tombstone a single row locally.
  Future<void> localTombstone(
      String table, String id, String deletedAt) async {
    await db.update(
      table,
      {'deleted_at': deletedAt, 'updated_at': deletedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Optimistically apply a partial update to a local row and bump its
  /// updated_at, so an edit shows immediately and survives the next merge
  /// (last-write-wins) even before it reaches the backend.
  Future<void> localPatch(
      String table, String id, Map<String, dynamic> patch, String now) async {
    final rows =
        await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final merged = Map<String, dynamic>.from(rows.first)
      ..addAll(patch)
      ..['updated_at'] = now;
    await db.insert(table, _toSqlite(merged),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, dynamic> _toSqlite(Map<String, dynamic> r) {
    final out = Map<String, dynamic>.from(r);
    for (final k in _boolColumns) {
      final v = out[k];
      if (v is bool) out[k] = v ? 1 : 0;
    }
    return out;
  }

  // ── Outbox helpers ─────────────────────────────────────────

  Future<int> enqueueOp({
    required String entity,
    required String entityId,
    required String op,
    String? payloadJson,
    required String queuedAt,
  }) {
    return db.insert('pending_ops', {
      'entity': entity,
      'entity_id': entityId,
      'op': op,
      'payload': payloadJson,
      'queued_at': queuedAt,
    });
  }

  Future<List<Map<String, Object?>>> pendingOps() {
    return db.query('pending_ops', orderBy: 'op_id ASC');
  }

  Future<void> removeOp(int opId) async {
    await db.delete('pending_ops', where: 'op_id = ?', whereArgs: [opId]);
  }

  Future<int> pendingOpCount() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM pending_ops');
    return (r.first['c'] as int?) ?? 0;
  }

  // ── Read APIs (typed) — all hide soft-deleted rows ─────────

  /// Compose `deleted_at IS NULL` with an optional caller clause.
  String _activeWhere([String? extra]) =>
      extra == null ? 'deleted_at IS NULL' : 'deleted_at IS NULL AND $extra';

  Future<List<Trip>> trips() async {
    final rows = await db.query('trip',
        where: 'deleted_at IS NULL', orderBy: 'start_date');
    return rows.map((r) => Trip.fromJson(_clean(r))).toList();
  }

  Future<List<Leg>> legs({String? tripId}) async {
    final rows = await db.query(
      'leg',
      where: tripId == null ? _activeWhere() : _activeWhere('trip_id = ?'),
      whereArgs: tripId == null ? null : [tripId],
      orderBy: 'sort_order',
    );
    return rows.map((r) => Leg.fromJson(_clean(r))).toList();
  }

  Future<Leg?> leg(String id) async {
    final rows = await db.query('leg',
        where: _activeWhere('id = ?'), whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Leg.fromJson(_clean(rows.first));
  }

  Future<List<Booking>> bookings({String? legId}) async {
    final rows = await db.query(
      'booking',
      where: legId == null ? _activeWhere() : _activeWhere('leg_id = ?'),
      whereArgs: legId == null ? null : [legId],
      orderBy: 'start_date',
    );
    return rows.map((r) => Booking.fromJson(_clean(r))).toList();
  }

  Future<List<Task>> tasks({String? legId, bool? done}) async {
    final clauses = <String>['deleted_at IS NULL'];
    final args = <Object?>[];
    if (legId != null) {
      clauses.add('leg_id = ?');
      args.add(legId);
    }
    if (done != null) {
      clauses.add('is_done = ?');
      args.add(done ? 1 : 0);
    }
    final rows = await db.query(
      'task',
      where: clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'is_done, due_date',
    );
    return rows.map((r) => Task.fromJson(_clean(r))).toList();
  }

  Future<List<PackingItem>> packing({String? tripId}) async {
    final rows = await db.query(
      'packing_item',
      where: tripId == null ? _activeWhere() : _activeWhere('trip_id = ?'),
      whereArgs: tripId == null ? null : [tripId],
      orderBy: 'category, sort_order',
    );
    return rows.map((r) => PackingItem.fromJson(_clean(r))).toList();
  }

  Future<List<JournalEntry>> journal({String? legId}) async {
    final rows = await db.query(
      'journal_entry',
      where: legId == null ? _activeWhere() : _activeWhere('leg_id = ?'),
      whereArgs: legId == null ? null : [legId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => JournalEntry.fromJson(_clean(r))).toList();
  }

  Future<Briefing?> latestBriefing() async {
    final rows = await db.query('briefing',
        where: 'deleted_at IS NULL', orderBy: 'date DESC', limit: 1);
    if (rows.isEmpty) return null;
    return Briefing.fromJson(_clean(rows.first));
  }

  Future<void> upsertBriefing(Briefing b) async {
    await db.insert(
      'briefing',
      {
        'id': b.id,
        'date': b.date,
        'markdown': b.markdown,
        'created_at': b.createdAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Cast a sqflite row to Map<String, dynamic> and normalize 0/1 → bool for
  /// the columns the Freezed models expect as bool. Extra columns the models
  /// don't declare (e.g. deleted_at) are ignored by their fromJson.
  Map<String, dynamic> _clean(Map<String, Object?> row) {
    final m = Map<String, dynamic>.from(row);
    for (final k in _boolColumns) {
      final v = m[k];
      if (v is int) m[k] = v == 1;
    }
    return m;
  }
}

final localDbProvider = Provider<LocalDb>((_) => LocalDb.instance);
