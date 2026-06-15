import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/leg.dart';

void main() {
  group('Leg', () {
    group('fromJson', () {
      test('maps snake_case fields correctly', () {
        final l = Leg.fromJson({
          'id': 'leg-1',
          'trip_id': 'trip-1',
          'slug': 'tokyo',
          'name': 'Tokyo',
          'emoji': '🗼',
          'color': '#FF5733',
          'start_date': '2026-09-01',
          'end_date': '2026-09-10',
          'is_schengen': true,
          'budget_cents': 250000,
          'currency': 'JPY',
          'places': 'Tokyo, Kyoto',
          'notes': 'Book bullet train',
          'sort_order': 2,
          'created_at': '2026-06-01T00:00:00Z',
          'updated_at': '2026-06-14T00:00:00Z',
        });

        expect(l.id, 'leg-1');
        expect(l.tripId, 'trip-1');
        expect(l.slug, 'tokyo');
        expect(l.name, 'Tokyo');
        expect(l.emoji, '🗼');
        expect(l.color, '#FF5733');
        expect(l.startDate, '2026-09-01');
        expect(l.endDate, '2026-09-10');
        expect(l.isSchengen, isTrue);
        expect(l.budgetCents, 250000);
        expect(l.currency, 'JPY');
        expect(l.places, 'Tokyo, Kyoto');
        expect(l.notes, 'Book bullet train');
        expect(l.sortOrder, 2);
        expect(l.createdAt, '2026-06-01T00:00:00Z');
        expect(l.updatedAt, '2026-06-14T00:00:00Z');
      });

      test('defaults apply when optional fields are omitted', () {
        final l = Leg.fromJson({
          'id': 'leg-2',
          'trip_id': 'trip-1',
          'slug': 'osaka',
          'name': 'Osaka',
          'start_date': '2026-09-11',
          'end_date': '2026-09-15',
        });

        expect(l.isSchengen, isFalse);
        expect(l.currency, 'USD');
        expect(l.sortOrder, 0);
        expect(l.emoji, isNull);
        expect(l.color, isNull);
        expect(l.budgetCents, isNull);
        expect(l.places, isNull);
        expect(l.notes, isNull);
        expect(l.createdAt, isNull);
        expect(l.updatedAt, isNull);
      });
    });

    group('toJson round-trip', () {
      test('serialises and deserialises without data loss', () {
        const l = Leg(
          id: 'leg-rt',
          tripId: 'trip-rt',
          slug: 'paris',
          name: 'Paris',
          startDate: '2026-10-01',
          endDate: '2026-10-10',
          isSchengen: true,
          currency: 'EUR',
          sortOrder: 1,
        );

        final json = l.toJson();
        final l2 = Leg.fromJson(json);

        expect(l2, equals(l));
      });
    });

    group('LegX extension — startDateTime / endDateTime', () {
      test('parses date-only strings', () {
        const l = Leg(
          id: 'x',
          tripId: 'x',
          slug: 'x',
          name: 'x',
          startDate: '2026-09-01',
          endDate: '2026-09-10',
        );
        expect(l.startDateTime, equals(DateTime(2026, 9, 1)));
        expect(l.endDateTime, equals(DateTime(2026, 9, 10)));
      });
    });

    group('LegX extension — containsDate', () {
      // Leg: 2026-09-01 → 2026-09-10 (both inclusive per the comment)
      const l = Leg(
        id: 'x',
        tripId: 'x',
        slug: 'x',
        name: 'x',
        startDate: '2026-09-01',
        endDate: '2026-09-10',
      );

      test('returns true on the start date', () {
        expect(l.containsDate(DateTime(2026, 9, 1)), isTrue);
      });

      test('returns true on the end date', () {
        expect(l.containsDate(DateTime(2026, 9, 10)), isTrue);
      });

      test('returns true for a date strictly between start and end', () {
        expect(l.containsDate(DateTime(2026, 9, 5)), isTrue);
      });

      test('returns false for the day before start', () {
        expect(l.containsDate(DateTime(2026, 8, 31)), isFalse);
      });

      test('returns false for the day after end', () {
        expect(l.containsDate(DateTime(2026, 9, 11)), isFalse);
      });

      test('returns false for a date well outside the range', () {
        expect(l.containsDate(DateTime(2025, 1, 1)), isFalse);
      });

      test('handles time component — midnight on end date still inside', () {
        expect(l.containsDate(DateTime(2026, 9, 10, 0, 0, 0)), isTrue);
      });

      test('returns false for end+1 at midnight', () {
        expect(l.containsDate(DateTime(2026, 9, 11, 0, 0, 0)), isFalse);
      });
    });
  });
}
