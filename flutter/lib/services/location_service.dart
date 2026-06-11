import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> currentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        // Don't request here — this runs on every chat send, and popping the
        // OS permission dialog mid-send is jarring. Request in onboarding.
        return null;
      }

      // A GPS fix indoors can take forever; chat sends await this, so cap it
      // and fall back to the last known position.
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// One-time permission request — call from onboarding/settings, not send paths.
  Future<bool> requestPermission() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      return perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }
}

final locationServiceProvider =
    Provider<LocationService>((_) => LocationService());
