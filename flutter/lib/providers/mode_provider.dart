import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppMode { planning, companion }

class ModeNotifier extends StateNotifier<AppMode> {
  ModeNotifier() : super(AppMode.planning);
  void set(AppMode m) => state = m;
  void toggle() => state =
      state == AppMode.planning ? AppMode.companion : AppMode.planning;
}

final modeProvider =
    StateNotifierProvider<ModeNotifier, AppMode>((_) => ModeNotifier());
