import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/booking.dart';

void main() {
  group('Booking', () {
    group('fromJson', () {
      test('maps all snake_case fields correctly', () {
        final b = Booking.fromJson({
          'id': 'bk-1',
          'leg_id': 'leg-1',
          'type': 'flight',
          'name': 'JAL 001 Tokyo → NYC',
          'status': 'confirmed',
          'start_date': '2026-09-01T09:00:00Z',
          'end_date': '2026-09-02T06:00:00Z',
          'confirmation': 'ABC123',
          'cost_cents': 85000,
          'currency': 'USD',
          'location_name': 'Narita Airport',
          'location_lat': 35.7720,
          'location_lon': 140.3929,
          'notes': 'Window seat',
          'created_at': '2026-06-01T00:00:00Z',
          'updated_at': '2026-06-14T00:00:00Z',
        });

        expect(b.id, 'bk-1');
        expect(b.legId, 'leg-1');
        expect(b.type, 'flight');
        expect(b.name, 'JAL 001 Tokyo → NYC');
        expect(b.status, 'confirmed');
        expect(b.startDate, '2026-09-01T09:00:00Z');
        expect(b.endDate, '2026-09-02T06:00:00Z');
        expect(b.confirmation, 'ABC123');
        expect(b.costCents, 85000);
        expect(b.currency, 'USD');
        expect(b.locationName, 'Narita Airport');
        expect(b.locationLat, closeTo(35.7720, 0.0001));
        expect(b.locationLon, closeTo(140.3929, 0.0001));
        expect(b.notes, 'Window seat');
        expect(b.createdAt, '2026-06-01T00:00:00Z');
        expect(b.updatedAt, '2026-06-14T00:00:00Z');
      });

      test('defaults apply when optional fields are omitted', () {
        final b = Booking.fromJson({
          'id': 'bk-2',
          'leg_id': 'leg-1',
          'type': 'hotel',
          'name': 'Park Hyatt',
          'status': 'pending',
        });

        expect(b.currency, 'USD');
        expect(b.startDate, isNull);
        expect(b.endDate, isNull);
        expect(b.confirmation, isNull);
        expect(b.costCents, isNull);
        expect(b.locationName, isNull);
        expect(b.locationLat, isNull);
        expect(b.locationLon, isNull);
        expect(b.notes, isNull);
        expect(b.createdAt, isNull);
        expect(b.updatedAt, isNull);
      });
    });

    group('toJson round-trip', () {
      test('serialises and deserialises without data loss', () {
        const b = Booking(
          id: 'bk-rt',
          legId: 'leg-rt',
          type: 'train',
          name: 'Shinkansen',
          status: 'confirmed',
          costCents: 15000,
          currency: 'JPY',
        );

        final json = b.toJson();
        final b2 = Booking.fromJson(json);

        expect(b2, equals(b));
      });
    });

    group('BookingX extension — startDateTime / endDateTime', () {
      test('returns parsed DateTime when dates are present', () {
        final b = Booking.fromJson({
          'id': 'bk-3',
          'leg_id': 'leg-1',
          'type': 'flight',
          'name': 'Test',
          'status': 'confirmed',
          'start_date': '2026-09-01T09:00:00Z',
          'end_date': '2026-09-01T22:00:00Z',
        });

        expect(b.startDateTime, isNotNull);
        expect(b.startDateTime!.year, 2026);
        expect(b.startDateTime!.month, 9);
        expect(b.startDateTime!.day, 1);

        expect(b.endDateTime, isNotNull);
        expect(b.endDateTime!.hour, isNotNull);
      });

      test('returns null when dates are absent', () {
        final b = Booking.fromJson({
          'id': 'bk-4',
          'leg_id': 'leg-1',
          'type': 'hotel',
          'name': 'Hotel',
          'status': 'confirmed',
        });

        expect(b.startDateTime, isNull);
        expect(b.endDateTime, isNull);
      });

      test('returns null when date string is malformed (tryParse)', () {
        const b = Booking(
          id: 'bk-5',
          legId: 'leg-1',
          type: 'hotel',
          name: 'Hotel',
          status: 'confirmed',
          startDate: 'not-a-date',
          endDate: 'also-bad',
        );

        expect(b.startDateTime, isNull);
        expect(b.endDateTime, isNull);
      });
    });

    group('BookingX extension — formattedCost', () {
      test('returns empty string when costCents is null', () {
        const b = Booking(
          id: 'bk-6',
          legId: 'leg-1',
          type: 'hotel',
          name: 'Hotel',
          status: 'confirmed',
        );
        expect(b.formattedCost, '');
      });

      test('formats USD with dollar symbol', () {
        const b = Booking(
          id: 'bk-7',
          legId: 'leg-1',
          type: 'flight',
          name: 'Flight',
          status: 'confirmed',
          costCents: 12099,
          currency: 'USD',
        );
        expect(b.formattedCost, contains(r'$'));
        expect(b.formattedCost, contains('120'));
      });

      test('formats EUR with euro symbol', () {
        const b = Booking(
          id: 'bk-8',
          legId: 'leg-1',
          type: 'hotel',
          name: 'Hotel',
          status: 'confirmed',
          costCents: 20000,
          currency: 'EUR',
        );
        expect(b.formattedCost, contains('€'));
        expect(b.formattedCost, contains('200'));
      });

      test('formats GBP with pound symbol', () {
        const b = Booking(
          id: 'bk-9',
          legId: 'leg-1',
          type: 'hotel',
          name: 'Hotel',
          status: 'confirmed',
          costCents: 15000,
          currency: 'GBP',
        );
        expect(b.formattedCost, contains('£'));
        expect(b.formattedCost, contains('150'));
      });

      test('formats unknown currency with code prefix', () {
        const b = Booking(
          id: 'bk-10',
          legId: 'leg-1',
          type: 'hotel',
          name: 'Hotel',
          status: 'confirmed',
          costCents: 5000,
          currency: 'JPY',
        );
        // Unknown code: _symbolFor returns 'JPY '
        expect(b.formattedCost, contains('JPY'));
        expect(b.formattedCost, contains('50'));
      });

      test('formats zero cents correctly', () {
        const b = Booking(
          id: 'bk-11',
          legId: 'leg-1',
          type: 'hotel',
          name: 'Hotel',
          status: 'confirmed',
          costCents: 0,
          currency: 'USD',
        );
        expect(b.formattedCost, contains('0'));
        expect(b.formattedCost, contains(r'$'));
      });
    });
  });
}
