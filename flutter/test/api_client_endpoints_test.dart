// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/grounding.dart';
import 'package:wayfarer/services/api_client.dart';

import 'support/fake_http.dart';

// Minimal fixture factories ─────────────────────────────────────────────────

Map<String, dynamic> _legJson({
  String id = 'leg1',
  String tripId = 'trip1',
  String slug = 'paris',
  String name = 'Paris',
  String startDate = '2026-06-01',
  String endDate = '2026-06-10',
}) =>
    {
      'id': id,
      'trip_id': tripId,
      'slug': slug,
      'name': name,
      'start_date': startDate,
      'end_date': endDate,
    };

Map<String, dynamic> _bookingJson({
  String id = 'bk1',
  String legId = 'leg1',
  String type = 'flight',
  String name = 'CDG → JFK',
  String status = 'confirmed',
}) =>
    {
      'id': id,
      'leg_id': legId,
      'type': type,
      'name': name,
      'status': status,
    };

Map<String, dynamic> _taskJson({
  String id = 'task1',
  String title = 'Pack bag',
  String priority = 'high',
  bool isDone = false,
}) =>
    {
      'id': id,
      'title': title,
      'priority': priority,
      'is_done': isDone,
    };

Map<String, dynamic> _packingJson({
  String id = 'pk1',
  String tripId = 'trip1',
  String category = 'clothing',
  String name = 'T-shirt',
  bool isPacked = false,
}) =>
    {
      'id': id,
      'trip_id': tripId,
      'category': category,
      'name': name,
      'is_packed': isPacked,
    };

Map<String, dynamic> _journalJson({
  String id = 'j1',
  String content = 'Great day in Paris.',
}) =>
    {
      'id': id,
      'content': content,
    };

Map<String, dynamic> _briefingJson({
  String id = 'br1',
  String date = '2026-06-14',
  String markdown = '# Morning briefing',
}) =>
    {
      'id': id,
      'date': date,
      'markdown': markdown,
    };

Map<String, dynamic> _tripJson({
  String id = 't1',
  String name = 'Europe',
  String startDate = '2026-06-01',
  String endDate = '2026-06-30',
}) =>
    {
      'id': id,
      'name': name,
      'start_date': startDate,
      'end_date': endDate,
    };

// ───────────────────────────────────────────────────────────────────────────

