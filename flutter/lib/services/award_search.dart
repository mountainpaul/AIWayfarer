import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Award-availability deep links.
///
/// None of the three engines (Seats.aero, PointsYeah, Roame.travel) offers a
/// free API, but all encode search state in the URL, so the closest thing to
/// "checking availability" is landing the user on a pre-filled live search.
/// URL formats verified against real captured URLs, June 2026. PointsYeah and
/// Roame gate results behind a free login; the params survive the redirect.
class AwardEngineLink {
  const AwardEngineLink({required this.engine, required this.url});
  final String engine;
  final Uri url;
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

List<AwardEngineLink> buildAwardLinks({
  required String origin,
  required String destination,
  required DateTime date,
  int windowDays = 3, // PointsYeah free tier caps the window at 4 days
}) {
  final start = _fmt(date);
  final end = _fmt(date.add(Duration(days: windowDays)));
  final o = origin.trim().toUpperCase();
  final d = destination.trim().toUpperCase();

  return [
    AwardEngineLink(
      engine: 'Seats.aero',
      url: Uri.https('seats.aero', '/search', {
        'origins': o,
        'destinations': d,
        'date': start,
        'additional_days': 'true',
        'additional_days_num': '$windowDays',
        'min_seats': '1',
        'applicable_cabin': 'any',
      }),
    ),
    AwardEngineLink(
      engine: 'PointsYeah',
      url: Uri.https('www.pointsyeah.com', '/search', {
        'departure': o,
        'arrival': d,
        'departDate': start,
        'departDateSec': end,
        'tripType': '1',
        'adults': '1',
        'children': '0',
        'multiday': 'true',
        'cabins': 'Economy,Premium Economy,Business,First',
      }),
    ),
    AwardEngineLink(
      engine: 'Roame.travel',
      url: Uri.https('roame.travel', '/search', {
        'origin': o,
        'originType': 'airport',
        'destination': d,
        'destinationType': 'airport',
        'departureDate': start,
        'endDepartureDate': end,
        'pax': '1',
        'searchClass': 'ECON',
        'fareClasses': ['ECON', 'PREMECON'],
        'isSkyview': 'false',
        'flexibleDates': '0',
      }),
    ),
  ];
}

/// Home airport (IATA), used as the default origin for award searches.
class HomeAirportNotifier extends StateNotifier<String> {
  HomeAirportNotifier() : super('') {
    _load();
  }

  static const _key = 'home_airport';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key) ?? '';
  }

  Future<void> set(String code) async {
    state = code.trim().toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state);
  }
}

final homeAirportProvider =
    StateNotifierProvider<HomeAirportNotifier, String>(
        (_) => HomeAirportNotifier());

/// Remembered origin/destination per leg, so airports only need typing once.
class LegAirportMemory {
  static String _originKey(String legId) => 'award_origin_$legId';
  static String _destKey(String legId) => 'award_dest_$legId';

  static Future<(String?, String?)> load(String legId) async {
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs.getString(_originKey(legId)),
      prefs.getString(_destKey(legId)),
    );
  }

  static Future<void> save(
      String legId, String origin, String destination) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_originKey(legId), origin.trim().toUpperCase());
    await prefs.setString(_destKey(legId), destination.trim().toUpperCase());
  }
}
