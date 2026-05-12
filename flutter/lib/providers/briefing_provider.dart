import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/briefing.dart';
import '../services/api_client.dart';
import '../services/local_db.dart';

final briefingProvider = FutureProvider<Briefing?>((ref) async {
  // Try backend first; fall back to local cache when offline.
  try {
    final fresh = await ref.read(apiClientProvider).getTodayBriefing();
    if (fresh != null) {
      await ref.read(localDbProvider).upsertBriefing(fresh);
      return fresh;
    }
  } catch (_) {
    // network/offline: fall through to local
  }
  return ref.read(localDbProvider).latestBriefing();
});
