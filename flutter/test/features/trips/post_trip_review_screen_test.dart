import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/trips/post_trip_review_screen.dart';
import 'package:wayfarer/models/trip_review.dart';
import 'package:wayfarer/providers/review_provider.dart';
import 'package:wayfarer/services/api_client.dart';

// ── Fake ApiClient ────────────────────────────────────────────────────────────

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');

  Map<String, dynamic>? lastPayload;
  bool throwOnCreate = false;

  @override
  Future<TripReview> createReview(Map<String, dynamic> body) async {
    if (throwOnCreate) throw Exception('backend unreachable');
    lastPayload = body;
    return TripReview(id: 'rev-new', tripId: body['trip_id'] as String? ?? 'trip-x');
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _kTripId = 'trip-test';

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: PostTripReviewScreen(tripId: _kTripId),
      ),
    );

List<ReviewableItem> _twoItems() => const [
      ReviewableItem(
        subjectType: 'stay',
        subjectLabel: 'Hotel Roma',
        bookingId: 'bk-1',
        legId: 'leg-1',
      ),
      ReviewableItem(
        subjectType: 'transport',
        subjectLabel: 'Air France 007',
        bookingId: 'bk-2',
        legId: 'leg-1',
      ),
    ];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Renders correctly ──────────────────────────────────────────────────────

  group('PostTripReviewScreen rendering', () {
    testWidgets('renders Overall, Pace and Highlight sections', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app([
        reviewableItemsProvider(_kTripId)
            .overrideWith((ref) async => _twoItems()),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Overall'), findsOneWidget);
      expect(find.text('Pace'), findsOneWidget);
      expect(find.text('Highlight'), findsOneWidget);
    });

    testWidgets('renders a card per reviewable item', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app([
        reviewableItemsProvider(_kTripId)
            .overrideWith((ref) async => _twoItems()),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Hotel Roma'), findsOneWidget);
      expect(find.text('Air France 007'), findsOneWidget);
      expect(find.text('stay'), findsOneWidget);
      expect(find.text('transport'), findsOneWidget);
    });

    testWidgets('shows empty-items notice when reviewables is empty', (tester) async {
      _tallSurface(tester);
      await tester.pumpWidget(_app([
        reviewableItemsProvider(_kTripId)
            .overrideWith((ref) async => const []),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('No bookings on this trip to rate.'), findsOneWidget);
      expect(find.text('Submit review'), findsOneWidget);
    });
  });

  // ── Successful submission ──────────────────────────────────────────────────

  group('PostTripReviewScreen submission', () {
    testWidgets(
        'sets overall_rating, highlight, item rating; '
        'submit shows "Review saved" snackbar and payload is correct',
        (tester) async {
      _tallSurface(tester);
      final api = _FakeApi();
      await tester.pumpWidget(_app([
        reviewableItemsProvider(_kTripId)
            .overrideWith((ref) async => _twoItems()),
        apiClientProvider.overrideWithValue(api),
      ]));
      await tester.pumpAndSettle();

      // Tap the 4th star in the Overall _Stars widget (first row of stars).
      // Stars are IconButtons; the first 5 belong to Overall (indices 0-4),
      // next 5 to the first item (indices 5-9), etc.
      final starButtons = find.byType(IconButton);
      // First five IconButtons are the Overall stars.
      await tester.tap(starButtons.at(3)); // 4th star → rating 4
      await tester.pump();

      // Enter a highlight.
      await tester.enterText(
        find.widgetWithText(TextField, 'The best part of the trip'),
        'Sunset in Santorini',
      );
      await tester.pump();

      // Rate the first item (Hotel Roma) with 3 stars.
      // Stars for first item start at index 5 (after the 5 Overall stars).
      await tester.tap(starButtons.at(7)); // 3rd star of the first item
      await tester.pump();

      // Tap Submit.
      await tester.tap(find.text('Submit review'));
      // Pump once to let the async _submit start; pumpAndSettle would finish
      // the pop animation and remove the scaffold before we can inspect the
      // snackbar. Pump a few frames instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // SnackBar should appear.
      expect(find.text('Review saved — thanks!'), findsOneWidget);

      // Assert payload.
      expect(api.lastPayload, isNotNull);
      expect(api.lastPayload!['trip_id'], _kTripId);
      expect(api.lastPayload!['overall_rating'], 4);
      expect(api.lastPayload!['highlight'], 'Sunset in Santorini');

      final items = api.lastPayload!['items'] as List<dynamic>;
      final hotelItems = items
          .cast<Map<String, dynamic>>()
          .where((i) => i['booking_id'] == 'bk-1')
          .toList();
      expect(hotelItems, hasLength(1));
      expect(hotelItems.first['rating'], 3);
    });

    testWidgets('submitting with empty reviewables still works', (tester) async {
      _tallSurface(tester);
      final api = _FakeApi();
      await tester.pumpWidget(_app([
        reviewableItemsProvider(_kTripId)
            .overrideWith((ref) async => const []),
        apiClientProvider.overrideWithValue(api),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit review'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Review saved — thanks!'), findsOneWidget);
      expect(api.lastPayload!['trip_id'], _kTripId);
      expect((api.lastPayload!['items'] as List<dynamic>), isEmpty);
    });
  });

  // ── Submission failure ─────────────────────────────────────────────────────

  group('PostTripReviewScreen failure', () {
    testWidgets('shows "Could not save" snackbar when createReview throws',
        (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()..throwOnCreate = true;
      await tester.pumpWidget(_app([
        reviewableItemsProvider(_kTripId)
            .overrideWith((ref) async => const []),
        apiClientProvider.overrideWithValue(api),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit review'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not save'),
        findsOneWidget,
      );
    });
  });
}
