// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wayfarer/models/grounding.dart';
import 'package:wayfarer/services/grounding_service.dart';
import 'package:wayfarer/services/local_db.dart';
import 'package:wayfarer/services/location_service.dart';

// ── Fake LocationService ────────────────────────────────────────────────────

class _FakeLocation extends LocationService {
  Position? position;

  @override
  Future<Position?> currentPosition() async => position;
}

/// Build a fake [Position] without hitting the platform channel.
Position _fakePos({
  required double lat,
  required double lon,
  required double accuracy,
}) =>
    Position(
      latitude: lat,
      longitude: lon,
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      timestamp: DateTime(2026, 6, 14),
    );

// ── Helpers ─────────────────────────────────────────────────────────────────

Future<LocalDb> _initDb() async {
  final db = LocalDb.newForTest();
  await db.init(pathOverride: inMemoryDatabasePath);
  return db;
}

String _dateOffset(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('GroundingService.compose()', () {
    test('includes GPS coordinates when location is available', () async {
      final loc = _FakeLocation()
        ..position = _fakePos(lat: 37.7749, lon: -122.4194, accuracy: 10);
      final db = await _initDb();
      addTearDown(db.close);

      final svc = GroundingService(db: db, location: loc);
      final g = await svc.compose();

      expect(g.gpsLat, closeTo(37.7749, 0.001));
      expect(g.gpsLon, closeTo(-122.4194, 0.001));
      expect(g.gpsAccuracyM, closeTo(10, 0.1));
    });

    test('GPS fields are null when location returns null', () async {
      final loc = _FakeLocation(); // position stays null
      final db = await _initDb();
      addTearDown(db.close);

      final svc = GroundingService(db: db, location: loc);
      final g = await svc.compose();

      expect(g.gpsLat, isNull);
      expect(g.gpsLon, isNull);
      expect(g.gpsAccuracyM, isNull);
    });

    test('localTimeIso is a valid ISO-8601 string', () async {
      final loc = _FakeLocation();
      final db = await _initDb();
      addTearDown(db.close);

      final svc = GroundingService(db: db, location: loc);
      final before = DateTime.now().toIso8601String();
      final g = await svc.compose();
      final after = DateTime.now().toIso8601String();

      expect(g.localTimeIso.compareTo(before), greaterThanOrEqualTo(0));
      expect(g.localTimeIso.compareTo(after), lessThanOrEqualTo(0));
    });

    test('currentLegId is null when no legs in DB', () async {
      final loc = _FakeLocation();
      final db = await _initDb();
      addTearDown(db.close);

      final svc = GroundingService(db: db, location: loc);
      final g = await svc.compose();

      expect(g.currentLegId, isNull);
      expect(g.currentLegSlug, isNull);
      expect(g.currentTripId, isNull);
    });

    test('picks the active leg when today falls within its date range',
        () async {
      final loc = _FakeLocation();
      final db = await _initDb();
      addTearDown(db.close);

      final yesterday = _dateOffset(-1);
      final tomorrow = _dateOffset(1);

      // Upsert a leg that spans yesterday → tomorrow (covers today).
      await db.upsertAll('leg', [
        {
          'id': 'leg-1',
          'trip_id': 'trip-1',
          'slug': 'paris-leg',
          'name': 'Paris',
          'start_date': yesterday,
          'end_date': tomorrow,
          'is_schengen': 1,
          'sort_order': 0,
          'currency': 'EUR',
        }
      ]);

      final svc = GroundingService(db: db, location: loc);
      final g = await svc.compose();

      expect(g.currentLegId, 'leg-1');
      expect(g.currentLegSlug, 'paris-leg');
      expect(g.currentTripId, 'trip-1');
    });

    test('currentLegId is null when the only leg is in the future', () async {
      final loc = _FakeLocation();
      final db = await _initDb();
      addTearDown(db.close);

      final nextWeek = _dateOffset(7);
      final nextMonth = _dateOffset(30);

      await db.upsertAll('leg', [
        {
          'id': 'leg-future',
          'trip_id': 'trip-1',
          'slug': 'future-leg',
          'name': 'Tokyo',
          'start_date': nextWeek,
          'end_date': nextMonth,
          'is_schengen': 0,
          'sort_order': 0,
          'currency': 'JPY',
        }
      ]);

      final svc = GroundingService(db: db, location: loc);
      final g = await svc.compose();

      expect(g.currentLegId, isNull);
    });

    test('nextBookingId points to the soonest future booking in the active leg',
        () async {
      final loc = _FakeLocation();
      final db = await _initDb();
      addTearDown(db.close);

      final yesterday = _dateOffset(-1);
      final tomorrow = _dateOffset(1);
      final soon = DateTime.now().add(const Duration(hours: 2)).toIso8601String();
      final later = DateTime.now().add(const Duration(hours: 5)).toIso8601String();

      await db.upsertAll('leg', [
        {
          'id': 'leg-1',
          'trip_id': 'trip-1',
          'slug': 'active',
          'name': 'Active',
          'start_date': yesterday,
          'end_date': tomorrow,
          'is_schengen': 0,
          'sort_order': 0,
          'currency': 'USD',
        }
      ]);

      await db.upsertAll('booking', [
        {
          'id': 'b-soon',
          'leg_id': 'leg-1',
          'type': 'hotel',
          'name': 'Hotel A',
          'status': 'confirmed',
          'start_date': soon,
          'currency': 'USD',
        },
        {
          'id': 'b-later',
          'leg_id': 'leg-1',
          'type': 'flight',
          'name': 'Flight B',
          'status': 'confirmed',
          'start_date': later,
          'currency': 'USD',
        },
      ]);

      final svc = GroundingService(db: db, location: loc);
      final g = await svc.compose();

      expect(g.currentLegId, 'leg-1');
      expect(g.nextBookingId, 'b-soon');
    });

    test('nextBookingId is null when active leg has no future bookings',
        () async {
      final loc = _FakeLocation();
      final db = await _initDb();
      addTearDown(db.close);

      final yesterday = _dateOffset(-1);
      final tomorrow = _dateOffset(1);
      final twoHoursAgo =
          DateTime.now().subtract(const Duration(hours: 2)).toIso8601String();

      await db.upsertAll('leg', [
        {
          'id': 'leg-1',
          'trip_id': 'trip-1',
          'slug': 'active',
          'name': 'Active',
          'start_date': yesterday,
          'end_date': tomorrow,
          'is_schengen': 0,
          'sort_order': 0,
          'currency': 'USD',
        }
      ]);

      await db.upsertAll('booking', [
        {
          'id': 'b-past',
          'leg_id': 'leg-1',
          'type': 'hotel',
          'name': 'Past Hotel',
          'status': 'confirmed',
          'start_date': twoHoursAgo,
          'currency': 'USD',
        },
      ]);

      final svc = GroundingService(db: db, location: loc);
      final g = await svc.compose();

      expect(g.nextBookingId, isNull);
    });

    test('returns a typed Grounding instance', () async {
      final loc = _FakeLocation();
      final db = await _initDb();
      addTearDown(db.close);

      final svc = GroundingService(db: db, location: loc);
      final g = await svc.compose();

      expect(g, isA<Grounding>());
    });
  });
}
