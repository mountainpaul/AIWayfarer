import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip.dart';
import '../models/trip_review.dart';
import '../services/api_client.dart';
import '../services/local_db.dart';
import 'trip_provider.dart';

/// Bumped after a review is submitted so dependent providers refetch.
final reviewRefreshProvider = StateProvider<int>((_) => 0);

/// The review for a trip (or null if none / offline).
final reviewForTripProvider =
    FutureProvider.family<TripReview?, String>((ref, tripId) async {
  ref.watch(reviewRefreshProvider);
  try {
    return await ref.read(apiClientProvider).getReview(tripId);
  } catch (_) {
    return null;
  }
});

/// Completed trips that have not been reviewed yet — drives the Home prompt.
final tripsNeedingReviewProvider = FutureProvider<List<Trip>>((ref) async {
  ref.watch(reviewRefreshProvider);
  final trips = await ref.watch(tripsProvider.future);
  final completed = trips.where((t) => t.status == 'completed').toList();
  if (completed.isEmpty) return const [];
  var reviewed = <String>{};
  try {
    final existing = await ref.read(apiClientProvider).listReviews();
    reviewed = existing.map((r) => r.tripId).toSet();
  } catch (_) {
    // Offline: can't tell what's reviewed — show nothing rather than nag wrongly.
    return const [];
  }
  return completed.where((t) => !reviewed.contains(t.id)).toList();
});

/// A booking (or leg) that can be rated in the review, pre-built from the
/// trip's actual data so rating is tap-fast.
class ReviewableItem {
  const ReviewableItem({
    required this.subjectType,
    required this.subjectLabel,
    this.bookingId,
    this.legId,
  });

  final String subjectType;
  final String subjectLabel;
  final String? bookingId;
  final String? legId;
}

String _subjectForBooking(String bookingType) {
  switch (bookingType) {
    case 'hotel':
    case 'rifugio':
      return 'stay';
    case 'flight':
    case 'ferry':
    case 'car':
    case 'train':
      return 'transport';
    case 'activity':
      return 'activity';
    default:
      return 'other';
  }
}

/// The rateable items for a trip: every booking across its legs, mapped to a
/// review subject type. Read from the local cache.
final reviewableItemsProvider =
    FutureProvider.family<List<ReviewableItem>, String>((ref, tripId) async {
  ref.watch(syncTriggerProvider);
  final LocalDb db = ref.read(localDbProvider);
  final legs = await db.legs(tripId: tripId);
  final out = <ReviewableItem>[];
  for (final leg in legs) {
    final bookings = await db.bookings(legId: leg.id);
    for (final b in bookings) {
      out.add(ReviewableItem(
        subjectType: _subjectForBooking(b.type),
        subjectLabel: b.name,
        bookingId: b.id,
        legId: leg.id,
      ));
    }
  }
  return out;
});

class ReviewMutations {
  ReviewMutations(this.ref);
  final Ref ref;

  /// Submit a review payload. Returns false on offline / server rejection
  /// (incl. 409 if already reviewed).
  Future<bool> submit(Map<String, dynamic> payload) async {
    try {
      await ref.read(apiClientProvider).createReview(payload);
      ref.read(reviewRefreshProvider.notifier).state++;
      return true;
    } catch (_) {
      return false;
    }
  }
}

final reviewMutationsProvider =
    Provider<ReviewMutations>((ref) => ReviewMutations(ref));
