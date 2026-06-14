import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';
import '../models/booking.dart';
import '../models/briefing.dart';
import '../models/chat_message.dart';
import '../models/grounding.dart';
import '../models/journal_entry.dart';
import '../models/leg.dart';
import '../models/packing_item.dart';
import '../models/task.dart';
import '../models/trip.dart';

/// Holds the configurable base URL so settings can change it at runtime.
/// Hydrated eagerly in `main()` from SharedPreferences via the provider override
/// — see `main.dart`.
class ApiBaseUrlNotifier extends StateNotifier<String> {
  ApiBaseUrlNotifier({String? initial}) : super(initial ?? Env.apiBaseUrl);

  static const prefsKey = 'api_base_url';

  Future<void> set(String url) async {
    state = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, url);
  }
}

final apiBaseUrlProvider =
    StateNotifierProvider<ApiBaseUrlNotifier, String>((_) {
  return ApiBaseUrlNotifier();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return ApiClient(baseUrl: baseUrl);
});

class ApiClient {
  ApiClient({required String baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  final Dio _dio;

  // ── Trips ────────────────────────────────────────────────
  Future<List<Trip>> listTrips() async {
    final r = await _dio.get<List<dynamic>>('/trips');
    return (r.data ?? [])
        .map((e) => Trip.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Trip> getTrip(String id) async {
    final r = await _dio.get<Map<String, dynamic>>('/trips/$id');
    return Trip.fromJson(r.data!);
  }

  // ── Legs ─────────────────────────────────────────────────
  Future<List<Leg>> listLegs({String? tripId}) async {
    final r = await _dio.get<List<dynamic>>('/legs',
        queryParameters: tripId == null ? null : {'trip_id': tripId});
    return (r.data ?? [])
        .map((e) => Leg.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Leg> getLeg(String id) async {
    final r = await _dio.get<Map<String, dynamic>>('/legs/$id');
    return Leg.fromJson(r.data!);
  }

  Future<Leg> patchLeg(String id, Map<String, dynamic> patch) async {
    final r = await _dio.patch<Map<String, dynamic>>('/legs/$id', data: patch);
    return Leg.fromJson(r.data!);
  }

  // ── Bookings ─────────────────────────────────────────────
  Future<List<Booking>> listBookings({String? legId}) async {
    final r = await _dio.get<List<dynamic>>('/bookings',
        queryParameters: legId == null ? null : {'leg_id': legId});
    return (r.data ?? [])
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Booking> getBooking(String id) async {
    final r = await _dio.get<Map<String, dynamic>>('/bookings/$id');
    return Booking.fromJson(r.data!);
  }

  Future<Booking> createBooking(Map<String, dynamic> body) async {
    final r = await _dio.post<Map<String, dynamic>>('/bookings', data: body);
    return Booking.fromJson(r.data!);
  }

  Future<Booking> patchBooking(String id, Map<String, dynamic> patch) async {
    final r =
        await _dio.patch<Map<String, dynamic>>('/bookings/$id', data: patch);
    return Booking.fromJson(r.data!);
  }

  Future<void> deleteBooking(String id) async {
    await _dio.delete<void>('/bookings/$id');
  }

  // ── Tasks ────────────────────────────────────────────────
  Future<List<Task>> listTasks({String? legId, bool? isDone}) async {
    final r = await _dio.get<List<dynamic>>('/tasks',
        queryParameters: {
          if (legId != null) 'leg_id': legId,
          if (isDone != null) 'is_done': isDone,
        });
    return (r.data ?? [])
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Task> createTask(Map<String, dynamic> body) async {
    final r = await _dio.post<Map<String, dynamic>>('/tasks', data: body);
    return Task.fromJson(r.data!);
  }

  Future<Task> patchTask(String id, Map<String, dynamic> patch) async {
    final r = await _dio.patch<Map<String, dynamic>>('/tasks/$id', data: patch);
    return Task.fromJson(r.data!);
  }

  /// Backend /tasks/{id}/done is a stateless toggle — flips whatever's there.
  /// Body is ignored. Caller cannot SET an explicit value via this method;
  /// use patchTask({'is_done': true|false}) for that.
  Future<Task> toggleTaskDone(String id) async {
    final r = await _dio.patch<Map<String, dynamic>>('/tasks/$id/done');
    return Task.fromJson(r.data!);
  }

  Future<void> deleteTask(String id) async {
    await _dio.delete<void>('/tasks/$id');
  }

  // ── Packing ──────────────────────────────────────────────
  Future<List<PackingItem>> listPacking({String? tripId}) async {
    final r = await _dio.get<List<dynamic>>('/packing',
        queryParameters: tripId == null ? null : {'trip_id': tripId});
    return (r.data ?? [])
        .map((e) => PackingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PackingItem> createPacking(Map<String, dynamic> body) async {
    final r = await _dio.post<Map<String, dynamic>>('/packing', data: body);
    return PackingItem.fromJson(r.data!);
  }

  Future<PackingItem> patchPacking(String id, Map<String, dynamic> patch) async {
    final r =
        await _dio.patch<Map<String, dynamic>>('/packing/$id', data: patch);
    return PackingItem.fromJson(r.data!);
  }

  /// Backend /packing/{id}/packed is a stateless toggle. See toggleTaskDone.
  Future<PackingItem> togglePacked(String id) async {
    final r = await _dio.patch<Map<String, dynamic>>('/packing/$id/packed');
    return PackingItem.fromJson(r.data!);
  }

  Future<void> deletePacking(String id) async {
    await _dio.delete<void>('/packing/$id');
  }

  // ── Journal ──────────────────────────────────────────────
  Future<List<JournalEntry>> listJournal({String? legId}) async {
    final r = await _dio.get<List<dynamic>>('/journal',
        queryParameters: legId == null ? null : {'leg_id': legId});
    return (r.data ?? [])
        .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<JournalEntry> createJournal(Map<String, dynamic> body) async {
    final r = await _dio.post<Map<String, dynamic>>('/journal', data: body);
    return JournalEntry.fromJson(r.data!);
  }

  // ── Chat ─────────────────────────────────────────────────
  /// `mode` is "planning" or "companion". Backend defaults to "companion" if
  /// omitted. The `history` field is intentionally absent — the backend system
  /// prompt is stable across a session for prompt caching, and conversation
  /// history is reconstructed via session_id (TODO when we wire it).
  Future<ChatResponse> chat({
    required String message,
    required Grounding grounding,
    String mode = 'companion',
    String? sessionId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/chat',
      data: {
        'message': message,
        'grounding': grounding.toJson(),
        'mode': mode,
        if (sessionId != null) 'session_id': sessionId,
      },
      // Heavy-tier queries can run long; don't cut them off at the
      // global 60s receiveTimeout.
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
    return ChatResponse.fromJson(r.data!);
  }

  // ── Grounding ────────────────────────────────────────────
  Future<Map<String, dynamic>> getGrounding() async {
    final r = await _dio.get<Map<String, dynamic>>('/grounding');
    return r.data ?? {};
  }

  // ── Briefing ─────────────────────────────────────────────
  Future<Briefing> generateBriefing({String? date}) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/briefing/generate',
      data: {if (date != null) 'date': date},
    );
    return Briefing.fromJson(r.data!);
  }

  Future<Briefing?> getTodayBriefing() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/briefing/today');
      if (r.data == null) return null;
      return Briefing.fromJson(r.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── Gmail Scanner ──────────────────────────────────────────
  Future<Map<String, dynamic>> scanBookingEmails({int months = 6}) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/gmail/scan-bookings',
      queryParameters: {'months': months},
      // Gmail fetch + Claude parse regularly takes 30-60s+, beyond the
      // global 60s receiveTimeout.
      options: Options(receiveTimeout: const Duration(minutes: 3)),
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> importBookings(
      List<Map<String, dynamic>> bookings) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/gmail/import-bookings',
      data: bookings,
    );
    return r.data ?? {};
  }

  Future<Map<String, dynamic>> scanLoyaltyOffers({int months = 2}) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/gmail/scan-offers',
      queryParameters: {'months': months},
      options: Options(receiveTimeout: const Duration(minutes: 3)),
    );
    return r.data ?? {};
  }

  // ── Sync ─────────────────────────────────────────────────
  /// Pull the sync bundle. Pass [since] (the previous response's `server_time`)
  /// to fetch only rows changed after that cursor — a cheap delta.
  Future<Map<String, dynamic>> syncSnapshot({String? since}) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/sync/snapshot',
      queryParameters: since == null ? null : {'since': since},
    );
    return r.data ?? {};
  }
}

/// Thrown when a request never reached the server (no connectivity / timeout),
/// as opposed to the server responding with an error. The offline outbox uses
/// this to decide whether to keep an op queued (unreachable) or drop it (the
/// server responded). See SyncService._flushOutbox.
class ApiUnreachable implements Exception {
  ApiUnreachable(this.cause);
  final Object cause;
  @override
  String toString() => 'ApiUnreachable: $cause';
}

/// Map a DioException to [ApiUnreachable] when it's a connectivity/timeout
/// failure (no HTTP response was received).
Object mapDioError(Object e) {
  if (e is DioException) {
    const unreachable = {
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    };
    if (e.response == null && unreachable.contains(e.type)) {
      return ApiUnreachable(e);
    }
  }
  return e;
}
