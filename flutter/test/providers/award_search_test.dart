import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/services/award_search.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _container() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

// ---------------------------------------------------------------------------
// buildAwardLinks — pure function, no I/O
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildAwardLinks', () {
    final date = DateTime(2026, 8, 1);

    test('returns one link per engine (3 total)', () {
      final links = buildAwardLinks(
          origin: 'SFO', destination: 'NRT', date: date);
      expect(links.length, 3);
    });

    test('engine names are Seats.aero, PointsYeah, Roame.travel', () {
      final names =
          buildAwardLinks(origin: 'SFO', destination: 'NRT', date: date)
              .map((l) => l.engine)
              .toList();
      expect(names, containsAll(['Seats.aero', 'PointsYeah', 'Roame.travel']));
    });

    test('normalises lowercase origin/destination to uppercase', () {
      final links =
          buildAwardLinks(origin: 'sfo', destination: 'nrt', date: date);
      for (final link in links) {
        // Each engine uses a different param name; verify none contains lowercase.
        final raw = link.url.toString();
        expect(raw.contains('sfo'), isFalse,
            reason: '${link.engine} URL contains lowercase origin');
        expect(raw.contains('nrt'), isFalse,
            reason: '${link.engine} URL contains lowercase destination');
      }
    });

    test('date is formatted as YYYY-MM-DD', () {
      final links = buildAwardLinks(
          origin: 'JFK', destination: 'LHR', date: DateTime(2026, 3, 5));
      for (final link in links) {
        expect(link.url.toString(), contains('2026-03-05'),
            reason: '${link.engine} URL missing formatted date');
      }
    });

    test('windowDays default is 3: end date is start + 3', () {
      final links =
          buildAwardLinks(origin: 'LAX', destination: 'CDG', date: date);
      // Seats.aero encodes windowDays as additional_days_num
      final seatsAero = links.firstWhere((l) => l.engine == 'Seats.aero');
      expect(seatsAero.url.queryParameters['additional_days_num'], '3');
    });

    test('windowDays override is respected', () {
      final links = buildAwardLinks(
          origin: 'LAX', destination: 'CDG', date: date, windowDays: 1);
      final seatsAero = links.firstWhere((l) => l.engine == 'Seats.aero');
      expect(seatsAero.url.queryParameters['additional_days_num'], '1');

      final endDate = DateTime(2026, 8, 2); // +1 day
      final expected =
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      final pointsYeah = links.firstWhere((l) => l.engine == 'PointsYeah');
      expect(pointsYeah.url.queryParameters['departDateSec'], expected);
    });

    test('Seats.aero URL has correct host', () {
      final link = buildAwardLinks(origin: 'SFO', destination: 'NRT', date: date)
          .firstWhere((l) => l.engine == 'Seats.aero');
      expect(link.url.host, 'seats.aero');
    });

    test('PointsYeah URL has correct host', () {
      final link = buildAwardLinks(origin: 'SFO', destination: 'NRT', date: date)
          .firstWhere((l) => l.engine == 'PointsYeah');
      expect(link.url.host, 'www.pointsyeah.com');
    });

    test('Roame.travel URL has correct host', () {
      final link = buildAwardLinks(origin: 'SFO', destination: 'NRT', date: date)
          .firstWhere((l) => l.engine == 'Roame.travel');
      expect(link.url.host, 'roame.travel');
    });

    test('Seats.aero encodes origin in "origins" param', () {
      final link = buildAwardLinks(origin: 'SFO', destination: 'NRT', date: date)
          .firstWhere((l) => l.engine == 'Seats.aero');
      expect(link.url.queryParameters['origins'], 'SFO');
      expect(link.url.queryParameters['destinations'], 'NRT');
    });

    test('PointsYeah encodes origin in "departure" param', () {
      final link = buildAwardLinks(origin: 'SFO', destination: 'NRT', date: date)
          .firstWhere((l) => l.engine == 'PointsYeah');
      expect(link.url.queryParameters['departure'], 'SFO');
      expect(link.url.queryParameters['arrival'], 'NRT');
    });

    test('Roame encodes origin in "origin" param', () {
      final link = buildAwardLinks(origin: 'SFO', destination: 'NRT', date: date)
          .firstWhere((l) => l.engine == 'Roame.travel');
      expect(link.url.queryParameters['origin'], 'SFO');
      expect(link.url.queryParameters['destination'], 'NRT');
    });
  });

  // ---------------------------------------------------------------------------
  // HomeAirportNotifier
  // ---------------------------------------------------------------------------

  group('homeAirportProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // HomeAirportNotifier._load() is called from the constructor and is async.
    // We must drain the microtask queue with pumpEventQueue() before asserting
    // hydrated state.

    test('defaults to empty string before any pref is set', () async {
      final c = _container();
      // Trigger provider creation, then drain all pending microtasks so _load()
      // completes before we dispose.
      c.read(homeAirportProvider);
      await pumpEventQueue();
      expect(c.read(homeAirportProvider), '');
    });

    test('hydrates from seeded SharedPreferences value', () async {
      SharedPreferences.setMockInitialValues({'home_airport': 'SFO'});
      final c = _container();
      c.read(homeAirportProvider);
      await pumpEventQueue();
      expect(c.read(homeAirportProvider), 'SFO');
    });

    test('set() updates state immediately', () async {
      final c = _container();
      await c.read(homeAirportProvider.notifier).set('JFK');
      expect(c.read(homeAirportProvider), 'JFK');
    });

    test('set() normalises to uppercase', () async {
      final c = _container();
      await c.read(homeAirportProvider.notifier).set('lax');
      expect(c.read(homeAirportProvider), 'LAX');
    });

    test('set() trims whitespace before uppercasing', () async {
      final c = _container();
      await c.read(homeAirportProvider.notifier).set('  ord  ');
      expect(c.read(homeAirportProvider), 'ORD');
    });

    test('set() persists to SharedPreferences', () async {
      final c = _container();
      await c.read(homeAirportProvider.notifier).set('DEN');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('home_airport'), 'DEN');
    });

    test('set() can overwrite a previously stored value', () async {
      SharedPreferences.setMockInitialValues({'home_airport': 'SFO'});
      final c = _container();
      c.read(homeAirportProvider);
      await pumpEventQueue();

      await c.read(homeAirportProvider.notifier).set('BOS');
      expect(c.read(homeAirportProvider), 'BOS');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('home_airport'), 'BOS');
    });
  });

  // ---------------------------------------------------------------------------
  // LegAirportMemory — pure SharedPreferences helper (static, no notifier)
  // ---------------------------------------------------------------------------

  group('LegAirportMemory', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns (null, null) when nothing saved', () async {
      final (origin, dest) = await LegAirportMemory.load('leg1');
      expect(origin, isNull);
      expect(dest, isNull);
    });

    test('save then load round-trips origin and destination', () async {
      await LegAirportMemory.save('leg1', 'SFO', 'NRT');
      final (origin, dest) = await LegAirportMemory.load('leg1');
      expect(origin, 'SFO');
      expect(dest, 'NRT');
    });

    test('save normalises to uppercase', () async {
      await LegAirportMemory.save('leg2', 'sfo', 'lhr');
      final (origin, dest) = await LegAirportMemory.load('leg2');
      expect(origin, 'SFO');
      expect(dest, 'LHR');
    });

    test('different legIds are stored independently', () async {
      await LegAirportMemory.save('legA', 'SFO', 'NRT');
      await LegAirportMemory.save('legB', 'JFK', 'LHR');

      final (oA, dA) = await LegAirportMemory.load('legA');
      final (oB, dB) = await LegAirportMemory.load('legB');

      expect(oA, 'SFO');
      expect(dA, 'NRT');
      expect(oB, 'JFK');
      expect(dB, 'LHR');
    });

    test('save overwrites previous values for same legId', () async {
      await LegAirportMemory.save('leg1', 'SFO', 'NRT');
      await LegAirportMemory.save('leg1', 'LAX', 'CDG');
      final (origin, dest) = await LegAirportMemory.load('leg1');
      expect(origin, 'LAX');
      expect(dest, 'CDG');
    });
  });
}
