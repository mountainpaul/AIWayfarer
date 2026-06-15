import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/traveler_profile.dart';
import 'package:wayfarer/services/api_client.dart';

import 'support/fake_http.dart';

void main() {
  group('base URL normalization', () {
    test('appends /api/v1 to a bare host', () {
      expect(ApiClient(baseUrl: 'http://localhost:8000').resolvedBaseUrl,
          'http://localhost:8000/api/v1');
    });

    test('strips trailing slashes before appending', () {
      expect(ApiClient(baseUrl: 'http://localhost:8000//').resolvedBaseUrl,
          'http://localhost:8000/api/v1');
    });

    test('leaves an already-versioned URL untouched', () {
      expect(ApiClient(baseUrl: 'http://localhost:8000/api/v1').resolvedBaseUrl,
          'http://localhost:8000/api/v1');
    });
  });

  group('trips', () {
    test('listTrips parses a JSON array', () async {
      final f = fakeDio((_) => jsonResponse([
            {
              'id': 't1',
              'name': 'Europe',
              'start_date': '2026-06-01',
              'end_date': '2026-06-30',
            }
          ]));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final trips = await api.listTrips();
      expect(trips.single.name, 'Europe');
      expect(f.adapter.requests.single.path, '/trips');
      expect(f.adapter.requests.single.method, 'GET');
    });

    test('createTrip POSTs the body and parses the result', () async {
      final f = fakeDio((opts) => jsonResponse({
            'id': 't2',
            'name': opts.data['name'],
            'start_date': '2026-07-01',
            'end_date': '2026-07-10',
          }, status: 201));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final trip = await api.createTrip({'name': 'Japan'});
      expect(trip.id, 't2');
      expect(trip.name, 'Japan');
      final req = f.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.data, {'name': 'Japan'});
    });

    test('patchTrip sends a PATCH to the id path', () async {
      final f = fakeDio((_) => jsonResponse({
            'id': 't1',
            'name': 'Renamed',
            'start_date': '2026-06-01',
            'end_date': '2026-06-30',
          }));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.patchTrip('t1', {'name': 'Renamed'});
      final req = f.adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/trips/t1');
    });

    test('deleteTrip issues a DELETE', () async {
      final f = fakeDio((_) => jsonResponse(null, status: 204));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.deleteTrip('t1');
      expect(f.adapter.requests.single.method, 'DELETE');
      expect(f.adapter.requests.single.path, '/trips/t1');
    });
  });

  group('query params', () {
    test('getSchengen forwards as_of and trip_id', () async {
      final f = fakeDio((_) => jsonResponse({'days_used': 10}));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final r = await api.getSchengen(asOf: '2026-06-14', tripId: 't1');
      expect(r['days_used'], 10);
      expect(f.adapter.requests.single.queryParameters,
          {'as_of': '2026-06-14', 'trip_id': 't1'});
    });

    test('listBookings filters by legId', () async {
      final f = fakeDio((_) => jsonResponse(const []));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.listBookings(legId: 'leg9');
      expect(f.adapter.requests.single.queryParameters, {'leg_id': 'leg9'});
    });
  });

  group('traveler profile', () {
    test('getProfile parses the singleton', () async {
      final f = fakeDio((_) => jsonResponse({
            'id': 'p1',
            'user_id': 'paul',
            'lodging_style': 'boutique',
            'preferences_blob': {'interests': ['food']},
          }));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final p = await api.getProfile();
      expect(p.userId, 'paul');
      expect(p.lodgingStyle, 'boutique');
      expect(p.interests, ['food']);
      expect(f.adapter.requests.single.path, '/profile');
    });

    test('patchProfile PATCHes /profile with the body', () async {
      final f = fakeDio((opts) => jsonResponse({
            'id': 'p1',
            'user_id': 'paul',
            'travel_pace': opts.data['travel_pace'],
          }));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final p = await api.patchProfile({'travel_pace': 'relaxed'});
      expect(p.travelPace, 'relaxed');
      expect(f.adapter.requests.single.method, 'PATCH');
    });
  });

  group('briefing 404 handling', () {
    test('getTodayBriefing returns null on 404 instead of throwing', () async {
      final f = fakeDio((_) => jsonResponse({'detail': 'none'}, status: 404));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      expect(await api.getTodayBriefing(), isNull);
    });

    test('getTodayBriefing rethrows non-404 errors', () async {
      final f = fakeDio((_) => jsonResponse({'detail': 'boom'}, status: 500));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      expect(api.getTodayBriefing(), throwsA(isA<DioException>()));
    });
  });

  group('mapDioError', () {
    test('maps a connection timeout (no response) to ApiUnreachable', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(mapDioError(e), isA<ApiUnreachable>());
    });

    test('leaves a server error (with response) as-is', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        response: Response(
            requestOptions: RequestOptions(path: '/x'), statusCode: 500),
      );
      expect(mapDioError(e), same(e));
    });

    test('passes through a non-Dio error unchanged', () {
      final e = StateError('nope');
      expect(mapDioError(e), same(e));
    });
  });
}
