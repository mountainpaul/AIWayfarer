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

/// Local SQLite cache. Schema mirrors backend/db/schema.sql.
/// sqflite manages WAL itself, so we drop the explicit PRAGMA.
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

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
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, Env.dbFileName);
    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trips (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        start_date  TEXT NOT NULL,
        end_date    TEXT NOT NULL,
        created_at  TEXT,
        updated_at  TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS legs (
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
        updated_at    TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_legs_trip ON legs(trip_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_legs_dates ON legs(start_date, end_date)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookings (
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
        updated_at      TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bookings_leg ON bookings(leg_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bookings_dates ON bookings(start_date, end_date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bookings_type ON bookings(type)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id          TEXT PRIMARY KEY,
        leg_id      TEXT,
        title       TEXT NOT NULL,
        priority    TEXT NOT NULL,
        due_date    TEXT,
        is_done     INTEGER NOT NULL DEFAULT 0,
        notes       TEXT,
        created_at  TEXT,
        updated_at  TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_leg ON tasks(leg_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tasks_done ON tasks(is_done)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS packing_items (
        id          TEXT PRIMARY KEY,
        trip_id     TEXT NOT NULL,
        category    TEXT NOT NULL,
        name        TEXT NOT NULL,
        is_packed   INTEGER NOT NULL DEFAULT 0,
        sort_order  INTEGER NOT NULL,
        created_at  TEXT,
        updated_at  TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_packing_trip ON packing_items(trip_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_entries (
        id              TEXT PRIMARY KEY,
        leg_id          TEXT,
        content         TEXT NOT NULL,
        entry_type      TEXT NOT NULL DEFAULT 'note',
        location_name   TEXT,
        location_lat    REAL,
        location_lon    REAL,
        created_at      TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_journal_leg ON journal_entries(leg_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_journal_type ON journal_entries(entry_type)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_journal_created ON journal_entries(created_at)');

    // Briefings - local cache only; backend canonical.
    // Schema mirrors backend: {id, date, markdown, created_at}.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS briefings (
        id          TEXT PRIMARY KEY,
        date        TEXT NOT NULL UNIQUE,
        markdown    TEXT NOT NULL,
        created_at  TEXT
      )
    ''');
  }

  // Generic helpers

  // SQLite stores 0/1 for booleans, but the Freezed models declare `bool`.
  // Convert at the sqflite boundary in both directions.
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

  Future<void> clearTable(String table) async {
    await db.delete(table);
  }

  Map<String, dynamic> _toSqlite(Map<String, dynamic> r) {
    final out = Map<String, dynamic>.from(r);
    for (final k in _boolColumns) {
      final v = out[k];
      if (v is bool) out[k] = v ? 1 : 0;
    }
    return out;
  }

  // Read APIs (typed)

  Future<List<Trip>> trips() async {
    final rows = await db.query('trips', orderBy: 'start_date');
    return rows.map((r) => Trip.fromJson(_clean(r))).toList();
  }

  Future<List<Leg>> legs({String? tripId}) async {
    final rows = await db.query(
      'legs',
      where: tripId == null ? null : 'trip_id = ?',
      whereArgs: tripId == null ? null : [tripId],
      orderBy: 'sort_order',
    );
    return rows.map((r) => Leg.fromJson(_clean(r))).toList();
  }

  Future<Leg?> leg(String id) async {
    final rows =
        await db.query('legs', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Leg.fromJson(_clean(rows.first));
  }

  Future<List<Booking>> bookings({String? legId}) async {
    final rows = await db.query(
      'bookings',
      where: legId == null ? null : 'leg_id = ?',
      whereArgs: legId == null ? null : [legId],
      orderBy: 'start_date',
    );
    return rows.map((r) => Booking.fromJson(_clean(r))).toList();
  }

  Future<List<Task>> tasks({String? legId, bool? done}) async {
    final clauses = <String>[];
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
      'tasks',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'is_done, due_date',
    );
    return rows.map((r) => Task.fromJson(_clean(r))).toList();
  }

  Future<List<PackingItem>> packing({String? tripId}) async {
    final rows = await db.query(
      'packing_items',
      where: tripId == null ? null : 'trip_id = ?',
      whereArgs: tripId == null ? null : [tripId],
      orderBy: 'category, sort_order',
    );
    return rows.map((r) => PackingItem.fromJson(_clean(r))).toList();
  }

  Future<List<JournalEntry>> journal({String? legId}) async {
    final rows = await db.query(
      'journal_entries',
      where: legId == null ? null : 'leg_id = ?',
      whereArgs: legId == null ? null : [legId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => JournalEntry.fromJson(_clean(r))).toList();
  }

  Future<Briefing?> latestBriefing() async {
    final rows = await db.query('briefings', orderBy: 'date DESC', limit: 1);
    if (rows.isEmpty) return null;
    return Briefing.fromJson(_clean(rows.first));
  }

  Future<void> upsertBriefing(Briefing b) async {
    await db.insert(
      'briefings',
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
  /// the columns the Freezed models expect as bool.
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
