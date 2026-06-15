import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wayfarer/models/grounding.dart';
import 'package:wayfarer/providers/grounding_provider.dart';
import 'package:wayfarer/services/grounding_service.dart';
import 'package:wayfarer/services/location_service.dart';
import 'package:wayfarer/services/local_db.dart';

// ── Fake GroundingService ───────────────────────────────────────────────────

class _FakeLocation extends LocationService {
  @override
  Future<Position?> currentPosition() async => null;
}

class _FakeGroundingService extends GroundingService {
  _FakeGroundingService(this._result, LocalDb db)
      : super(db: db, location: _FakeLocation());

  final Grounding _result;

  @override
  Future<Grounding> compose() async => _result;
}

late LocalDb _db;

Future<_FakeGroundingService> _makeService(Grounding stub) async {
  return _FakeGroundingService(stub, _db);
}

// ── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    _db = LocalDb.newForTest();
    await _db.init(pathOverride: inMemoryDatabasePath);
  });

  tearDown(() async {
    await _db.close();
  });

  group('groundingProvider', () {
    test('resolves to the Grounding returned by GroundingService.compose()',
        () async {
      const stub = Grounding(
        localTimeIso: '2026-06-14T09:00:00.000',
        gpsLat: 48.8566,
        gpsLon: 2.3522,
        currentLegId: 'leg-paris',
        currentLegSlug: 'paris',
        currentTripId: 'trip-eu',
        nextBookingId: 'booking-42',
      );

      final svc = await _makeService(stub);
      final c = ProviderContainer(
        overrides: [
          groundingServiceProvider.overrideWithValue(svc),
        ],
      );
      addTearDown(c.dispose);

      final g = await c.read(groundingProvider.future);

      expect(g.localTimeIso, '2026-06-14T09:00:00.000');
      expect(g.gpsLat, closeTo(48.8566, 0.0001));
      expect(g.gpsLon, closeTo(2.3522, 0.0001));
      expect(g.currentLegId, 'leg-paris');
      expect(g.nextBookingId, 'booking-42');
    });

    test('resolves with null GPS fields when service returns no location',
        () async {
      const stub = Grounding(localTimeIso: '2026-06-14T09:00:00.000');

      final svc = await _makeService(stub);
      final c = ProviderContainer(
        overrides: [
          groundingServiceProvider.overrideWithValue(svc),
        ],
      );
      addTearDown(c.dispose);

      final g = await c.read(groundingProvider.future);

      expect(g.gpsLat, isNull);
      expect(g.gpsLon, isNull);
      expect(g.currentLegId, isNull);
    });
  });
}
