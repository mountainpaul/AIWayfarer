import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wayfarer/models/trip.dart';
import 'package:wayfarer/models/trip_review.dart';
import 'package:wayfarer/providers/review_provider.dart';
import 'package:wayfarer/providers/trip_provider.dart';
import 'package:wayfarer/services/api_client.dart';
import 'package:wayfarer/services/local_db.dart';

// ── Fake ApiClient ────────────────────────────────────────────────────────────

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');

  /// What getReview should return (null = not found).
  TripReview? reviewToReturn;

  /// Set to true to make getReview throw.
  bool throwOnGet = false;

  /// Reviews to return from listReviews.
  List<TripReview> reviewList = const [];

  /// Set to true to make listReviews throw.
  bool throwOnList = false;

  /// Records the last payload passed to createReview.
  Map<String, dynamic>? lastCreatePayload;

  /// Set to true to make createReview throw.
  bool throwOnCreate = false;

  @override
  Future<TripReview?> getReview(String tripId) async {
    if (throwOnGet) throw Exception('offline');
    return reviewToReturn;
  }

  @override
  Future<List<TripReview>> listReviews() async {
    if (throwOnList) throw Exception('offline');
    return reviewList;
  }

  @override
  Future<TripReview> createReview(Map<String, dynamic> body) async {
    if (throwOnCreate) throw Exception('server rejected');
    lastCreatePayload = body;
    return TripReview(
      id: 'rev-created',
      tripId: body['trip_id'] as String? ?? 'trip-x',
    );
  }
}

// ── Fixture helpers ───────────────────────────────────────────────────────────

