import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

/// A single iteration step from the multi-agent pipeline (§3.5).
/// Backend emits {label, content}. Source: app/services/claude.py.
@freezed
class IterationStep with _$IterationStep {
  const factory IterationStep({
    required String label,
    required String content,
  }) = _IterationStep;

  factory IterationStep.fromJson(Map<String, dynamic> json) =>
      _$IterationStepFromJson(json);
}

/// Wire shape returned by POST /chat. Source: app/models.py:ChatResponse.
@freezed
class ChatResponse with _$ChatResponse {
  const factory ChatResponse({
    required String answer,
    @Default('') String draft,
    @Default('') String critique,
    @Default('medium') String confidence,
    @Default(<String>[]) List<String> sources,
    @Default(<IterationStep>[]) List<IterationStep> iterations,
  }) = _ChatResponse;

  factory ChatResponse.fromJson(Map<String, dynamic> json) =>
      _$ChatResponseFromJson(json);
}

/// UI-side message stored in the chat history. Built locally — never decoded
/// directly from a network response. The chat provider constructs an assistant
/// ChatMessage from a ChatResponse.
@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String role,
    required String content,
    @JsonKey(name: 'created_at') String? createdAt,
    @Default(<IterationStep>[]) List<IterationStep> iterations,
    @Default('high') String confidence,
    @JsonKey(name: 'clarifying_question') String? clarifyingQuestion,
    @Default(<String>[]) List<String> sources,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}
