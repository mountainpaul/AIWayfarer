import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking.dart';
import '../models/grounding.dart';
import '../models/leg.dart';
import 'local_db.dart';
import 'location_service.dart';

/// Composes the grounding payload (§4) from local Trip HQ state + GPS + clock.
/// The backend may augment this with calendar data; we send what the device knows.
class GroundingService {
  GroundingService({
    required LocalDb db,
    required LocationService location,
  })  : _db = db,
        _location = location;

  final LocalDb _db;
  final LocationService _location;

  Future<Grounding> compose() async {
    final pos = await _location.currentPosition();
    final now = DateTime.now();
    final legs = await _db.legs();
    final today = DateTime(now.year, now.month, now.day);
    Leg? current;
    for (final l in legs) {
      if (l.containsDate(today)) {
        current = l;
        break;
      }
    }

    String? nextBookingId;
    if (current != null) {
      final bookings = await _db.bookings(legId: current.id);
      Booking? next;
      for (final b in bookings) {
        final start = b.startDateTime;
        if (start != null && start.isAfter(now)) {
          if (next == null || start.isBefore(next.startDateTime!)) {
            next = b;
          }
        }
      }
      nextBookingId = next?.id;
    }

    return Grounding(
      gpsLat: pos?.latitude,
      gpsLon: pos?.longitude,
      gpsAccuracyM: pos?.accuracy,
      localTimeIso: now.toIso8601String(),
      timezone: now.timeZoneName,
      currentLegId: current?.id,
      currentLegSlug: current?.slug,
      currentTripId: current?.tripId,
      nextBookingId: nextBookingId,
    );
  }
}

final groundingServiceProvider = Provider<GroundingService>((ref) {
  return GroundingService(
    db: ref.watch(localDbProvider),
    location: ref.watch(locationServiceProvider),
  );
});
