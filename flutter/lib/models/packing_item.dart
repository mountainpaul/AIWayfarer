import 'package:freezed_annotation/freezed_annotation.dart';

part 'packing_item.freezed.dart';
part 'packing_item.g.dart';

@freezed
class PackingItem with _$PackingItem {
  const factory PackingItem({
    required String id,
    @JsonKey(name: 'trip_id') required String tripId,
    required String category,
    required String name,
    @JsonKey(name: 'is_packed') @Default(false) bool isPacked,
    @JsonKey(name: 'sort_order') @Default(0) int sortOrder,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _PackingItem;

  factory PackingItem.fromJson(Map<String, dynamic> json) =>
      _$PackingItemFromJson(json);
}

