import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/task.dart';

void main() {
  group('Task', () {
    group('fromJson', () {
      test('maps all snake_case fields correctly', () {
        final t = Task.fromJson({
          'id': 'task-1',
          'leg_id': 'leg-1',
          'title': 'Book Shinkansen',
          'priority': 'high',
          'due_date': '2026-08-01',
          'is_done': true,
          'notes': 'Check JR Pass',
          'created_at': '2026-06-01T00:00:00Z',
          'updated_at': '2026-06-14T00:00:00Z',
        });

        expect(t.id, 'task-1');
        expect(t.legId, 'leg-1');
        expect(t.title, 'Book Shinkansen');
        expect(t.priority, 'high');
        expect(t.dueDate, '2026-08-01');
        expect(t.isDone, isTrue);
        expect(t.notes, 'Check JR Pass');
        expect(t.createdAt, '2026-06-01T00:00:00Z');
        expect(t.updatedAt, '2026-06-14T00:00:00Z');
      });

      test('defaults apply when optional fields are omitted', () {
        final t = Task.fromJson({
          'id': 'task-2',
          'title': 'Pack bag',
          'priority': 'medium',
        });

        expect(t.legId, isNull);
        expect(t.isDone, isFalse);
        expect(t.dueDate, isNull);
        expect(t.notes, isNull);
        expect(t.createdAt, isNull);
        expect(t.updatedAt, isNull);
      });
    });

    group('toJson round-trip', () {
      test('serialises and deserialises without data loss', () {
        const t = Task(
          id: 'task-rt',
          legId: 'leg-rt',
          title: 'Reserve restaurant',
          priority: 'low',
          dueDate: '2026-07-15',
          isDone: false,
          notes: 'Dinner for 2',
        );

        final json = t.toJson();
        final t2 = Task.fromJson(json);

        expect(t2, equals(t));
      });
    });

    group('TaskX extension — dueDateTime', () {
      test('returns parsed DateTime when dueDate is set', () {
        final t = Task.fromJson({
          'id': 'task-3',
          'title': 'Visa',
          'priority': 'high',
          'due_date': '2026-07-15',
        });

        expect(t.dueDateTime, isNotNull);
        expect(t.dueDateTime, equals(DateTime(2026, 7, 15)));
      });

      test('returns null when dueDate is absent', () {
        const t = Task(
          id: 'task-4',
          title: 'General task',
          priority: 'low',
        );

        expect(t.dueDateTime, isNull);
      });

      test('returns null when dueDate string is malformed (tryParse)', () {
        const t = Task(
          id: 'task-5',
          title: 'Bad date task',
          priority: 'medium',
          dueDate: 'not-a-date',
        );

        expect(t.dueDateTime, isNull);
      });

      test('parses full ISO-8601 timestamp in dueDate', () {
        const t = Task(
          id: 'task-6',
          title: 'Meeting',
          priority: 'high',
          dueDate: '2026-08-01T14:30:00Z',
        );

        expect(t.dueDateTime, isNotNull);
        expect(t.dueDateTime!.year, 2026);
        expect(t.dueDateTime!.month, 8);
        expect(t.dueDateTime!.day, 1);
      });
    });
  });
}
