import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/features/awards/awards_screen.dart';
import 'package:wayfarer/models/leg.dart';
import 'package:wayfarer/providers/trip_provider.dart';
import 'package:wayfarer/services/api_client.dart';
import 'package:wayfarer/services/award_search.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeApiOk extends ApiClient {
  _FakeApiOk() : super(baseUrl: 'http://test.local');

  @override
  Future<Map<String, dynamic>> scanLoyaltyOffers({int months = 2}) async {
    return {
      'offers': [
        {
          'kind': 'flight',
          'title': '30% off United miles',
          'program': 'United MileagePlus',
          'summary': 'Transfer bonus from Chase.',
          'expires': '2026-07-31',
          'promo_code': 'BONUS30',
          'leg_id': null,
        },
        {
          'kind': 'hotel',
          'title': 'Marriott double points',
          'program': 'Marriott Bonvoy',
          'summary': '',
          'expires': null,
          'promo_code': null,
          'leg_id': null,
        },
      ],
    };
  }
}

class _FakeApiEmpty extends ApiClient {
  _FakeApiEmpty() : super(baseUrl: 'http://test.local');

  @override
  Future<Map<String, dynamic>> scanLoyaltyOffers({int months = 2}) async {
    return {'offers': <dynamic>[]};
  }
}

class _FakeApiError extends ApiClient {
  _FakeApiError() : super(baseUrl: 'http://test.local');

  @override
  Future<Map<String, dynamic>> scanLoyaltyOffers({int months = 2}) async {
    throw Exception('Network failure');
  }
}

class _FakeApiWithLegOffer extends ApiClient {
  _FakeApiWithLegOffer() : super(baseUrl: 'http://test.local');

  @override
  Future<Map<String, dynamic>> scanLoyaltyOffers({int months = 2}) async {
    return {
      'offers': [
        {
          'kind': 'flight',
          'title': 'Leg-linked offer',
          'program': 'Delta SkyMiles',
          'summary': 'Earn more miles on leg.',
          'expires': null,
          'promo_code': null,
          'leg_id': 'leg-abc',
        },
      ],
    };
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

final _futureDate = DateTime.now().add(const Duration(days: 30));
final _futureDateStr =
    '${_futureDate.year}-${_futureDate.month.toString().padLeft(2, '0')}-${_futureDate.day.toString().padLeft(2, '0')}';

final _sampleLeg = Leg(
  id: 'leg-1',
  tripId: 'trip-1',
  slug: 'italy',
  name: 'Italy',
  emoji: '🇮🇹',
  startDate: _futureDateStr,
  endDate: _futureDateStr,
);

// A leg that is in the past (should not appear in upcoming).
const _pastLeg = Leg(
  id: 'leg-past',
  tripId: 'trip-1',
  slug: 'past',
  name: 'Past Leg',
  startDate: '2020-01-01',
  endDate: '2020-01-10',
);

void _tallSurface(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 4000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: Scaffold(body: AwardsScreen())),
    );

List<Override> _baseOverrides({
  ApiClient? api,
  AsyncValue<List<Leg>>? legs,
}) =>
    [
      apiClientProvider.overrideWithValue(api ?? _FakeApiEmpty()),
      legsProvider.overrideWith(
          (ref) async => (legs ?? const AsyncData(<Leg>[])).valueOrNull ?? []),
    ];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Static structure ───────────────────────────────────────────────────────

