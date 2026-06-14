import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking.dart';
import '../models/journal_entry.dart';
import '../models/leg.dart';
import '../models/packing_item.dart';
import '../models/task.dart';
import '../models/trip.dart';
import '../services/api_client.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

/// Read paths come from local SQLite. Write paths go to backend, then refresh local.

final syncTriggerProvider = StateProvider<int>((_) => 0);

final initialSyncProvider = FutureProvider<bool>((ref) async {
  final sync = ref.watch(syncServiceProvider);
  final ok = await sync.snapshot();
  return ok;
});

/// Pull fresh data from the backend, then bump the trigger so all local-read
/// providers refetch. Returns false when the backend is unreachable (cached
/// data keeps being shown). This is what pull-to-refresh should call —
/// bumping the trigger alone only re-reads local SQLite.
Future<bool> refreshFromBackend(WidgetRef ref) async {
  final ok = await ref.read(syncServiceProvider).snapshot();
  ref.read(syncTriggerProvider.notifier).state++;
  return ok;
}

final tripsProvider = FutureProvider<List<Trip>>((ref) async {
  ref.watch(syncTriggerProvider);
  await ref.watch(initialSyncProvider.future);
  return ref.watch(localDbProvider).trips();
});

final legsProvider = FutureProvider<List<Leg>>((ref) async {
  ref.watch(syncTriggerProvider);
  await ref.watch(initialSyncProvider.future);
  return ref.watch(localDbProvider).legs();
});

final legProvider =
    FutureProvider.family<Leg?, String>((ref, id) async {
  ref.watch(syncTriggerProvider);
  // Wait for the initial sync like the list providers do — otherwise a
  // cold-start deep link (web URL refresh) reads an empty DB and 404s.
  await ref.watch(initialSyncProvider.future);
  return ref.watch(localDbProvider).leg(id);
});

final currentLegProvider = FutureProvider<Leg?>((ref) async {
  ref.watch(syncTriggerProvider);
  final legs = await ref.watch(legsProvider.future);
  final today = DateTime.now();
  final t = DateTime(today.year, today.month, today.day);
  for (final l in legs) {
    if (l.containsDate(t)) return l;
  }
  return null;
});

final bookingsForLegProvider =
    FutureProvider.family<List<Booking>, String>((ref, legId) async {
  ref.watch(syncTriggerProvider);
  return ref.watch(localDbProvider).bookings(legId: legId);
});

final tasksForLegProvider =
    FutureProvider.family<List<Task>, String?>((ref, legId) async {
  ref.watch(syncTriggerProvider);
  return ref.watch(localDbProvider).tasks(legId: legId);
});

final openTaskCountProvider = FutureProvider<int>((ref) async {
  ref.watch(syncTriggerProvider);
  final t = await ref.watch(localDbProvider).tasks(done: false);
  return t.length;
});

/// Schengen 90/180 usage. Computed server-side, so null when the backend is
/// unreachable (the card hides rather than showing stale numbers).
final schengenProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(syncTriggerProvider);
  try {
    return await ref.read(apiClientProvider).getSchengen();
  } catch (_) {
    return null;
  }
});

/// Per-leg accommodation coverage. Computed server-side; null when offline.
final coverageProvider =
    FutureProvider<List<Map<String, dynamic>>?>((ref) async {
  ref.watch(syncTriggerProvider);
  try {
    return await ref.read(apiClientProvider).getCoverage();
  } catch (_) {
    return null;
  }
});

/// Budget rollup (planned vs actual, per currency). Server-computed; null offline.
final budgetProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(syncTriggerProvider);
  try {
    return await ref.read(apiClientProvider).getBudget();
  } catch (_) {
    return null;
  }
});

final packingForTripProvider =
    FutureProvider.family<List<PackingItem>, String>((ref, tripId) async {
  ref.watch(syncTriggerProvider);
  return ref.watch(localDbProvider).packing(tripId: tripId);
});

final journalForLegProvider =
    FutureProvider.family<List<JournalEntry>, String?>((ref, legId) async {
  ref.watch(syncTriggerProvider);
  return ref.watch(localDbProvider).journal(legId: legId);
});

final nextBookingProvider = FutureProvider<Booking?>((ref) async {
  final leg = await ref.watch(currentLegProvider.future);
  if (leg == null) return null;
  final bookings = await ref.watch(bookingsForLegProvider(leg.id).future);
  final now = DateTime.now();
  Booking? next;
  for (final b in bookings) {
    final start = b.startDateTime;
    if (start != null && start.isAfter(now)) {
      if (next == null || start.isBefore(next.startDateTime!)) {
        next = b;
      }
    }
  }
  return next;
});

