import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/grounding.dart';

void main() {
  group('Grounding', () {
    group('fromJson', () {
      test('maps all snake_case fields correctly', () {
        final g = Grounding.fromJson({
          'gps_lat': 35.6762,
          'gps_lon': 139.6503,
          'gps_accuracy_m': 12.5,
          'local_time_iso': '2026-09-05T14:30:00+09:00',
          'timezone': 'Asia/Tokyo',
          'current_leg_id': 'leg-1',
          'current_leg_slug': 'tokyo',
          'current_trip_id': 'trip-1',
          'next_booking_id': 'bk-42',
        });

        expect(g.gpsLat, closeTo(35.6762, 0.0001));
        expect(g.gpsLon, closeTo(139.6503, 0.0001));
        expect(g.gpsAccuracyM, closeTo(12.5, 0.01));
        expect(g.localTimeIso, '2026-09-05T14:30:00+09:00');
        expect(g.timezone, 'Asia/Tokyo');
        expect(g.currentLegId, 'leg-1');
        expect(g.currentLegSlug, 'tokyo');
        expect(g.currentTripId, 'trip-1');
        expect(g.nextBookingId, 'bk-42');
      });

      test('optional GPS and context fields default to null', () {
        final g = Grounding.fromJson({
          'local_time_iso': '2026-09-05T14:30:00Z',
        });

        expect(g.localTimeIso, '2026-09-05T14:30:00Z');
        expect(g.gpsLat, isNull);
        expect(g.gpsLon, isNull);
        expect(g.gpsAccuracyM, isNull);
        expect(g.timezone, isNull);
        expect(g.currentLegId, isNull);
        expect(g.currentLegSlug, isNull);
        expect(g.currentTripId, isNull);
        expect(g.nextBookingId, isNull);
      });

      test('accepts zero-value GPS coordinates (not treated as null)', () {
        final g = Grounding.fromJson({
          'gps_lat': 0.0,
          'gps_lon': 0.0,
          'local_time_iso': '2026-09-05T00:00:00Z',
        });

        expect(g.gpsLat, 0.0);
        expect(g.gpsLon, 0.0);
      });
    });

    group('toJson round-trip', () {
      test('serialises and deserialises without data loss', () {
        const g = Grounding(
          gpsLat: 35.6762,
          gpsLon: 139.6503,
          gpsAccuracyM: 10.0,
          localTimeIso: '2026-09-05T14:30:00+09:00',
          timezone: 'Asia/Tokyo',
          currentLegId: 'leg-1',
          currentLegSlug: 'tokyo',
          currentTripId: 'trip-1',
          nextBookingId: 'bk-99',
        );

        final json = g.toJson();
        final g2 = Grounding.fromJson(json);

        expect(g2, equals(g));
      });
    });
  });
}
