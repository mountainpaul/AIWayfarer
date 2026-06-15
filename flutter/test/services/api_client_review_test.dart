import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/services/api_client.dart';

import '../support/fake_http.dart';

void main() {
  group('ApiClient — review endpoints', () {
    // ── listReviews ──────────────────────────────────────────────────────────

    group('listReviews', () {
      test('GET /reviews parses a list of TripReviews', () async {
        final f = fakeDio((req) => jsonResponse([
              {
                'id': 'rev-1',
                'trip_id': 'trip-1',
                'overall_rating': 4,
                'items': [],
              },
              {
                'id': 'rev-2',
                'trip_id': 'trip-2',
                'items': [],
              },
            ]));

        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);
        final reviews = await client.listReviews();

        expect(reviews, hasLength(2));
        expect(reviews[0].id, 'rev-1');
        expect(reviews[0].tripId, 'trip-1');
        expect(reviews[0].overallRating, 4);
        expect(reviews[1].id, 'rev-2');
        expect(reviews[1].tripId, 'trip-2');

        // Assert the request path and method.
        expect(f.adapter.requests, hasLength(1));
        final req = f.adapter.requests.first;
        expect(req.method, 'GET');
        expect(req.path, endsWith('/reviews'));
      });

      test('returns empty list when server returns []', () async {
        final f = fakeDio((req) => jsonResponse(<dynamic>[]));
        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);

        final reviews = await client.listReviews();
        expect(reviews, isEmpty);
      });
    });

    // ── getReview ────────────────────────────────────────────────────────────

    group('getReview', () {
      test('GET /reviews/{tripId} parses the returned TripReview', () async {
        final f = fakeDio((req) => jsonResponse({
              'id': 'rev-1',
              'trip_id': 'trip-abc',
              'overall_rating': 5,
              'pace_feedback': 'just_right',
              'items': [
                {
                  'id': 'ri-1',
                  'review_id': 'rev-1',
                  'subject_type': 'stay',
                  'subject_label': 'Hotel Tokyo',
                  'rating': 5,
                },
              ],
            }));

        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);
        final review = await client.getReview('trip-abc');

        expect(review, isNotNull);
        expect(review!.id, 'rev-1');
        expect(review.tripId, 'trip-abc');
        expect(review.overallRating, 5);
        expect(review.paceFeedback, 'just_right');
        expect(review.items, hasLength(1));
        expect(review.items.first.subjectLabel, 'Hotel Tokyo');

        expect(f.adapter.requests.first.method, 'GET');
        expect(f.adapter.requests.first.path, endsWith('/reviews/trip-abc'));
      });

      test('returns null on 404', () async {
        final f = fakeDio((req) => jsonResponse({'detail': 'not found'}, status: 404));
        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);

        final review = await client.getReview('no-such-trip');
        expect(review, isNull);
      });

      test('rethrows non-404 errors (e.g. 500)', () async {
        final f = fakeDio((req) => jsonResponse({'detail': 'oops'}, status: 500));
        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);

        expect(() => client.getReview('trip-bad'), throwsA(isA<DioException>()));
      });
    });

    // ── createReview ─────────────────────────────────────────────────────────

    group('createReview', () {
      test('POST /reviews forwards body and parses returned TripReview', () async {
        const payload = <String, dynamic>{
          'trip_id': 'trip-1',
          'overall_rating': 4,
          'items': <dynamic>[],
        };

        final f = fakeDio((req) => jsonResponse({
              'id': 'rev-new',
              'trip_id': 'trip-1',
              'overall_rating': 4,
              'items': [],
            }));

        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);
        final review = await client.createReview(payload);

        expect(review.id, 'rev-new');
        expect(review.tripId, 'trip-1');
        expect(review.overallRating, 4);

        // Assert path and method.
        expect(f.adapter.requests, hasLength(1));
        final req = f.adapter.requests.first;
        expect(req.method, 'POST');
        expect(req.path, endsWith('/reviews'));

        // Assert the body was forwarded.
        final body = req.data as Map<String, dynamic>;
        expect(body['trip_id'], 'trip-1');
        expect(body['overall_rating'], 4);
      });

      test('throws on server error', () async {
        final f = fakeDio((req) => jsonResponse({'detail': 'conflict'}, status: 409));
        final client = ApiClient(baseUrl: 'http://test.local', dio: f.dio);

        expect(
          () => client.createReview({'trip_id': 'trip-dup', 'items': []}),
          throwsA(isA<DioException>()),
        );
      });
    });
  });
}
