import 'package:freezed_annotation/freezed_annotation.dart';

part 'briefing.freezed.dart';
part 'briefing.g.dart';

/// Pre-trip / morning briefing (§9). Generated overnight, surfaced on the
/// Today screen. Backend canonical shape: {id, date, markdown, created_at}.
@freezed
class Briefing with _$Briefing {
  const factory Briefing({
    required String id,
    required String date,
    required String markdown,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _Briefing;

  factory Briefing.fromJson(Map<String, dynamic> json) =>
      _$BriefingFromJson(json);
}
