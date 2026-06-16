// Tests for ApiClient.createLeg — verifies the correct HTTP method, path,
// request body, and parsed Leg response.

import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/services/api_client.dart';

import '../support/fake_http.dart';

void main() {
  group('ApiClient — leg endpoints', () {
    // ── createLeg ──────────────────────────────────────────────────────────

    group('createLeg', () {
      test('POSTs to /legs with correct body and parses the Leg response',
          () async {
        const payload = <String, dynamic>{
          'trip_id': 'trip-1',
          'name': 'Italy',
          'start_date': '2026-06-23',
          'end_date': '2026-06-24',
          'is_schengen': true,
          'sort_order': 0,
        };

        final f = fakeDio(
          (req) => jsonResponse({
            'id': 'leg-new',
            'trip_id': 'trip-1',
            'slug': 'italy',
            'name': 'Italy',
            'start_date': '2026-06-23',
            'end_date': '2026-06-24',
            'is_schengen': true,
            'sort_order': 0,
          }),
        );

        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);
        final leg = await client.createLeg(payload);

        // Response parsed correctly.
        expect(leg.id, equals('leg-new'));
        expect(leg.tripId, equals('trip-1'));
        expect(leg.slug, equals('italy'));
        expect(leg.name, equals('Italy'));
        expect(leg.startDate, equals('2026-06-23'));
        expect(leg.endDate, equals('2026-06-24'));
        expect(leg.isSchengen, isTrue);
        expect(leg.sortOrder, equals(0));

        // Exactly one request was made.
        expect(f.adapter.requests, hasLength(1));
        final req = f.adapter.requests.first;

        // Method and path are correct.
        expect(req.method, equals('POST'));
        expect(req.path, endsWith('/legs'));

        // Body fields were forwarded.
        final body = req.data as Map<String, dynamic>;
        expect(body['trip_id'], equals('trip-1'));
        expect(body['name'], equals('Italy'));
        expect(body['start_date'], equals('2026-06-23'));
        expect(body['end_date'], equals('2026-06-24'));
        expect(body['is_schengen'], isTrue);
        expect(body['sort_order'], equals(0));
      });

      test('parses optional fields (places, notes, emoji, color) when present',
          () async {
        final f = fakeDio(
          (req) => jsonResponse({
            'id': 'leg-2',
            'trip_id': 'trip-1',
            'slug': 'france',
            'name': 'France',
            'start_date': '2026-07-01',
            'end_date': '2026-08-05',
            'emoji': '🇫🇷',
            'color': '#3b82f6',
            'places': 'Paris, Lyon',
            'notes': 'Bring umbrella',
            'is_schengen': true,
            'sort_order': 1,
          }),
        );

        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);
        final leg = await client.createLeg({
          'trip_id': 'trip-1',
          'name': 'France',
          'start_date': '2026-07-01',
          'end_date': '2026-08-05',
        });

        expect(leg.emoji, equals('🇫🇷'));
        expect(leg.color, equals('#3b82f6'));
        expect(leg.places, equals('Paris, Lyon'));
        expect(leg.notes, equals('Bring umbrella'));
      });

      test('omits optional fields when absent from the server response',
          () async {
        final f = fakeDio(
          (req) => jsonResponse({
            'id': 'leg-3',
            'trip_id': 'trip-1',
            'slug': 'austria',
            'name': 'Austria',
            'start_date': '2026-08-06',
            'end_date': '2026-08-20',
            'sort_order': 2,
          }),
        );

        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);
        final leg = await client.createLeg({
          'trip_id': 'trip-1',
          'name': 'Austria',
          'start_date': '2026-08-06',
          'end_date': '2026-08-20',
        });

        expect(leg.emoji, isNull);
        expect(leg.color, isNull);
        expect(leg.places, isNull);
        expect(leg.notes, isNull);
        // is_schengen defaults to false when absent.
        expect(leg.isSchengen, isFalse);
      });
    });

    // ── listLegs ───────────────────────────────────────────────────────────

    group('listLegs', () {
      test('GET /legs returns a list of Legs', () async {
        final f = fakeDio(
          (req) => jsonResponse([
            {
              'id': 'leg-1',
              'trip_id': 'trip-1',
              'slug': 'italy',
              'name': 'Italy',
              'start_date': '2026-06-01',
              'end_date': '2026-06-30',
            },
            {
              'id': 'leg-2',
              'trip_id': 'trip-1',
              'slug': 'france',
              'name': 'France',
              'start_date': '2026-07-01',
              'end_date': '2026-08-05',
            },
          ]),
        );

        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);
        final legs = await client.listLegs();

        expect(legs, hasLength(2));
        expect(legs[0].id, equals('leg-1'));
        expect(legs[1].id, equals('leg-2'));

        final req = f.adapter.requests.first;
        expect(req.method, equals('GET'));
        expect(req.path, endsWith('/legs'));
      });

      test('GET /legs?trip_id= passes trip_id query param', () async {
        final f = fakeDio((req) => jsonResponse(<dynamic>[]));
        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);

        await client.listLegs(tripId: 'trip-42');

        final req = f.adapter.requests.first;
        expect(req.queryParameters['trip_id'], equals('trip-42'));
      });

      test('returns empty list when server returns []', () async {
        final f = fakeDio((req) => jsonResponse(<dynamic>[]));
        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);

        final legs = await client.listLegs();
        expect(legs, isEmpty);
      });
    });
  });
}