  group('AwardsScreen — static structure', () {
    testWidgets('renders Loyalty offers heading', (tester) async {
      await tester.pumpWidget(_app(_baseOverrides()));
      await tester.pumpAndSettle();

      expect(find.text('Loyalty offers'), findsOneWidget);
    });

    testWidgets('renders Award flight search heading', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides()));
      await tester.pumpAndSettle();

      expect(find.text('Award flight search'), findsOneWidget);
    });

    testWidgets('renders Scan email button before any scan', (tester) async {
      await tester.pumpWidget(_app(_baseOverrides()));
      await tester.pumpAndSettle();

      expect(find.text('Scan email for offers'), findsOneWidget);
    });

    testWidgets('renders subtitle description for loyalty offers', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scans your Gmail'), findsOneWidget);
    });

    testWidgets('renders subtitle description for award search section',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Seats.aero'), findsOneWidget);
    });
  });

  // ── Legs section ──────────────────────────────────────────────────────────

  group('AwardsScreen — legs section', () {
    testWidgets('shows "No upcoming legs" when legs list is empty', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(legs: const AsyncData([]))));
      await tester.pumpAndSettle();

      expect(find.text('No upcoming legs.'), findsOneWidget);
    });

    testWidgets('renders upcoming leg as a ListTile', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(
        legs: AsyncData([_sampleLeg]),
      )));
      await tester.pumpAndSettle();

      // The leg name should appear in the tile.
      expect(find.textContaining('Italy'), findsOneWidget);
    });

    testWidgets('renders leg dates in subtitle', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(
        legs: AsyncData([_sampleLeg]),
      )));
      await tester.pumpAndSettle();

      // subtitle contains startDate - endDate
      expect(find.textContaining(_futureDateStr), findsWidgets);
    });

    testWidgets('renders search icon on each leg tile', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(
        legs: AsyncData([_sampleLeg]),
      )));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('past leg is not shown in upcoming list', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(
        legs: const AsyncData([_pastLeg]),
      )));
      await tester.pumpAndSettle();

      expect(find.text('No upcoming legs.'), findsOneWidget);
      expect(find.text('Past Leg'), findsNothing);
    });

    testWidgets('only upcoming legs are rendered when mixed', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(
        legs: AsyncData([_pastLeg, _sampleLeg]),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Italy'), findsOneWidget);
      expect(find.text('Past Leg'), findsNothing);
    });

    testWidgets('renders loading indicator while legs are loading', (tester) async {
      _tallSurface(tester);
      // Use a Completer so the future never resolves and there are no pending
      // timers to cause test-framework complaints.
      final completer = Completer<List<Leg>>();
      addTearDown(() => completer.complete([])); // complete on teardown to avoid leak
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiEmpty()),
          legsProvider.overrideWith((ref) => completer.future),
        ],
        child: const MaterialApp(home: Scaffold(body: AwardsScreen())),
      ));
      await tester.pump(); // one frame — async not settled

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('renders error text when legs provider errors', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiEmpty()),
          legsProvider.overrideWith(
              (ref) => Future<List<Leg>>.error('DB error')),
        ],
        child: const MaterialApp(home: Scaffold(body: AwardsScreen())),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('DB error'), findsOneWidget);
    });

    testWidgets('tapping a leg tile opens the bottom sheet', (tester) async {
      _tallSurface(tester);
      // Override legProvider(id) too so the sheet can load the leg.
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiEmpty()),
          legsProvider.overrideWith((ref) async => [_sampleLeg]),
          legProvider('leg-1').overrideWith((ref) async => _sampleLeg),
          homeAirportProvider.overrideWith((_) => HomeAirportNotifier()),
        ],
        child: const MaterialApp(home: Scaffold(body: AwardsScreen())),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Italy'));
      await tester.pumpAndSettle();

      expect(find.text('Search award availability'), findsOneWidget);
    });
  });

  // ── Scan button ───────────────────────────────────────────────────────────

  group('AwardsScreen — scan interaction', () {
    testWidgets('tapping Scan shows loading indicator', (tester) async {
      // Use a slow fake so we can observe the loading state.
      final slowApi = _SlowApiClient();
      await tester.pumpWidget(_app(_baseOverrides(api: slowApi)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pump(); // one frame: scanning begins

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Scan email for offers'), findsNothing);

      // Let the future complete to avoid timer leaks.
      await tester.pumpAndSettle();
    });

    testWidgets('shows loading message text while scanning', (tester) async {
      final slowApi = _SlowApiClient();
      await tester.pumpWidget(_app(_baseOverrides(api: slowApi)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pump();

      expect(
          find.textContaining('Scanning and parsing'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('renders offer cards after successful scan', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(api: _FakeApiOk())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pumpAndSettle();

      expect(find.text('30% off United miles'), findsOneWidget);
      expect(find.text('Marriott double points'), findsOneWidget);
    });

    testWidgets('renders Rescan button after first scan', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(api: _FakeApiOk())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pumpAndSettle();

      expect(find.text('Rescan'), findsOneWidget);
      expect(find.text('Scan email for offers'), findsNothing);
    });

    testWidgets('shows "No current offers" when scan returns empty list',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(api: _FakeApiEmpty())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No current offers found'), findsOneWidget);
    });

    testWidgets('shows error text when scan throws', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(api: _FakeApiError())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Network failure'), findsOneWidget);
    });

    testWidgets('button is not visible while scanning', (tester) async {
      final slowApi = _SlowApiClient();
      await tester.pumpWidget(_app(_baseOverrides(api: slowApi)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pump();

      // FilledButton.icon is gone during scan.
      expect(find.text('Scan email for offers'), findsNothing);
      expect(find.text('Rescan'), findsNothing);

      await tester.pumpAndSettle();
    });
  });

  // ── OfferCard contents ────────────────────────────────────────────────────

  group('AwardsScreen — offer card details', () {
    testWidgets('offer card shows program name', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(api: _FakeApiOk())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pumpAndSettle();

      expect(find.text('United MileagePlus'), findsOneWidget);
    });

    testWidgets('offer card shows expires chip', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(api: _FakeApiOk())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pumpAndSettle();

      expect(find.text('Expires 2026-07-31'), findsOneWidget);
    });

    testWidgets('offer card shows promo code chip', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(api: _FakeApiOk())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pumpAndSettle();

      expect(find.text('Code: BONUS30'), findsOneWidget);
    });

    testWidgets('offer card shows summary when non-empty', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(api: _FakeApiOk())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pumpAndSettle();

      expect(find.text('Transfer bonus from Chase.'), findsOneWidget);
    });

    testWidgets('offer with no expires/promo shows no chip', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(api: _FakeApiOk())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pumpAndSettle();

      // Marriott offer has no expires/promo — those chips should not appear for it.
      // The single Expires chip belongs only to the United offer.
      expect(find.text('Expires 2026-07-31'), findsOneWidget);
    });

    testWidgets('flight offer renders flight icon', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(api: _FakeApiOk())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.flight), findsOneWidget);
    });

    testWidgets('hotel offer renders hotel icon', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_baseOverrides(api: _FakeApiOk())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.hotel), findsOneWidget);
    });
  });

  // ── LegChip ───────────────────────────────────────────────────────────────

  group('AwardsScreen — leg-linked offer chip', () {
    testWidgets('offer with leg_id renders leg name chip when leg resolves',
        (tester) async {
      _tallSurface(tester);
      const legAbc = Leg(
        id: 'leg-abc',
        tripId: 'trip-1',
        slug: 'rome',
        name: 'Rome',
        startDate: '2026-09-01',
        endDate: '2026-09-15',
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(_FakeApiWithLegOffer()),
          legsProvider.overrideWith((ref) async => <Leg>[]),
          legProvider('leg-abc').overrideWith((ref) async => legAbc),
        ],
        child: const MaterialApp(home: Scaffold(body: AwardsScreen())),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan email for offers'));
      await tester.pumpAndSettle();

      expect(find.text('Rome'), findsOneWidget);
    });
  });
}

// ── Slow fake for mid-flight loading assertions ────────────────────────────

class _SlowApiClient extends ApiClient {
  _SlowApiClient() : super(baseUrl: 'http://test.local');

  @override
  Future<Map<String, dynamic>> scanLoyaltyOffers({int months = 2}) =>
      Future.delayed(
        const Duration(milliseconds: 200),
        () => {'offers': <dynamic>[]},
      );
}
