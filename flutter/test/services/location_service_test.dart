// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:wayfarer/services/location_service.dart';

// ---------------------------------------------------------------------------
// Fake geolocator platform — extend (not implement) to satisfy
// PlatformInterface.verify(); mix in MockPlatformInterfaceMixin so the token
// check is bypassed in test / debug mode.
// ---------------------------------------------------------------------------

class _FakeGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  bool serviceEnabled;
  LocationPermission permission;
  Position? currentPos;
  Position? lastKnownPos;
  bool throwOnCurrentPosition;
  bool throwOnLastKnown;

  _FakeGeolocatorPlatform({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.currentPos,
    this.lastKnownPos,
    this.throwOnCurrentPosition = false,
    this.throwOnLastKnown = false,
  });

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (throwOnCurrentPosition) throw Exception('GPS timeout');
    if (currentPos == null) throw Exception('No position');
    return currentPos!;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    if (throwOnLastKnown) throw Exception('No last known');
    return lastKnownPos;
  }
}

// Helper: create a dummy Position for assertions.
Position _fakePosition({double lat = 47.6, double lng = -122.3}) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 6, 14),
      accuracy: 10.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocationService sut;
  late _FakeGeolocatorPlatform fake;

  setUp(() {
    sut = LocationService();
  });

  tearDown(() {
    // Reset the platform instance so tests don't bleed into each other.
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform();
  });

  // -------------------------------------------------------------------------
  // currentPosition()
  // -------------------------------------------------------------------------

  group('currentPosition', () {
    test('returns position when service enabled and permission granted', () async {
      final pos = _fakePosition();
      fake = _FakeGeolocatorPlatform(currentPos: pos);
      GeolocatorPlatform.instance = fake;

      final result = await sut.currentPosition();

      expect(result, isNotNull);
      expect(result!.latitude, closeTo(47.6, 0.001));
      expect(result.longitude, closeTo(-122.3, 0.001));
    });

    test('returns null when location service is disabled', () async {
      fake = _FakeGeolocatorPlatform(serviceEnabled: false);
      GeolocatorPlatform.instance = fake;

      final result = await sut.currentPosition();

      expect(result, isNull);
    });

    test('returns null when permission is denied', () async {
      fake = _FakeGeolocatorPlatform(
        permission: LocationPermission.denied,
      );
      GeolocatorPlatform.instance = fake;

      final result = await sut.currentPosition();

      expect(result, isNull);
    });

    test('returns null when permission is deniedForever', () async {
      fake = _FakeGeolocatorPlatform(
        permission: LocationPermission.deniedForever,
      );
      GeolocatorPlatform.instance = fake;

      final result = await sut.currentPosition();

      expect(result, isNull);
    });

    test('falls back to last-known position when getCurrentPosition throws',
        () async {
      final lastKnown = _fakePosition(lat: 47.5, lng: -122.2);
      fake = _FakeGeolocatorPlatform(
        throwOnCurrentPosition: true,
        lastKnownPos: lastKnown,
      );
      GeolocatorPlatform.instance = fake;

      final result = await sut.currentPosition();

      expect(result, isNotNull);
      expect(result!.latitude, closeTo(47.5, 0.001));
    });

    test('returns null when both getCurrentPosition and getLastKnownPosition throw',
        () async {
      fake = _FakeGeolocatorPlatform(
        throwOnCurrentPosition: true,
        throwOnLastKnown: true,
      );
      GeolocatorPlatform.instance = fake;

      final result = await sut.currentPosition();

      expect(result, isNull);
    });

    test('returns null when fallback last-known is null', () async {
      fake = _FakeGeolocatorPlatform(
        throwOnCurrentPosition: true,
        lastKnownPos: null,
      );
      GeolocatorPlatform.instance = fake;

      final result = await sut.currentPosition();

      // getLastKnownPosition returns null (not a throw), so outer catch
      // doesn't fire — but null propagates correctly.
      expect(result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // requestPermission()
  // -------------------------------------------------------------------------

  group('requestPermission', () {
    test('returns true when platform grants whileInUse', () async {
      fake = _FakeGeolocatorPlatform(permission: LocationPermission.whileInUse);
      GeolocatorPlatform.instance = fake;

      expect(await sut.requestPermission(), isTrue);
    });

    test('returns true when platform grants always', () async {
      fake = _FakeGeolocatorPlatform(permission: LocationPermission.always);
      GeolocatorPlatform.instance = fake;

      expect(await sut.requestPermission(), isTrue);
    });

    test('returns false when permission remains denied', () async {
      fake = _FakeGeolocatorPlatform(permission: LocationPermission.denied);
      GeolocatorPlatform.instance = fake;

      // checkPermission returns denied → calls requestPermission on platform
      // which also returns denied
      expect(await sut.requestPermission(), isFalse);
    });

    test('returns false when permission is deniedForever (no request made)',
        () async {
      fake = _FakeGeolocatorPlatform(
        permission: LocationPermission.deniedForever,
      );
      GeolocatorPlatform.instance = fake;

      expect(await sut.requestPermission(), isFalse);
    });

    test('returns false when platform throws', () async {
      final throwingFake = _ThrowingGeolocatorPlatform();
      GeolocatorPlatform.instance = throwingFake;

      expect(await sut.requestPermission(), isFalse);
    });
  });
}

// A platform that always throws, to exercise the catch branch in requestPermission.
class _ThrowingGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<LocationPermission> checkPermission() async =>
      throw Exception('platform error');
}
