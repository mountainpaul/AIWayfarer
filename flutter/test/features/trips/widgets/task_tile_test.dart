import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/trips/widgets/task_tile.dart';
import 'package:wayfarer/models/task.dart';
import 'package:wayfarer/providers/trip_provider.dart';

// ---------------------------------------------------------------------------
// Fake TripMutations
// ---------------------------------------------------------------------------
class _FakeMutations extends TripMutations {
  _FakeMutations() : super(_NullRef());

  String? toggledTaskId;
  String? deletedTaskId;
  String? updatedTaskId;
  bool returnValue = true;

  @override
  Future<bool> toggleTaskDone(String id) async {
    toggledTaskId = id;
    return returnValue;
  }

  @override
  Future<bool> deleteTask(String id) async {
    deletedTaskId = id;
    return returnValue;
  }

  @override
  Future<bool> updateTask(String id, Map<String, dynamic> patch) async {
    updatedTaskId = id;
    return returnValue;
  }
}

class _NullRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

// ---------------------------------------------------------------------------
// Sample models
// ---------------------------------------------------------------------------
const _pendingTask = Task(
  id: 'task-1',
  legId: 'leg-1',
  title: 'Book Shinkansen',
  priority: 'high',
  dueDate: '2026-08-01',
  isDone: false,
);

const _doneTask = Task(
  id: 'task-2',
  legId: 'leg-1',
  title: 'Buy travel insurance',
  priority: 'critical',
  isDone: true,
);

const _lowPriorityTask = Task(
  id: 'task-3',
  title: 'Get souvenirs',
  priority: 'low',
  isDone: false,
);

const _mediumTask = Task(
  id: 'task-4',
  title: 'Check luggage weight',
  priority: 'medium',
  isDone: false,
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
Widget _wrap(Task task, {_FakeMutations? mutations}) {
  return ProviderScope(
    overrides: [
      if (mutations != null)
        tripMutationsProvider.overrideWithValue(mutations),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: TaskTile(task: task),
      ),
    ),
  );
}

void main() {
  group('TaskTile', () {
    // ── Rendering ─────────────────────────────────────────────────────────

    testWidgets('renders task title', (tester) async {
      await tester.pumpWidget(_wrap(_pendingTask));
      expect(find.text('Book Shinkansen'), findsOneWidget);
    });

    testWidgets('renders priority label', (tester) async {
      await tester.pumpWidget(_wrap(_pendingTask));
      expect(find.text('high'), findsOneWidget);
    });

    testWidgets('renders due date when present', (tester) async {
      await tester.pumpWidget(_wrap(_pendingTask));
      expect(find.textContaining('2026-08-01'), findsOneWidget);
    });

    testWidgets('hides due date when absent', (tester) async {
      await tester.pumpWidget(_wrap(_lowPriorityTask));
      expect(find.textContaining('due'), findsNothing);
    });

    testWidgets('renders all priority variants', (tester) async {
      for (final priority in ['critical', 'high', 'medium', 'low']) {
        await tester.pumpWidget(_wrap(
          Task(id: 'p-$priority', title: 'Test', priority: priority),
        ));
        expect(find.text(priority), findsOneWidget);
      }
    });

    // ── Checkbox state ────────────────────────────────────────────────────

    testWidgets('pending task checkbox is unchecked', (tester) async {
      await tester.pumpWidget(_wrap(_pendingTask));
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('done task checkbox is checked', (tester) async {
      await tester.pumpWidget(_wrap(_doneTask));
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    // ── Strikethrough on done task ────────────────────────────────────────

    testWidgets('done task title has strikethrough decoration', (tester) async {
      await tester.pumpWidget(_wrap(_doneTask));
      final text = tester.widget<Text>(find.text('Buy travel insurance'));
      expect(text.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('pending task title has no strikethrough', (tester) async {
      await tester.pumpWidget(_wrap(_pendingTask));
      final text = tester.widget<Text>(find.text('Book Shinkansen'));
      // null decoration means no strikethrough.
      expect(text.style?.decoration, isNot(TextDecoration.lineThrough));
    });

    // ── Checkbox tap calls toggleTaskDone ─────────────────────────────────

    testWidgets('tapping checkbox calls toggleTaskDone with task id',
        (tester) async {
      final mutations = _FakeMutations();
      await tester.pumpWidget(_wrap(_pendingTask, mutations: mutations));

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(mutations.toggledTaskId, 'task-1');
    });

    testWidgets('checkbox toggle failure shows offline snackbar', (tester) async {
      final mutations = _FakeMutations()..returnValue = false;
      await tester.pumpWidget(_wrap(_pendingTask, mutations: mutations));

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(find.text('Offline - writes disabled'), findsOneWidget);
    });

    // ── Popup menu ────────────────────────────────────────────────────────

    testWidgets('popup menu shows Edit and Delete options', (tester) async {
      await tester.pumpWidget(_wrap(_pendingTask));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    // ── Delete flow ───────────────────────────────────────────────────────

    testWidgets('delete: dialog appears on menu selection', (tester) async {
      final mutations = _FakeMutations();
      await tester.pumpWidget(_wrap(_pendingTask, mutations: mutations));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete task?'), findsOneWidget);
      expect(find.textContaining('"Book Shinkansen"'), findsOneWidget);
    });

    testWidgets('delete: cancel aborts without calling deleteTask',
        (tester) async {
      final mutations = _FakeMutations();
      await tester.pumpWidget(_wrap(_pendingTask, mutations: mutations));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(mutations.deletedTaskId, isNull);
    });

    testWidgets('delete: confirm calls deleteTask with task id', (tester) async {
      final mutations = _FakeMutations();
      await tester.pumpWidget(_wrap(_pendingTask, mutations: mutations));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Tap the 'Delete' FilledButton in the dialog (last instance).
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(mutations.deletedTaskId, 'task-1');
    });

    testWidgets('delete failure shows error snackbar', (tester) async {
      final mutations = _FakeMutations()..returnValue = false;
      await tester.pumpWidget(_wrap(_pendingTask, mutations: mutations));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('Failed to delete task'), findsOneWidget);
    });

    // ── Priority colours (structural — text presence) ─────────────────────

    testWidgets('critical priority renders its label', (tester) async {
      await tester.pumpWidget(_wrap(_doneTask));
      expect(find.text('critical'), findsOneWidget);
    });

    testWidgets('medium priority renders its label', (tester) async {
      await tester.pumpWidget(_wrap(_mediumTask));
      expect(find.text('medium'), findsOneWidget);
    });

    testWidgets('low priority renders its label', (tester) async {
      await tester.pumpWidget(_wrap(_lowPriorityTask));
      expect(find.text('low'), findsOneWidget);
    });
  });
}
