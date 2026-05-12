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

  /// Returns true on success; false on network error (caller toasts "offline").
  Future<bool> snapshot() async {
    try {
      final data = await api.syncSnapshot();
      await _replace('trips', data['trips']);
      await _replace('legs', data['legs']);
      await _replace('bookings', data['bookings']);
      await _replace('tasks', data['tasks']);
      await _replace('packing_items', data['packing_items']);
      await _replace('journal_entries', data['journal_entries']);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _replace(String table, dynamic rows) async {
    if (rows is! List) return;
    await db.clearTable(table);
    final cast = rows
        .whereType<Map<String, dynamic>>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    await db.upsertAll(table, cast);
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    api: ref.watch(apiClientProvider),
    db: ref.watch(localDbProvider),
  );
});
