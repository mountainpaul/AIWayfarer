import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/journal_entry.dart';

void main() {
  group('JournalEntry', () {
    group('fromJson', () {
      test('maps all snake_case fields correctly', () {
        final j = JournalEntry.fromJson({
          'id': 'je-1',
          'leg_id': 'leg-1',
          'content': 'Amazing ramen today.',
          'entry_type': 'food',
          'location_name': 'Ichiran Ramen Shinjuku',
          'location_lat': 35.6897,
          'location_lon': 139.6922,
          'created_at': '2026-09-05T12:30:00Z',
        });

        expect(j.id, 'je-1');
        expect(j.legId, 'leg-1');
        expect(j.content, 'Amazing ramen today.');
        expect(j.entryType, 'food');
        expect(j.locationName, 'Ichiran Ramen Shinjuku');
        expect(j.locationLat, closeTo(35.6897, 0.0001));
        expect(j.locationLon, closeTo(139.6922, 0.0001));
        expect(j.createdAt, '2026-09-05T12:30:00Z');
      });

      test('defaults entryType to "note" when omitted', () {
        final j = JournalEntry.fromJson({
          'id': 'je-2',
          'content': 'Quick note.',
        });

        expect(j.entryType, 'note');
        expect(j.legId, isNull);
        expect(j.locationName, isNull);
        expect(j.locationLat, isNull);
        expect(j.locationLon, isNull);
        expect(j.createdAt, isNull);
      });

      test('accepts explicit entryType override', () {
        final j = JournalEntry.fromJson({
          'id': 'je-3',
          'content': 'Saw Mt Fuji.',
          'entry_type': 'photo',
        });

        expect(j.entryType, 'photo');
      });
    });

    group('toJson round-trip', () {
      test('serialises and deserialises without data loss', () {
        const j = JournalEntry(
          id: 'je-rt',
          legId: 'leg-rt',
          content: 'Great hike!',
          entryType: 'note',
          locationName: 'Mount Kurama',
          locationLat: 35.1167,
          locationLon: 135.7667,
          createdAt: '2026-09-10T08:00:00Z',
        );

        final json = j.toJson();
        final j2 = JournalEntry.fromJson(json);

        expect(j2, equals(j));
      });
    });
  });
}
