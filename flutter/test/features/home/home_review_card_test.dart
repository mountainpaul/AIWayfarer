import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/features/home/home_screen.dart';
import 'package:wayfarer/models/briefing.dart';
import 'package:wayfarer/models/trip.dart';
import 'package:wayfarer/providers/briefing_provider.dart';
import 'package:wayfarer/providers/review_provider.dart';
import 'package:wayfarer/providers/trip_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

void _tallSurface(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 4000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

/// Build the complete list of overrides for HomeScreen, with tripsNeedingReview
/// as the variable under test.
List<Override> _overrides({required List<Trip> tripsNeedingReview}) => [
      // tripsNeedingReviewProvider is the focal point of these tests.
      tripsNeedingReviewProvider.overrideWith(
          (ref) async => tripsNeedingReview),

      // Stub all other home providers so HomeScreen renders without network.
      briefingProvider.overrideWith((ref) async => const Briefing(
            id: 'b1',
            date: '2026-06-15',
            markdown: 'Morning briefing.',
          )),
      currentLegProvider.overrideWith((ref) async => null),
      nextBookingProvider.overrideWith((ref) async => null),
      openTaskCountProvider.overrideWith((ref) async => 0),
      schengenProvider.overrideWith((ref) async => null),
      coverageProvider.overrideWith((ref) async => null),
      budgetProvider.overrideWith((ref) async => null),
    ];

/// Minimal GoRouter stub: wraps the widget so context.go calls don't crash.
/// We don't test navigation — only rendering.
Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      // Use plain MaterialApp (no GoRouter), since the card only calls
      // context.go which requires a GoRouter. Wrap the onTap destination in a
      // try/catch-friendly way by using MaterialApp.router via a no-op router,
      // OR simply use Scaffold + HomeScreen and catch the GoRouter lookup error.
      //
      // The cleanest approach for rendering-only tests: use a NavigatorObserver
      // and accept that tapping the card will throw a LookupError that we don't
      // trigger. We only assert visibility, not navigation.
      child: const MaterialApp(
        home: Scaffold(body: HomeScreen()),
      ),
    );

const _kCompletedTrip = Trip(
  id: 'trip-done',
  name: 'Japan 2025',
  startDate: '2025-09-01',
  endDate: '2025-09-30',
  status: 'completed',
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('_ReviewPromptCard visibility', () {
    testWidgets(
        'shows "How was <name>?" card when tripsNeedingReview returns a trip',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides(
        tripsNeedingReview: const [_kCompletedTrip],
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('How was Japan 2025?'), findsOneWidget);
      expect(
        find.textContaining('quick review'),
        findsOneWidget,
      );
    });

    testWidgets('card is absent when tripsNeedingReview returns empty list',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides(
        tripsNeedingReview: const [],
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('How was'), findsNothing);
    });

    testWidgets('shows the first trip name when multiple trips need review',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app(_overrides(
        tripsNeedingReview: const [
          _kCompletedTrip,
          Trip(
            id: 'trip-done-2',
            name: 'Italy 2024',
            startDate: '2024-05-01',
            endDate: '2024-05-20',
            status: 'completed',
          ),
        ],
      )));
      await tester.pumpAndSettle();

      // Only the first is displayed.
      expect(find.textContaining('How was Japan 2025?'), findsOneWidget);
      expect(find.textContaining('How was Italy 2024?'), findsNothing);
    });

    testWidgets(
        'card is absent while tripsNeedingReviewProvider is still loading',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          tripsNeedingReviewProvider
              .overrideWith((ref) => Future.delayed(const Duration(hours: 1))),
          briefingProvider.overrideWith((ref) async => null),
          currentLegProvider.overrideWith((ref) async => null),
          nextBookingProvider.overrideWith((ref) async => null),
          openTaskCountProvider.overrideWith((ref) async => 0),
          schengenProvider.overrideWith((ref) async => null),
          coverageProvider.overrideWith((ref) async => null),
          budgetProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: Scaffold(body: HomeScreen()),
        ),
      ));
      // One pump only — don't settle; providers are still pending.
      await tester.pump();

      expect(find.textContaining('How was'), findsNothing);
    });

    testWidgets('card is absent when tripsNeedingReviewProvider errors',
        (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          tripsNeedingReviewProvider
              .overrideWith((ref) => Future.error('boom')),
          briefingProvider.overrideWith((ref) async => null),
          currentLegProvider.overrideWith((ref) async => null),
          nextBookingProvider.overrideWith((ref) async => null),
          openTaskCountProvider.overrideWith((ref) async => 0),
          schengenProvider.overrideWith((ref) async => null),
          coverageProvider.overrideWith((ref) async => null),
          budgetProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: Scaffold(body: HomeScreen()),
        ),
      ));
      // Suppress the unhandled error from the provider error.
      final errors = <Object>[];
      FlutterError.onError = (details) => errors.add(details.exception);
      await tester.pumpAndSettle();
      FlutterError.onError = FlutterError.presentError;

      expect(find.textContaining('How was'), findsNothing);
    });
  });
}
