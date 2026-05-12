import 'package:freezed_annotation/freezed_annotation.dart';

part 'journal_entry.freezed.dart';
part 'journal_entry.g.dart';

@freezed
class JournalEntry with _$JournalEntry {
  const factory JournalEntry({
    required String id,
    @JsonKey(name: 'leg_id') String? legId,
    required String content,
    @JsonKey(name: 'entry_type') @Default('note') String entryType,
    @JsonKey(name: 'location_name') String? locationName,
    @JsonKey(name: 'location_lat') double? locationLat,
    @JsonKey(name: 'location_lon') double? locationLon,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _JournalEntry;

  factory JournalEntry.fromJson(Map<String, dynamic> json) =>
      _$JournalEntryFromJson(json);
}
