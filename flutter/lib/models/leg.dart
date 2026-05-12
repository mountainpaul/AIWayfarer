import 'package:freezed_annotation/freezed_annotation.dart';

part 'leg.freezed.dart';
part 'leg.g.dart';

@freezed
class Leg with _$Leg {
  const factory Leg({
    required String id,
    @JsonKey(name: 'trip_id') required String tripId,
    required String slug,
    required String name,
    String? emoji,
    String? color,
    @JsonKey(name: 'start_date') required String startDate,
    @JsonKey(name: 'end_date') required String endDate,
    @JsonKey(name: 'is_schengen') @Default(false) bool isSchengen,
    @JsonKey(name: 'budget_cents') int? budgetCents,
    @Default('USD') String currency,
    String? places,
    String? notes,
    @JsonKey(name: 'sort_order') @Default(0) int sortOrder,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _Leg;

  factory Leg.fromJson(Map<String, dynamic> json) => _$LegFromJson(json);
}

extension LegX on Leg {
  DateTime get startDateTime => DateTime.parse(startDate);
  DateTime get endDateTime => DateTime.parse(endDate);

  bool containsDate(DateTime d) {
    final start = startDateTime;
    final end = endDateTime;
    return !d.isBefore(start) && !d.isAfter(end.add(const Duration(days: 1)));
  }
}
