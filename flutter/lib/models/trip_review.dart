import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip_review.freezed.dart';
part 'trip_review.g.dart';

/// One rated item within a post-trip review, linked to the actual leg/booking
/// it rates so the feedback is specific (not vague).
@freezed
class ReviewItem with _$ReviewItem {
  const factory ReviewItem({
    required String id,
    @JsonKey(name: 'review_id') required String reviewId,
    @JsonKey(name: 'leg_id') String? legId,
    @JsonKey(name: 'booking_id') String? bookingId,
    @JsonKey(name: 'subject_type') required String subjectType,
    @JsonKey(name: 'subject_label') required String subjectLabel,
    int? rating,
    String? liked,
    String? disliked,
  }) = _ReviewItem;

  factory ReviewItem.fromJson(Map<String, dynamic> json) =>
      _$ReviewItemFromJson(json);
}

/// A post-trip review. One per trip; submitting it distills the traveler
/// profile summary on the backend.
@freezed
class TripReview with _$TripReview {
  const factory TripReview({
    required String id,
    @JsonKey(name: 'trip_id') required String tripId,
    @JsonKey(name: 'overall_rating') int? overallRating,
    @JsonKey(name: 'pace_feedback') String? paceFeedback,
    String? highlight,
    String? lowlight,
    @JsonKey(name: 'free_text') String? freeText,
    @Default(<ReviewItem>[]) List<ReviewItem> items,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _TripReview;

  factory TripReview.fromJson(Map<String, dynamic> json) =>
      _$TripReviewFromJson(json);
}
