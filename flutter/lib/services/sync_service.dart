import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'local_db.dart';

/// Two-way-ish sync (see docs/sync-redesign.md).
///
/// Reads come from local SQLite. A sync:
///   1. Flushes the offline outbox (local edits made while disconnected) to the
///      backend, so the server has them BEFORE we pull.
///   2. Pulls a snapshot (delta when we have a cursor) and MERGES it by
///      last-write-wins — never wiping local-only or newer-local rows.
///
/// The backend is not treated as authoritative; the newer `updated_at` wins.
class SyncService {
  SyncService({required this.api, required this.db});

  final ApiClient api;
  final LocalDb db;

  // The snapshot JSON keys are plural (the API contract); the local tables are
  // singular (BEST_PRACTICES §3.1). Map each plural payload key to its table.
  static const _tableForKey = {
    'trips': 'trip',
    'legs': 'leg',
    'bookings': 'booking',
    'tasks': 'task',
    'packing_items': 'packing_item',
    'journal_entries': 'journal_entry',
  };

  /// Delta cursor: the server_time from the last successful pull.
  static const _cursorKey = 'sync_cursor';

  /// Returns true on success; false on network error (caller keeps showing
  /// cached data). Queued offline edits are retained on failure, not lost.
  Future<bool> snapshot() async {
    try {
      // 1. Push queued offline edits first.
      await _flushOutbox();

      // 2. Pull (delta when we have a cursor) and merge non-destructively.
      final prefs = await SharedPreferences.getInstance();
      final since = prefs.getString(_cursorKey);
      final data = await api.syncSnapshot(since: since);

      final incoming = <String, List<Map<String, dynamic>>>{
        for (final e in _tableForKey.entries)
          if (data[e.key] is List)
            e.value: (data[e.key] as List)
                .whereType<Map<String, dynamic>>()
                .map((r) => Map<String, dynamic>.from(r))
                .toList(),
      };
      await db.mergeAll(incoming);

      final serverTime = data['server_time'];
      if (serverTime is String && serverTime.isNotEmpty) {
        await prefs.setString(_cursorKey, serverTime);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Replay queued local mutations to the backend, oldest first. Stops at the
  /// first op that fails because the backend is unreachable (preserving order
  /// and the queue); an op the server actively rejects (4xx/5xx) is dropped so
  /// one bad op can't wedge the queue forever.
  Future<void> _flushOutbox() async {
    final ops = await db.pendingOps();
    for (final op in ops) {
      try {
        await _replay(op);
        await db.removeOp(op['op_id'] as int);
      } catch (e) {
        if (mapDioError(e) is ApiUnreachable) {
          // Offline / can't reach server — keep this and all later ops queued.
          break;
        }
        // Server responded with an error (e.g. 404 on an already-gone row):
        // delivered as far as it can be — drop it and continue.
        await db.removeOp(op['op_id'] as int);
      }
    }
  }

  Future<void> _replay(Map<String, Object?> op) async {
    final entity = op['entity'] as String;
    final id = op['entity_id'] as String;
    final type = op['op'] as String;
    final raw = op['payload'] as String?;
    final payload = raw == null
        ? <String, dynamic>{}
        : (jsonDecode(raw) as Map).cast<String, dynamic>();

    switch ('$entity.$type') {
      case 'booking.update':
        await api.patchBooking(id, payload);
        break;
      case 'booking.delete':
        await api.deleteBooking(id);
        break;
      case 'task.update':
        await api.patchTask(id, payload);
        break;
      case 'task.delete':
        await api.deleteTask(id);
        break;
      case 'packing.update':
        await api.patchPacking(id, payload);
        break;
      default:
        // Unknown op shape — drop it rather than loop forever.
        break;
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    api: ref.watch(apiClientProvider),
    db: ref.watch(localDbProvider),
  );
});
