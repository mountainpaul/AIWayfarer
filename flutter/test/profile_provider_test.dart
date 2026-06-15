import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/traveler_profile.dart';
import 'package:wayfarer/providers/profile_provider.dart';
import 'package:wayfarer/services/api_client.dart';

/// Fake ApiClient: overrides only the profile endpoints. The real super
/// constructor builds a Dio but makes no network call until a method runs.
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');

  TravelerProfile profile =
      const TravelerProfile(id: '1', userId: 'paul');
  Object? throwOnGet;
  Map<String, dynamic>? lastPatch;
  bool throwOnPatch = false;

  @override
  Future<TravelerProfile> getProfile() async {
    if (throwOnGet != null) throw throwOnGet!;
    return profile;
  }

  @override
  Future<TravelerProfile> patchProfile(Map<String, dynamic> patch) async {
    if (throwOnPatch) throw Exception('server rejected');
    lastPatch = patch;
    profile = profile.copyWith(
      lodgingStyle: patch['lodging_style'] as String? ?? profile.lodgingStyle,
    );
    return profile;
  }
}

ProviderContainer _container(_FakeApi api) {
  final c = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(api)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('profileProvider', () {
    test('returns the fetched profile', () async {
      final api = _FakeApi()
        ..profile = const TravelerProfile(
            id: '1', userId: 'paul', lodgingStyle: 'boutique');
      final c = _container(api);

      final p = await c.read(profileProvider.future);
      expect(p?.lodgingStyle, 'boutique');
    });

    test('returns null when the backend is unreachable', () async {
      final api = _FakeApi()..throwOnGet = ApiUnreachable('down');
      final c = _container(api);

      expect(await c.read(profileProvider.future), isNull);
    });
  });

  group('ProfileMutations.update', () {
    test('patches and bumps the refresh trigger', () async {
      final api = _FakeApi();
      final c = _container(api);
      final before = c.read(profileRefreshProvider);

      final ok = await c
          .read(profileMutationsProvider)
          .update({'lodging_style': 'luxury'});

      expect(ok, isTrue);
      expect(api.lastPatch, {'lodging_style': 'luxury'});
      expect(c.read(profileRefreshProvider), before + 1); // forces refetch
    });

    test('returns false and does not bump on failure', () async {
      final api = _FakeApi()..throwOnPatch = true;
      final c = _container(api);
      final before = c.read(profileRefreshProvider);

      final ok =
          await c.read(profileMutationsProvider).update({'travel_pace': 'packed'});

      expect(ok, isFalse);
      expect(c.read(profileRefreshProvider), before); // unchanged
    });
  });
}
