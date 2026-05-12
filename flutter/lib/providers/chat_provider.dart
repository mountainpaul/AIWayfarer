import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  ChatNotifier(this.ref) : super(ChatState());

  final Ref ref;
  final _uuid = const Uuid();

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
        // When the critic returns low confidence, the answer IS the
        // clarifying question (per spec §3.4). Surface it so the UI chip
        // renders.
        clarifyingQuestion:
            response.confidence == 'low' ? response.answer : null,
      );
      state = state.copyWith(
        messages: [...state.messages, reply],
        sending: false,
      );
    } catch (e) {
      state = state.copyWith(sending: false, error: e.toString());
    }
  }

  void clear() {
    state = ChatState();
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));
