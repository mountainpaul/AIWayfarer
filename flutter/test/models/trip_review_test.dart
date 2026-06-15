import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/trip_review.dart';

void main() {
  group('ReviewItem.fromJson', () {
    test('maps all snake_case fields correctly', () {
      final item = ReviewItem.fromJson({
        'id': 'ri-1',
        'review_id': 'rev-1',
        'leg_id': 'leg-1',
        'booking_id': 'bk-1',
        'subject_type': 'stay',
        'subject_label': 'Hotel du Louvre',
        'rating': 4,
        'liked': 'Great location',
        'disliked': 'Small room',
      });

      expect(item.id, 'ri-1');
      expect(item.reviewId, 'rev-1');
      expect(item.legId, 'leg-1');
      expect(item.bookingId, 'bk-1');
      expect(item.subjectType, 'stay');
      expect(item.subjectLabel, 'Hotel du Louvre');
      expect(item.rating, 4);
      expect(item.liked, 'Great location');
      expect(item.disliked, 'Small room');
    });

    test('nullable fields are null when omitted', () {
      final item = ReviewItem.fromJson({
        'id': 'ri-2',
        'review_id': 'rev-1',
        'subject_type': 'transport',
        'subject_label': 'Air France 007',
      });

      expect(item.legId, isNull);
      expect(item.bookingId, isNull);
      expect(item.rating, isNull);
      expect(item.liked, isNull);
      expect(item.disliked, isNull);
    });

    test('rating 0 is preserved as-is', () {
      final item = ReviewItem.fromJson({
        'id': 'ri-3',
        'review_id': 'rev-1',
        'subject_type': 'activity',
        'subject_label': 'City tour',
        'rating': 0,
      });

      expect(item.rating, 0);
    });
  });

  group('TripReview.fromJson', () {
    test('maps all snake_case fields correctly', () {
      final review = TripReview.fromJson({
        'id': 'rev-1',
        'trip_id': 'trip-1',
        'overall_rating': 5,
        'pace_feedback': 'just_right',
        'highlight': 'The Louvre was incredible',
        'lowlight': 'Too much rain',
        'free_text': 'Would go back in summer',
        'created_at': '2026-06-01T10:00:00Z',
        'updated_at': '2026-06-01T10:00:00Z',
        'items': [],
      });

      expect(review.id, 'rev-1');
      expect(review.tripId, 'trip-1');
      expect(review.overallRating, 5);
      expect(review.paceFeedback, 'just_right');
      expect(review.highlight, 'The Louvre was incredible');
      expect(review.lowlight, 'Too much rain');
      expect(review.freeText, 'Would go back in summer');
      expect(review.createdAt, '2026-06-01T10:00:00Z');
      expect(review.updatedAt, '2026-06-01T10:00:00Z');
      expect(review.items, isEmpty);
    });

    test('optional fields default correctly when keys are omitted', () {
      final review = TripReview.fromJson({
        'id': 'rev-2',
        'trip_id': 'trip-2',
      });

      expect(review.overallRating, isNull);
      expect(review.paceFeedback, isNull);
      expect(review.highlight, isNull);
      expect(review.lowlight, isNull);
      expect(review.freeText, isNull);
      expect(review.createdAt, isNull);
      expect(review.updatedAt, isNull);
      expect(review.items, isEmpty); // @Default(<ReviewItem>[])
    });

    test('parses nested items list', () {
      final review = TripReview.fromJson({
        'id': 'rev-3',
        'trip_id': 'trip-3',
        'items': [
          {
            'id': 'ri-1',
            'review_id': 'rev-3',
            'subject_type': 'stay',
            'subject_label': 'Hostel Barcelona',
            'rating': 3,
          },
          {
            'id': 'ri-2',
            'review_id': 'rev-3',
            'leg_id': 'leg-1',
            'booking_id': 'bk-99',
            'subject_type': 'transport',
            'subject_label': 'Ryanair FR1234',
            'rating': 2,
            'disliked': 'Delays',
          },
        ],
      });

      expect(review.items, hasLength(2));
      expect(review.items[0].subjectType, 'stay');
      expect(review.items[0].subjectLabel, 'Hostel Barcelona');
      expect(review.items[1].bookingId, 'bk-99');
      expect(review.items[1].disliked, 'Delays');
    });

    test('toJson / fromJson round-trip is lossless (scalar fields)', () {
      // Note: items are stored as List<ReviewItem> in the generated toJson
      // (not converted to Map), so a round-trip with non-empty items requires
      // manually converting them. Test scalar fields here; items are covered by
      // the nested-items parse test above.
      const review = TripReview(
        id: 'rev-rt',
        tripId: 'trip-rt',
        overallRating: 4,
        paceFeedback: 'just_right',
        highlight: 'Mountains',
      );

      final json = review.toJson();
      final review2 = TripReview.fromJson(json);

      expect(review2.id, review.id);
      expect(review2.tripId, review.tripId);
      expect(review2.overallRating, review.overallRating);
      expect(review2.paceFeedback, review.paceFeedback);
      expect(review2.highlight, review.highlight);
    });
  });
}
