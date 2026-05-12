import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    @JsonKey(name: 'leg_id') String? legId,
    required String title,
    required String priority,
    @JsonKey(name: 'due_date') String? dueDate,
    @JsonKey(name: 'is_done') @Default(false) bool isDone,
    String? notes,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}

extension TaskX on Task {
  DateTime? get dueDateTime =>
      dueDate == null ? null : DateTime.tryParse(dueDate!);
}