Map<String, dynamic> _legRow({
  String id = 'leg-1',
  String tripId = 'trip-1',
  String slug = 'paris',
  String name = 'Paris',
}) =>
    {
      'id': id,
      'trip_id': tripId,
      'slug': slug,
      'name': name,
      'start_date': '2026-01-01',
      'end_date': '2026-01-10',
      'is_schengen': 0,
      'sort_order': 0,
      'currency': 'USD',
      'created_at': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> _bookingRow({
  required String id,
  required String legId,
  required String type,
  required String name,
}) =>
    {
      'id': id,
      'leg_id': legId,
      'type': type,
      'name': name,
      'status': 'confirmed',
      'currency': 'USD',
      'created_at': '2026-01-01T00:00:00Z',
    };

TripReview _review(String id, String tripId) =>
    TripReview(id: id, tripId: tripId);

// ── Container factory ─────────────────────────────────────────────────────────

Future<(ProviderContainer, LocalDb)> _makeContainer({
  required _FakeApi api,
  List<Trip>? tripsOverride,
}) async {
  final db = LocalDb.newForTest();
  await db.init(pathOverride: inMemoryDatabasePath);

  final overrides = <Override>[
    apiClientProvider.overrideWithValue(api),
    localDbProvider.overrideWithValue(db),
    // Always override initialSyncProvider so tripsProvider doesn't hit the network.
    initialSyncProvider.overrideWith((ref) async => true),
    if (tripsOverride != null)
      tripsProvider.overrideWith((ref) async => tripsOverride),
  ];

  final container = ProviderContainer(overrides: overrides);
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

  // ── reviewForTripProvider ─────────────────────────────────────────────────

  group('reviewForTripProvider', () {
    test('returns the review when getReview succeeds', () async {
      final api = _FakeApi()
        ..reviewToReturn = _review('rev-1', 'trip-1');
      final (c, _) = await _makeContainer(api: api);

      final result = await c.read(reviewForTripProvider('trip-1').future);
      expect(result, isNotNull);
      expect(result!.id, 'rev-1');
      expect(result.tripId, 'trip-1');
    });

    test('returns null when getReview throws (offline)', () async {
      final api = _FakeApi()..throwOnGet = true;
      final (c, _) = await _makeContainer(api: api);

      final result = await c.read(reviewForTripProvider('trip-1').future);
      expect(result, isNull);
    });

    test('returns null when getReview returns null (no review exists)', () async {
      final api = _FakeApi()..reviewToReturn = null;
      final (c, _) = await _makeContainer(api: api);

      final result = await c.read(reviewForTripProvider('trip-1').future);
      expect(result, isNull);
    });
  });

  // ── tripsNeedingReviewProvider ────────────────────────────────────────────

  group('tripsNeedingReviewProvider', () {
    test('returns completed trips that are not yet reviewed', () async {
      const completedTrip = Trip(
        id: 'trip-completed',
        name: 'Japan 2025',
        startDate: '2025-09-01',
        endDate: '2025-09-30',
        status: 'completed',
      );
      final api = _FakeApi()
        ..reviewList = []; // no reviews yet

      final (c, _) = await _makeContainer(
        api: api,
        tripsOverride: [
          completedTrip,
          const Trip(
            id: 'trip-planning',
            name: 'Greece 2027',
            startDate: '2027-06-01',
            endDate: '2027-06-30',
            status: 'planning',
          ),
        ],
      );

      final result = await c.read(tripsNeedingReviewProvider.future);
      expect(result, hasLength(1));
      expect(result.first.id, 'trip-completed');
    });

    test('excludes completed trips that are already reviewed', () async {
      final api = _FakeApi()
        ..reviewList = [_review('rev-1', 'trip-done')];

      final (c, _) = await _makeContainer(
        api: api,
        tripsOverride: [
          const Trip(
            id: 'trip-done',
            name: 'Done Trip',
            startDate: '2025-01-01',
            endDate: '2025-01-31',
            status: 'completed',
          ),
        ],
      );

      final result = await c.read(tripsNeedingReviewProvider.future);
      expect(result, isEmpty);
    });

    test('returns [] when there are no completed trips', () async {
      final api = _FakeApi()..reviewList = [];

      final (c, _) = await _makeContainer(
        api: api,
        tripsOverride: [
          const Trip(
            id: 'trip-active',
            name: 'Active Trip',
            startDate: '2026-06-01',
            endDate: '2026-07-01',
            status: 'active',
          ),
        ],
      );

      final result = await c.read(tripsNeedingReviewProvider.future);
      expect(result, isEmpty);
    });

    test('returns [] when listReviews throws (offline)', () async {
      final api = _FakeApi()..throwOnList = true;

      final (c, _) = await _makeContainer(
        api: api,
        tripsOverride: [
          const Trip(
            id: 'trip-completed',
            name: 'Completed Trip',
            startDate: '2025-01-01',
            endDate: '2025-01-31',
            status: 'completed',
          ),
        ],
      );

      // Offline → can't determine reviewed set → return [] rather than nagging.
      final result = await c.read(tripsNeedingReviewProvider.future);
      expect(result, isEmpty);
    });

    test('returns [] when trips list is empty', () async {
      final api = _FakeApi();
      final (c, _) = await _makeContainer(
        api: api,
        tripsOverride: const [],
      );

      final result = await c.read(tripsNeedingReviewProvider.future);
      expect(result, isEmpty);
    });
  });

  // ── reviewableItemsProvider ───────────────────────────────────────────────

  group('reviewableItemsProvider', () {
    test('maps hotel and rifugio bookings to stay subject type', () async {
      final api = _FakeApi();
      final (c, db) = await _makeContainer(api: api);

      await db.upsertAll('leg', [_legRow(id: 'leg-1', tripId: 'trip-1')]);
      await db.upsertAll('booking', [
        _bookingRow(id: 'bk-hotel', legId: 'leg-1', type: 'hotel', name: 'Hotel Paris'),
        _bookingRow(id: 'bk-rif', legId: 'leg-1', type: 'rifugio', name: 'Rifugio Alpi'),
      ]);

      final items = await c.read(reviewableItemsProvider('trip-1').future);
      expect(items, hasLength(2));
      expect(items.every((i) => i.subjectType == 'stay'), isTrue);
    });

    test('maps flight, ferry, car, train bookings to transport', () async {
      final api = _FakeApi();
      final (c, db) = await _makeContainer(api: api);

      await db.upsertAll('leg', [_legRow(id: 'leg-1', tripId: 'trip-1')]);
      await db.upsertAll('booking', [
        _bookingRow(id: 'bk-flight', legId: 'leg-1', type: 'flight', name: 'Air France'),
        _bookingRow(id: 'bk-ferry', legId: 'leg-1', type: 'ferry', name: 'Stena'),
        _bookingRow(id: 'bk-car', legId: 'leg-1', type: 'car', name: 'Hertz'),
        _bookingRow(id: 'bk-train', legId: 'leg-1', type: 'train', name: 'TGV'),
      ]);

      final items = await c.read(reviewableItemsProvider('trip-1').future);
      expect(items, hasLength(4));
      expect(items.every((i) => i.subjectType == 'transport'), isTrue);
    });

    test('maps activity booking to activity', () async {
      final api = _FakeApi();
      final (c, db) = await _makeContainer(api: api);

      await db.upsertAll('leg', [_legRow(id: 'leg-1', tripId: 'trip-1')]);
      await db.upsertAll('booking', [
        _bookingRow(id: 'bk-act', legId: 'leg-1', type: 'activity', name: 'Eiffel Tour'),
      ]);

      final items = await c.read(reviewableItemsProvider('trip-1').future);
      expect(items.single.subjectType, 'activity');
    });

    test('maps unknown booking types to other', () async {
      final api = _FakeApi();
      final (c, db) = await _makeContainer(api: api);

      await db.upsertAll('leg', [_legRow(id: 'leg-1', tripId: 'trip-1')]);
      await db.upsertAll('booking', [
        _bookingRow(id: 'bk-misc', legId: 'leg-1', type: 'insurance', name: 'Policy A'),
      ]);

      final items = await c.read(reviewableItemsProvider('trip-1').future);
      expect(items.single.subjectType, 'other');
    });

    test('carries bookingId and legId correctly', () async {
      final api = _FakeApi();
      final (c, db) = await _makeContainer(api: api);

      await db.upsertAll('leg', [_legRow(id: 'leg-42', tripId: 'trip-1')]);
      await db.upsertAll('booking', [
        _bookingRow(id: 'bk-99', legId: 'leg-42', type: 'hotel', name: 'Grand Hotel'),
      ]);

      final items = await c.read(reviewableItemsProvider('trip-1').future);
      expect(items.single.bookingId, 'bk-99');
      expect(items.single.legId, 'leg-42');
    });

    test('returns empty list when trip has no legs', () async {
      final api = _FakeApi();
      final (c, _) = await _makeContainer(api: api);
      // No legs seeded for trip-1.

      final items = await c.read(reviewableItemsProvider('trip-1').future);
      expect(items, isEmpty);
    });

    test('aggregates bookings across multiple legs', () async {
      final api = _FakeApi();
      final (c, db) = await _makeContainer(api: api);

      await db.upsertAll('leg', [
        _legRow(id: 'leg-a', tripId: 'trip-1', slug: 'paris', name: 'Paris'),
        _legRow(id: 'leg-b', tripId: 'trip-1', slug: 'rome', name: 'Rome'),
      ]);
      await db.upsertAll('booking', [
        _bookingRow(id: 'bk-1', legId: 'leg-a', type: 'hotel', name: 'Hotel Paris'),
        _bookingRow(id: 'bk-2', legId: 'leg-b', type: 'activity', name: 'Colosseum'),
      ]);

      final items = await c.read(reviewableItemsProvider('trip-1').future);
      expect(items, hasLength(2));
      expect(items.map((i) => i.bookingId), containsAll(['bk-1', 'bk-2']));
    });
  });

  // ── ReviewMutations.submit ────────────────────────────────────────────────

  group('ReviewMutations.submit', () {
    test('calls createReview with the payload and bumps reviewRefreshProvider',
        () async {
      final api = _FakeApi();
      final (c, _) = await _makeContainer(api: api);

      final before = c.read(reviewRefreshProvider);
      const payload = <String, dynamic>{
        'trip_id': 'trip-1',
        'overall_rating': 5,
        'items': <dynamic>[],
      };

      final ok = await c.read(reviewMutationsProvider).submit(payload);

      expect(ok, isTrue);
      expect(api.lastCreatePayload, isNotNull);
      expect(api.lastCreatePayload!['trip_id'], 'trip-1');
      expect(api.lastCreatePayload!['overall_rating'], 5);
      expect(c.read(reviewRefreshProvider), before + 1);
    });

    test('returns false and does not bump when createReview throws', () async {
      final api = _FakeApi()..throwOnCreate = true;
      final (c, _) = await _makeContainer(api: api);

      final before = c.read(reviewRefreshProvider);

      final ok = await c.read(reviewMutationsProvider).submit({
        'trip_id': 'trip-1',
        'items': <dynamic>[],
      });

      expect(ok, isFalse);
      expect(c.read(reviewRefreshProvider), before); // unchanged
    });
  });
}
