import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/trip.dart';

void main() {
  group('Trip', () {
    group('fromJson', () {
      test('maps snake_case fields correctly', () {
        final t = Trip.fromJson({
          'id': 'trip-1',
          'name': 'Japan Adventure',
          'start_date': '2026-09-01',
          'end_date': '2026-09-30',
          'status': 'active',
          'created_at': '2026-06-01T00:00:00Z',
          'updated_at': '2026-06-14T00:00:00Z',
        });

        expect(t.id, 'trip-1');
        expect(t.name, 'Japan Adventure');
        expect(t.startDate, '2026-09-01');
        expect(t.endDate, '2026-09-30');
        expect(t.status, 'active');
        expect(t.createdAt, '2026-06-01T00:00:00Z');
        expect(t.updatedAt, '2026-06-14T00:00:00Z');
      });

      test('default status is "planning" when omitted', () {
        final t = Trip.fromJson({
          'id': 'trip-2',
          'name': 'Europe',
          'start_date': '2026-10-01',
          'end_date': '2026-10-15',
        });

        expect(t.status, 'planning');
        expect(t.createdAt, isNull);
        expect(t.updatedAt, isNull);
      });
    });

    group('toJson round-trip', () {
      test('serialises and deserialises without data loss', () {
        const t = Trip(
          id: 'trip-rt',
          name: 'Round Trip Test',
          startDate: '2026-08-01',
          endDate: '2026-08-14',
          status: 'completed',
        );

        final json = t.toJson();
        final t2 = Trip.fromJson(json);

        expect(t2, equals(t));
      });
    });

    group('TripX extension', () {
      test('startDateTime parses the ISO date string', () {
        const t = Trip(
          id: 'x',
          name: 'x',
          startDate: '2026-09-01',
          endDate: '2026-09-30',
        );
        expect(t.startDateTime, equals(DateTime(2026, 9, 1)));
      });

      test('endDateTime parses the ISO date string', () {
        const t = Trip(
          id: 'x',
          name: 'x',
          startDate: '2026-09-01',
          endDate: '2026-09-30',
        );
        expect(t.endDateTime, equals(DateTime(2026, 9, 30)));
      });

      test('startDateTime and endDateTime parse full ISO-8601 timestamps', () {
        const t = Trip(
          id: 'x',
          name: 'x',
          startDate: '2026-09-01T08:00:00Z',
          endDate: '2026-09-30T22:59:00Z',
        );
        expect(t.startDateTime.year, 2026);
        expect(t.startDateTime.month, 9);
        expect(t.startDateTime.day, 1);
        expect(t.endDateTime.month, 9);
        expect(t.endDateTime.day, 30);
      });
    });
  });
}
