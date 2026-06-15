import 'package:freezed_annotation/freezed_annotation.dart';

part 'traveler_profile.freezed.dart';
part 'traveler_profile.g.dart';

/// Traveler preferences. Stable typed columns + a JSON `preferencesBlob`
/// sandbox for evolving questionnaire fields (interests, avoids). The
/// `profileSummary` is the distilled paragraph the backend injects into chat
/// grounding — AI-managed, not user-edited here.
@freezed
class TravelerProfile with _$TravelerProfile {
  const factory TravelerProfile({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'lodging_style') String? lodgingStyle,
    @JsonKey(name: 'transport_preference') String? transportPreference,
    @JsonKey(name: 'travel_pace') String? travelPace,
    @JsonKey(name: 'budget_tier') String? budgetTier,
    @JsonKey(name: 'profile_summary') String? profileSummary,
    @JsonKey(name: 'preferences_blob')
    @Default(<String, dynamic>{}) Map<String, dynamic> preferencesBlob,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _TravelerProfile;

  factory TravelerProfile.fromJson(Map<String, dynamic> json) =>
      _$TravelerProfileFromJson(json);
}

extension TravelerProfileX on TravelerProfile {
  /// Interests stored in the sandbox blob, defensively coerced to a string list.
  List<String> get interests => _stringList(preferencesBlob['interests']);

  /// Things to avoid, stored in the sandbox blob.
  List<String> get avoids => _stringList(preferencesBlob['avoids']);
}

List<String> _stringList(Object? raw) {
  if (raw is List) {
    return raw.map((e) => e.toString()).toList();
  }
  return const [];
}
