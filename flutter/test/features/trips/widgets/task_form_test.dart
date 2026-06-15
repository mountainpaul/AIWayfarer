// task_form shows a dialog that returns a payload map via Navigator.pop.
// No provider mutations are called directly by the form.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/trips/widgets/task_form.dart';
import 'package:wayfarer/models/task.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required String legId,
  Task? existing,
  required List<Map<String, dynamic>?> results,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            child: const Text('Open'),
            onPressed: () async {
              final r = await showTaskForm(ctx, legId: legId, existing: existing);
              results.add(r);
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TaskForm — create mode', () {
    testWidgets('renders New Task title with Create and Cancel buttons', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, legId: 'leg1', results: []);

      expect(find.text('New Task'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('shows Required error when title is empty on submit', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', results: results);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('submitting valid title returns payload with leg_id and title', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg-99', results: results);

      await tester.enterText(find.byType(TextFormField).first, 'Book transfer');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final p = results.first!;
      expect(p['leg_id'], equals('leg-99'));
      expect(p['title'], equals('Book transfer'));
      expect(p['priority'], isA<String>());
    });

    testWidgets('notes absent from payload when left blank', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', results: results);

      await tester.enterText(find.byType(TextFormField).first, 'My Task');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.first!.containsKey('notes'), isFalse);
    });

    testWidgets('notes included in payload when filled', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', results: results);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'My Task');
      await tester.enterText(fields.at(1), 'Remember passport');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.first!['notes'], equals('Remember passport'));
    });

    testWidgets('due_date absent from payload when not picked', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', results: results);

      await tester.enterText(find.byType(TextFormField).first, 'No date task');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(results.first!.containsKey('due_date'), isFalse);
    });

    testWidgets('Cancel returns null', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', results: results);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.first, isNull);
    });

    testWidgets('changing priority dropdown changes priority in payload', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', results: results);

      // Default priority is 'medium'. Change to 'critical'.
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('critical').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Critical task');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.first!['priority'], equals('critical'));
    });

    testWidgets('Set due date button is visible', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, legId: 'leg1', results: []);
      expect(find.text('Set due date'), findsOneWidget);
    });
  });

  group('TaskForm — edit mode', () {
    const existingTask = Task(
      id: 't-1',
      legId: 'leg1',
      title: 'Book taxi',
      priority: 'high',
      dueDate: '2026-08-15',
      notes: 'Early morning',
    );

    testWidgets('renders Edit Task title prefilled with existing values', (tester) async {
      _tallSurface(tester);
      await _pumpHost(tester, legId: 'leg1', existing: existingTask, results: []);

      expect(find.text('Edit Task'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Book taxi'), findsOneWidget);
      expect(find.text('Early morning'), findsOneWidget);
      // Date is shown on the due date button.
      expect(find.textContaining('2026-08-15'), findsOneWidget);
    });

    testWidgets('editing title produces updated payload', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', existing: existingTask, results: results);

      await tester.enterText(find.byType(TextFormField).first, 'Book shuttle');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      final p = results.first!;
      expect(p['title'], equals('Book shuttle'));
      expect(p['priority'], equals('high'));
      expect(p['due_date'], equals('2026-08-15'));
      expect(p['notes'], equals('Early morning'));
    });

    testWidgets('validation fires in edit mode when title is cleared', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', existing: existingTask, results: results);

      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('Cancel returns null in edit mode', (tester) async {
      _tallSurface(tester);
      final results = <Map<String, dynamic>?>[];
      await _pumpHost(tester, legId: 'leg1', existing: existingTask, results: results);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.first, isNull);
    });
  });
}