/// Mutators - call API, then bump sync trigger so consumers refetch.

class TripMutations {
  TripMutations(this.ref);
  final Ref ref;

  // ── Trips ──
  Future<bool> createTrip(Map<String, dynamic> payload) async {
    try {
      await ref.read(apiClientProvider).createTrip(payload);
      await _refresh();
      return true;
    } catch (_) {
      return false; // create is online-only for now
    }
  }

  Future<bool> updateTrip(String id, Map<String, dynamic> patch) async {
    try {
      await ref.read(apiClientProvider).patchTrip(id, patch);
      await _refresh();
      return true;
    } catch (e) {
      return _queueIfOffline(e, 'trip', 'trip', id, 'update', patch);
    }
  }

  Future<bool> deleteTrip(String id) async {
    try {
      await ref.read(apiClientProvider).deleteTrip(id);
      await _refresh();
      return true;
    } catch (e) {
      return _queueIfOffline(e, 'trip', 'trip', id, 'delete', null);
    }
  }

  Future<bool> toggleTaskDone(String id) async {
    try {
      await ref.read(apiClientProvider).toggleTaskDone(id);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> togglePacked(String id) async {
    try {
      await ref.read(apiClientProvider).togglePacked(id);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createBooking(Map<String, dynamic> payload) async {
    try {
      await ref.read(apiClientProvider).createBooking(payload);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateBooking(String id, Map<String, dynamic> patch) async {
    try {
      await ref.read(apiClientProvider).patchBooking(id, patch);
      await _refresh();
      return true;
    } catch (e) {
      return _queueIfOffline(e, 'booking', 'booking', id, 'update', patch);
    }
  }

  Future<bool> deleteBooking(String id) async {
    try {
      await ref.read(apiClientProvider).deleteBooking(id);
      await _refresh();
      return true;
    } catch (e) {
      return _queueIfOffline(e, 'booking', 'booking', id, 'delete', null);
    }
  }

  Future<bool> createTask(Map<String, dynamic> payload) async {
    try {
      await ref.read(apiClientProvider).createTask(payload);
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTask(String id, Map<String, dynamic> patch) async {
    try {
      await ref.read(apiClientProvider).patchTask(id, patch);
      await _refresh();
      return true;
    } catch (e) {
      return _queueIfOffline(e, 'task', 'task', id, 'update', patch);
    }
  }

  Future<bool> deleteTask(String id) async {
    try {
      await ref.read(apiClientProvider).deleteTask(id);
      await _refresh();
      return true;
    } catch (e) {
      return _queueIfOffline(e, 'task', 'task', id, 'delete', null);
    }
  }

  Future<bool> addJournal({
    String? legId,
    required String content,
    String entryType = 'note',
    String? locationName,
  }) async {
    try {
      await ref.read(apiClientProvider).createJournal({
        if (legId != null) 'leg_id': legId,
        'content': content,
        'entry_type': entryType,
        if (locationName != null) 'location_name': locationName,
      });
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// When a write fails only because the backend is unreachable, save it
  /// locally (optimistic) and queue it in the outbox so it retries on the next
  /// sync — then report success, because the change IS saved, just not yet
  /// pushed. A genuine server rejection (4xx/5xx) returns false as before.
  ///
  /// This is the fix for the lost edit: editing a booking while offline no
  /// longer fails-and-vanishes; it persists and syncs when connectivity returns.
  Future<bool> _queueIfOffline(
    Object error,
    String table,
    String entity,
    String id,
    String op,
    Map<String, dynamic>? patch,
  ) async {
    if (mapDioError(error) is! ApiUnreachable) return false;
    final db = ref.read(localDbProvider);
    final now = _nowIso();
    if (op == 'delete') {
      await db.localTombstone(table, id, now);
    } else if (patch != null) {
      await db.localPatch(table, id, patch, now);
    }
    await db.enqueueOp(
      entity: entity,
      entityId: id,
      op: op,
      payloadJson: patch == null ? null : jsonEncode(patch),
      queuedAt: now,
    );
    ref.read(syncTriggerProvider.notifier).state++;
    return true;
  }

  /// UTC timestamp in the backend's exact format (no milliseconds) so local and
  /// server updated_at values compare correctly for last-write-wins.
  String _nowIso() {
    final n = DateTime.now().toUtc();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}'
        'T${two(n.hour)}:${two(n.minute)}:${two(n.second)}Z';
  }

  Future<void> _refresh() async {
    await ref.read(syncServiceProvider).snapshot();
    ref.read(syncTriggerProvider.notifier).state++;
  }
}

final tripMutationsProvider =
    Provider<TripMutations>((ref) => TripMutations(ref));