void main() {
  // ── Trips ──────────────────────────────────────────────────────────────────

  group('getTrip', () {
    test('GETs /trips/{id} and parses Trip', () async {
      final f = fakeDio((_) => jsonResponse(_tripJson()));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final trip = await api.getTrip('t1');

      expect(trip.id, 't1');
      expect(trip.name, 'Europe');
      final req = f.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/trips/t1');
    });
  });

  // ── Legs ───────────────────────────────────────────────────────────────────

  group('getLeg', () {
    test('GETs /legs/{id} and parses Leg', () async {
      final f = fakeDio((_) => jsonResponse(_legJson()));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final leg = await api.getLeg('leg1');

      expect(leg.id, 'leg1');
      expect(leg.name, 'Paris');
      final req = f.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/legs/leg1');
    });
  });

  group('listLegs', () {
    test('GETs /legs with no query params when tripId is null', () async {
      final f = fakeDio((_) => jsonResponse([_legJson()]));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final legs = await api.listLegs();

      expect(legs.single.id, 'leg1');
      final req = f.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/legs');
      expect(req.queryParameters, isEmpty);
    });

    test('forwards trip_id query param when provided', () async {
      final f = fakeDio((_) => jsonResponse(<dynamic>[]));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.listLegs(tripId: 'trip1');

      expect(
        f.adapter.requests.single.queryParameters,
        {'trip_id': 'trip1'},
      );
    });
  });

  group('patchLeg', () {
    test('PATCHes /legs/{id} and parses the updated Leg', () async {
      final f = fakeDio(
        (_) => jsonResponse(_legJson(name: 'Paris Updated')),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final leg = await api.patchLeg('leg1', {'name': 'Paris Updated'});

      expect(leg.name, 'Paris Updated');
      final req = f.adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/legs/leg1');
      expect(req.data, {'name': 'Paris Updated'});
    });
  });

  // ── Bookings ───────────────────────────────────────────────────────────────

  group('getBooking', () {
    test('GETs /bookings/{id} and parses Booking', () async {
      final f = fakeDio((_) => jsonResponse(_bookingJson()));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final booking = await api.getBooking('bk1');

      expect(booking.id, 'bk1');
      expect(booking.name, 'CDG → JFK');
      final req = f.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/bookings/bk1');
    });
  });

  group('createBooking', () {
    test('POSTs to /bookings and parses the new Booking', () async {
      final f = fakeDio(
        (opts) => jsonResponse(
          _bookingJson(name: opts.data['name'] as String),
          status: 201,
        ),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final body = {
        'leg_id': 'leg1',
        'type': 'flight',
        'name': 'JFK → CDG',
        'status': 'confirmed',
      };
      final booking = await api.createBooking(body);

      expect(booking.name, 'JFK → CDG');
      final req = f.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/bookings');
      expect(req.data, body);
    });
  });

  group('patchBooking', () {
    test('PATCHes /bookings/{id} and parses the updated Booking', () async {
      final f = fakeDio(
        (_) => jsonResponse(_bookingJson(status: 'cancelled')),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final booking =
          await api.patchBooking('bk1', {'status': 'cancelled'});

      expect(booking.status, 'cancelled');
      final req = f.adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/bookings/bk1');
      expect(req.data, {'status': 'cancelled'});
    });
  });

  group('deleteBooking', () {
    test('DELETEs /bookings/{id}', () async {
      final f = fakeDio((_) => jsonResponse(null, status: 204));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.deleteBooking('bk1');

      expect(f.adapter.requests.single.method, 'DELETE');
      expect(f.adapter.requests.single.path, '/bookings/bk1');
    });
  });

  // ── Tasks ──────────────────────────────────────────────────────────────────

  group('listTasks', () {
    test('GETs /tasks with no query params when filters are null', () async {
      final f = fakeDio((_) => jsonResponse([_taskJson()]));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final tasks = await api.listTasks();

      expect(tasks.single.id, 'task1');
      final req = f.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/tasks');
      expect(req.queryParameters, isEmpty);
    });

    test('forwards leg_id query param', () async {
      final f = fakeDio((_) => jsonResponse(<dynamic>[]));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.listTasks(legId: 'leg1');

      expect(f.adapter.requests.single.queryParameters, {'leg_id': 'leg1'});
    });

    test('forwards is_done query param', () async {
      final f = fakeDio((_) => jsonResponse(<dynamic>[]));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.listTasks(isDone: false);

      expect(
        f.adapter.requests.single.queryParameters,
        {'is_done': false},
      );
    });

    test('forwards both leg_id and is_done together', () async {
      final f = fakeDio((_) => jsonResponse(<dynamic>[]));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.listTasks(legId: 'leg1', isDone: true);

      expect(
        f.adapter.requests.single.queryParameters,
        {'leg_id': 'leg1', 'is_done': true},
      );
    });
  });

  group('createTask', () {
    test('POSTs to /tasks and parses the new Task', () async {
      final f = fakeDio(
        (opts) => jsonResponse(
          _taskJson(title: opts.data['title'] as String),
          status: 201,
        ),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final body = {'title': 'Book hotel', 'priority': 'medium'};
      final task = await api.createTask(body);

      expect(task.title, 'Book hotel');
      final req = f.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/tasks');
      expect(req.data, body);
    });
  });

  group('patchTask', () {
    test('PATCHes /tasks/{id} and parses the updated Task', () async {
      final f = fakeDio(
        (_) => jsonResponse(_taskJson(isDone: true)),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final task = await api.patchTask('task1', {'is_done': true});

      expect(task.isDone, isTrue);
      final req = f.adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/tasks/task1');
      expect(req.data, {'is_done': true});
    });
  });

  group('toggleTaskDone', () {
    test('PATCHes /tasks/{id}/done with no body', () async {
      final f = fakeDio((_) => jsonResponse(_taskJson(isDone: true)));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final task = await api.toggleTaskDone('task1');

      expect(task.isDone, isTrue);
      final req = f.adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/tasks/task1/done');
    });
  });

  group('deleteTask', () {
    test('DELETEs /tasks/{id}', () async {
      final f = fakeDio((_) => jsonResponse(null, status: 204));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.deleteTask('task1');

      expect(f.adapter.requests.single.method, 'DELETE');
      expect(f.adapter.requests.single.path, '/tasks/task1');
    });
  });

  // ── Packing ────────────────────────────────────────────────────────────────

  group('listPacking', () {
    test('GETs /packing with no query params when tripId is null', () async {
      final f = fakeDio((_) => jsonResponse([_packingJson()]));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final items = await api.listPacking();

      expect(items.single.id, 'pk1');
      final req = f.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/packing');
      expect(req.queryParameters, isEmpty);
    });

    test('forwards trip_id query param', () async {
      final f = fakeDio((_) => jsonResponse(<dynamic>[]));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.listPacking(tripId: 'trip1');

      expect(
        f.adapter.requests.single.queryParameters,
        {'trip_id': 'trip1'},
      );
    });
  });

  group('createPacking', () {
    test('POSTs to /packing and parses the new PackingItem', () async {
      final f = fakeDio(
        (opts) => jsonResponse(
          _packingJson(name: opts.data['name'] as String),
          status: 201,
        ),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final body = {
        'trip_id': 'trip1',
        'category': 'clothing',
        'name': 'Rain jacket',
      };
      final item = await api.createPacking(body);

      expect(item.name, 'Rain jacket');
      final req = f.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/packing');
      expect(req.data, body);
    });
  });

  group('patchPacking', () {
    test('PATCHes /packing/{id} and parses the updated PackingItem', () async {
      final f = fakeDio(
        (_) => jsonResponse(_packingJson(isPacked: true)),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final item = await api.patchPacking('pk1', {'is_packed': true});

      expect(item.isPacked, isTrue);
      final req = f.adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/packing/pk1');
      expect(req.data, {'is_packed': true});
    });
  });

  group('togglePacked', () {
    test('PATCHes /packing/{id}/packed with no body', () async {
      final f = fakeDio((_) => jsonResponse(_packingJson(isPacked: true)));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final item = await api.togglePacked('pk1');

      expect(item.isPacked, isTrue);
      final req = f.adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/packing/pk1/packed');
    });
  });

  group('deletePacking', () {
    test('DELETEs /packing/{id}', () async {
      final f = fakeDio((_) => jsonResponse(null, status: 204));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.deletePacking('pk1');

      expect(f.adapter.requests.single.method, 'DELETE');
      expect(f.adapter.requests.single.path, '/packing/pk1');
    });
  });

  // ── Journal ────────────────────────────────────────────────────────────────

  group('listJournal', () {
    test('GETs /journal with no query params when legId is null', () async {
      final f = fakeDio((_) => jsonResponse([_journalJson()]));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final entries = await api.listJournal();

      expect(entries.single.id, 'j1');
      final req = f.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/journal');
      expect(req.queryParameters, isEmpty);
    });

    test('forwards leg_id query param', () async {
      final f = fakeDio((_) => jsonResponse(<dynamic>[]));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.listJournal(legId: 'leg1');

      expect(
        f.adapter.requests.single.queryParameters,
        {'leg_id': 'leg1'},
      );
    });
  });

  group('createJournal', () {
    test('POSTs to /journal and parses the new JournalEntry', () async {
      final f = fakeDio(
        (opts) => jsonResponse(
          _journalJson(content: opts.data['content'] as String),
          status: 201,
        ),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final body = {'content': 'Visited the Eiffel Tower.', 'leg_id': 'leg1'};
      final entry = await api.createJournal(body);

      expect(entry.content, 'Visited the Eiffel Tower.');
      final req = f.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/journal');
      expect(req.data, body);
    });
  });

  // ── Chat ───────────────────────────────────────────────────────────────────

  group('chat', () {
    Grounding grounding() => const Grounding(
          localTimeIso: '2026-06-14T09:00:00',
          currentLegId: 'leg1',
        );

    test('POSTs to /chat and parses ChatResponse', () async {
      final f = fakeDio(
        (_) => jsonResponse({
          'answer': 'You are in Paris.',
          'confidence': 'high',
        }),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final response = await api.chat(
        message: 'Where am I?',
        grounding: grounding(),
      );

      expect(response.answer, 'You are in Paris.');
      expect(response.confidence, 'high');
      final req = f.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/chat');
    });

    test('includes message, grounding, and default mode in body', () async {
      final f = fakeDio(
        (_) => jsonResponse({'answer': 'ok'}),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);
      final g = grounding();

      await api.chat(message: 'Hello', grounding: g);

      final body = f.adapter.requests.single.data as Map<String, dynamic>;
      expect(body['message'], 'Hello');
      expect(body['mode'], 'companion');
      expect(body['grounding'], isA<Map<String, dynamic>>());
      expect(body.containsKey('session_id'), isFalse);
    });

    test('includes session_id when provided', () async {
      final f = fakeDio((_) => jsonResponse({'answer': 'ok'}));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.chat(
        message: 'Hello',
        grounding: grounding(),
        sessionId: 'sess-abc',
      );

      final body = f.adapter.requests.single.data as Map<String, dynamic>;
      expect(body['session_id'], 'sess-abc');
    });

    test('forwards custom mode', () async {
      final f = fakeDio((_) => jsonResponse({'answer': 'ok'}));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.chat(
        message: 'Plan my trip',
        grounding: grounding(),
        mode: 'planning',
      );

      final body = f.adapter.requests.single.data as Map<String, dynamic>;
      expect(body['mode'], 'planning');
    });

    test('parses iterations list in ChatResponse', () async {
      final f = fakeDio(
        (_) => jsonResponse({
          'answer': 'Done.',
          'iterations': [
            {'label': 'plan', 'content': 'step 1'},
          ],
        }),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final response = await api.chat(
        message: 'Plan something',
        grounding: grounding(),
      );

      expect(response.iterations.single.label, 'plan');
      expect(response.iterations.single.content, 'step 1');
    });
  });

  // ── Grounding ──────────────────────────────────────────────────────────────

  group('getGrounding', () {
    test('GETs /grounding and returns a map', () async {
      final f = fakeDio(
        (_) => jsonResponse({'local_time_iso': '2026-06-14T09:00:00'}),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.getGrounding();

      expect(result['local_time_iso'], '2026-06-14T09:00:00');
      final req = f.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/grounding');
    });

    test('returns empty map when response data is null', () async {
      final f = fakeDio((_) => jsonResponse(null));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.getGrounding();

      expect(result, isEmpty);
    });
  });

  // ── Briefing ───────────────────────────────────────────────────────────────

  group('generateBriefing', () {
    test('POSTs to /briefing/generate with no date and parses Briefing',
        () async {
      final f = fakeDio((_) => jsonResponse(_briefingJson()));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final briefing = await api.generateBriefing();

      expect(briefing.id, 'br1');
      expect(briefing.markdown, '# Morning briefing');
      final req = f.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/briefing/generate');
      expect((req.data as Map<String, dynamic>), isEmpty);
    });

    test('includes date in body when provided', () async {
      final f = fakeDio(
        (_) => jsonResponse(_briefingJson(date: '2026-06-15')),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final briefing = await api.generateBriefing(date: '2026-06-15');

      expect(briefing.date, '2026-06-15');
      final body =
          f.adapter.requests.single.data as Map<String, dynamic>;
      expect(body['date'], '2026-06-15');
    });
  });

  // ── Coverage ───────────────────────────────────────────────────────────────

  group('getCoverage', () {
    test('GETs /coverage with no query params when tripId is null', () async {
      final f = fakeDio(
        (_) => jsonResponse([
          {'country': 'FR', 'days': 10}
        ]),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.getCoverage();

      expect(result.single['country'], 'FR');
      final req = f.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/coverage');
      expect(req.queryParameters, isEmpty);
    });

    test('forwards trip_id query param', () async {
      final f = fakeDio((_) => jsonResponse(<dynamic>[]));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.getCoverage(tripId: 'trip1');

      expect(
        f.adapter.requests.single.queryParameters,
        {'trip_id': 'trip1'},
      );
    });

    test('returns empty list when response is null', () async {
      final f = fakeDio((_) => jsonResponse(null));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.getCoverage();

      expect(result, isEmpty);
    });
  });

  // ── Budget ─────────────────────────────────────────────────────────────────

  group('getBudget', () {
    test('GETs /budget with no query params when tripId is null', () async {
      final f = fakeDio(
        (_) => jsonResponse({'total_cents': 150000, 'spent_cents': 50000}),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.getBudget();

      expect(result['total_cents'], 150000);
      final req = f.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/budget');
      expect(req.queryParameters, isEmpty);
    });

    test('forwards trip_id query param', () async {
      final f = fakeDio((_) => jsonResponse({}));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.getBudget(tripId: 'trip1');

      expect(
        f.adapter.requests.single.queryParameters,
        {'trip_id': 'trip1'},
      );
    });

    test('returns empty map when response data is null', () async {
      final f = fakeDio((_) => jsonResponse(null));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.getBudget();

      expect(result, isEmpty);
    });
  });

  // ── Gmail Scanner ──────────────────────────────────────────────────────────

  group('scanBookingEmails', () {
    test('POSTs to /gmail/scan-bookings with default months', () async {
      final f = fakeDio(
        (_) => jsonResponse({'scanned': 12, 'found': 3}),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.scanBookingEmails();

      expect(result['scanned'], 12);
      final req = f.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/gmail/scan-bookings');
      expect(req.queryParameters['months'], 6);
    });

    test('forwards custom months value', () async {
      final f = fakeDio((_) => jsonResponse({}));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.scanBookingEmails(months: 3);

      expect(f.adapter.requests.single.queryParameters['months'], 3);
    });

    test('returns empty map when response data is null', () async {
      final f = fakeDio((_) => jsonResponse(null));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.scanBookingEmails();

      expect(result, isEmpty);
    });
  });

  group('importBookings', () {
    test('POSTs to /gmail/import-bookings with the bookings list', () async {
      final f = fakeDio(
        (_) => jsonResponse({'imported': 2, 'skipped': 0}),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final bookings = [
        {'leg_id': 'leg1', 'type': 'flight', 'name': 'CDG→JFK', 'status': 'confirmed'},
        {'leg_id': 'leg1', 'type': 'hotel', 'name': 'Hotel X', 'status': 'confirmed'},
      ];
      final result = await api.importBookings(bookings);

      expect(result['imported'], 2);
      final req = f.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/gmail/import-bookings');
      expect(req.data, bookings);
    });

    test('returns empty map when response data is null', () async {
      final f = fakeDio((_) => jsonResponse(null));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.importBookings([]);

      expect(result, isEmpty);
    });
  });

  group('scanLoyaltyOffers', () {
    test('POSTs to /gmail/scan-offers with default months', () async {
      final f = fakeDio(
        (_) => jsonResponse({'offers_found': 5}),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.scanLoyaltyOffers();

      expect(result['offers_found'], 5);
      final req = f.adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/gmail/scan-offers');
      expect(req.queryParameters['months'], 2);
    });

    test('forwards custom months value', () async {
      final f = fakeDio((_) => jsonResponse({}));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.scanLoyaltyOffers(months: 4);

      expect(f.adapter.requests.single.queryParameters['months'], 4);
    });

    test('returns empty map when response data is null', () async {
      final f = fakeDio((_) => jsonResponse(null));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.scanLoyaltyOffers();

      expect(result, isEmpty);
    });
  });

  // ── Sync ───────────────────────────────────────────────────────────────────

  group('syncSnapshot', () {
    test('GETs /sync/snapshot with no query params when since is null',
        () async {
      final f = fakeDio(
        (_) => jsonResponse({'server_time': '2026-06-14T09:00:00Z', 'trips': []}),
      );
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.syncSnapshot();

      expect(result['server_time'], '2026-06-14T09:00:00Z');
      final req = f.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/sync/snapshot');
      expect(req.queryParameters, isEmpty);
    });

    test('forwards since cursor as query param', () async {
      final f = fakeDio((_) => jsonResponse({}));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      await api.syncSnapshot(since: '2026-06-13T00:00:00Z');

      expect(
        f.adapter.requests.single.queryParameters,
        {'since': '2026-06-13T00:00:00Z'},
      );
    });

    test('returns empty map when response data is null', () async {
      final f = fakeDio((_) => jsonResponse(null));
      final api = ApiClient(baseUrl: 'http://x', dio: f.dio);

      final result = await api.syncSnapshot();

      expect(result, isEmpty);
    });
  });
}
