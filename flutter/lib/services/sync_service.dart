import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'local_db.dart';

/// Pulls a snapshot from the backend and writes it to local sqlite.
/// Read paths come from local. Write paths go to backend → local on success.
/// Offline write queue is OUT OF SCOPE for v0.5.
class SyncService {
  SyncService({required this.api, required this.db});

  final ApiClient api;
  final LocalDb db;

  static const _tables = [
    'trips',
    'legs',
    'bookings',
    'tasks',
    'packing_items',
    'journal_entries',
  ];

  /// Returns true on success; false on network error (caller toasts "offline").
  Future<bool> snapshot() async {
    try {
      final data = await api.syncSnapshot();
      // Tables missing from the payload are left untouched rather than cleared.
      final replacement = <String, List<Map<String, dynamic>>>{
        for (final t in _tables)
          if (data[t] is List)
            t: (data[t] as List)
                .whereType<Map<String, dynamic>>()
                .map((r) => Map<String, dynamic>.from(r))
                .toList(),
      };
      // Single transaction: a crash or bad row mid-sync must not leave the
      // offline cache half-cleared.
      await db.replaceAll(replacement);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    api: ref.watch(apiClientProvider),
    db: ref.watch(localDbProvider),
  );
});
