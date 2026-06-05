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
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteBooking(String id) async {
    try {
      await ref.read(apiClientProvider).deleteBooking(id);
      await _refresh();
      return true;
    } catch (_) {
      return false;
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
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTask(String id) async {
    try {
      await ref.read(apiClientProvider).deleteTask(id);
      await _refresh();
      return true;
    } catch (_) {
      return false;
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

  Future<void> _refresh() async {
    await ref.read(syncServiceProvider).snapshot();
    ref.read(syncTriggerProvider.notifier).state++;
  }
}

final tripMutationsProvider =
    Provider<TripMutations>((ref) => TripMutations(ref));
