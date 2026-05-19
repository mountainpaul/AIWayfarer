import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuietModeNotifier extends StateNotifier<bool> {
  QuietModeNotifier({bool initial = false}) : super(initial);

  static const prefsKey = 'quiet_mode';

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);
  }
}

final quietModeProvider =
    StateNotifierProvider<QuietModeNotifier, bool>((_) {
  return QuietModeNotifier();
});
