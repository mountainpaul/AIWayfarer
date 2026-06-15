import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/traveler_profile.dart';
import '../services/api_client.dart';

/// Bumped after a save so [profileProvider] refetches.
final profileRefreshProvider = StateProvider<int>((_) => 0);

/// The traveler profile, fetched live from the backend (GET auto-creates it).
/// Null when the backend is unreachable — mirrors the server-computed providers
/// (schengen/coverage/budget): the screen shows an offline notice rather than
/// pretending to have data. The profile is edited in planning mode (online), so
/// it deliberately skips the offline outbox the trip data uses.
final profileProvider = FutureProvider<TravelerProfile?>((ref) async {
  ref.watch(profileRefreshProvider);
  try {
    return await ref.read(apiClientProvider).getProfile();
  } catch (_) {
    return null;
  }
});

class ProfileMutations {
  ProfileMutations(this.ref);
  final Ref ref;

  /// Patch the singleton profile, then refetch. Returns false on any failure
  /// (offline or server rejection) so the screen can surface it.
  Future<bool> update(Map<String, dynamic> patch) async {
    try {
      await ref.read(apiClientProvider).patchProfile(patch);
      ref.read(profileRefreshProvider.notifier).state++;
      return true;
    } catch (_) {
      return false;
    }
  }
}

final profileMutationsProvider =
    Provider<ProfileMutations>((ref) => ProfileMutations(ref));
