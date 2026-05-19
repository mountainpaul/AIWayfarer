import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../services/api_client.dart';
import '../services/grounding_service.dart';
import 'mode_provider.dart';

class ChatState {
  ChatState({this.messages = const [], this.sending = false, this.error});

  final List<ChatMessage> messages;
  final bool sending;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? sending,
    String? error,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        error: error,
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this.ref) : super(ChatState()) {
    _restore();
  }

  static const _prefsKey = 'chat_history';
  static const _maxMessages = 100;

  final Ref ref;
  final _uuid = const Uuid();

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(messages: list);
    } catch (_) {
      // Corrupted data — start fresh.
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = state.messages.length > _maxMessages
        ? state.messages.sublist(state.messages.length - _maxMessages)
        : state.messages;
    await prefs.setString(
      _prefsKey,
      jsonEncode(trimmed.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty || state.sending) return;
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      sending: true,
      error: null,
    );

    try {
      final grounding = await ref.read(groundingServiceProvider).compose();
      final mode = ref.read(modeProvider) == AppMode.planning
          ? 'planning'
          : 'companion';
      final response = await ref.read(apiClientProvider).chat(
            message: text.trim(),
            grounding: grounding,
            mode: mode,
          );
      final reply = ChatMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: response.answer,
        createdAt: DateTime.now().toIso8601String(),
        iterations: response.iterations,
        confidence: response.confidence,
        sources: response.sources,
        clarifyingQuestion:
            response.confidence == 'low' ? response.answer : null,
      );
      state = state.copyWith(
        messages: [...state.messages, reply],
        sending: false,
      );
      _persist();
    } catch (e) {
      state = state.copyWith(sending: false, error: e.toString());
      _persist();
    }
  }

  void clear() {
    state = ChatState();
    _persist();
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));
