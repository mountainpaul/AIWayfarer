import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/traveler_profile.dart';

void main() {
  group('TravelerProfile', () {
    test('fromJson maps snake_case fields and the JSON blob', () {
      final p = TravelerProfile.fromJson({
        'id': 'abc',
        'user_id': 'paul',
        'lodging_style': 'boutique',
        'transport_preference': 'trains',
        'travel_pace': 'relaxed',
        'budget_tier': 'mid_range',
        'profile_summary': 'Likes slow travel.',
        'preferences_blob': {
          'interests': ['food', 'history'],
          'avoids': ['5am flights'],
        },
        'created_at': '2026-06-14T00:00:00Z',
        'updated_at': '2026-06-14T00:00:00Z',
      });

      expect(p.userId, 'paul');
      expect(p.lodgingStyle, 'boutique');
      expect(p.transportPreference, 'trains');
      expect(p.profileSummary, 'Likes slow travel.');
      expect(p.interests, ['food', 'history']);
      expect(p.avoids, ['5am flights']);
    });

    test('defaults blob to empty and extensions return empty lists', () {
      final p = TravelerProfile.fromJson({'id': 'x', 'user_id': 'paul'});
      expect(p.preferencesBlob, isEmpty);
      expect(p.interests, isEmpty);
      expect(p.avoids, isEmpty);
    });

    test('extensions coerce non-list / missing blob values safely', () {
      final p = TravelerProfile.fromJson({
        'id': 'x',
        'user_id': 'paul',
        'preferences_blob': {'interests': 'not-a-list'},
      });
      expect(p.interests, isEmpty); // malformed → empty, not a crash
      expect(p.avoids, isEmpty); // missing key → empty
    });

    test('coerces numeric blob entries to strings', () {
      final p = TravelerProfile.fromJson({
        'id': 'x',
        'user_id': 'paul',
        'preferences_blob': {
          'interests': [1, 'food']
        },
      });
      expect(p.interests, ['1', 'food']);
    });
  });
}
