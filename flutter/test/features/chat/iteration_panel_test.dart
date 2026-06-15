import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/chat/widgets/iteration_panel.dart';
import 'package:wayfarer/models/chat_message.dart';

Widget _wrap(List<IterationStep> steps) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: IterationPanel(steps: steps),
        ),
      ),
    );

void _tallSurface(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 3000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  group('IterationPanel — header', () {
    testWidgets('shows step count in title', (tester) async {
      _tallSurface(tester);
      const steps = [
        IterationStep(label: 'Draft', content: 'draft body'),
        IterationStep(label: 'Critique', content: 'critique body'),
        IterationStep(label: 'Revised', content: 'revised body'),
      ];
      await tester.pumpWidget(_wrap(steps));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 steps'), findsOneWidget);
      expect(find.textContaining('Show reasoning'), findsOneWidget);
    });

    testWidgets('shows "1 steps" for single step', (tester) async {
      const steps = [IterationStep(label: 'Draft', content: 'body')];
      await tester.pumpWidget(_wrap(steps));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 steps'), findsOneWidget);
    });

    testWidgets('is collapsed by default — step content not visible', (tester) async {
      _tallSurface(tester);
      const steps = [
        IterationStep(label: 'Draft', content: 'This is draft content'),
        IterationStep(label: 'Critique', content: 'This is critique'),
      ];
      await tester.pumpWidget(_wrap(steps));
      await tester.pumpAndSettle();

      // Step content should NOT be visible before expansion
      expect(find.text('This is draft content'), findsNothing);
      expect(find.text('This is critique'), findsNothing);
    });

    testWidgets('uses ExpansionTile', (tester) async {
      const steps = [IterationStep(label: 'A', content: 'B')];
      await tester.pumpWidget(_wrap(steps));
      await tester.pumpAndSettle();

      expect(find.byType(ExpansionTile), findsOneWidget);
    });

    testWidgets('renders border decoration container', (tester) async {
      const steps = [IterationStep(label: 'A', content: 'B')];
      await tester.pumpWidget(_wrap(steps));
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsWidgets);
    });
  });

  group('IterationPanel — expanded state', () {
    testWidgets('expanding shows all step labels and content', (tester) async {
      _tallSurface(tester);
      const steps = [
        IterationStep(label: 'Draft', content: 'first draft text'),
        IterationStep(label: 'Critique', content: 'critique text'),
        IterationStep(label: 'Revised', content: 'revised text'),
      ];
      await tester.pumpWidget(_wrap(steps));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Show reasoning'));
      await tester.pumpAndSettle();

      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('first draft text'), findsOneWidget);
      expect(find.text('Critique'), findsOneWidget);
      expect(find.text('critique text'), findsOneWidget);
      expect(find.text('Revised'), findsOneWidget);
      expect(find.text('revised text'), findsOneWidget);
    });

    testWidgets('collapsing hides step content again', (tester) async {
      _tallSurface(tester);
      const steps = [
        IterationStep(label: 'Draft', content: 'draft body'),
      ];
      await tester.pumpWidget(_wrap(steps));
      await tester.pumpAndSettle();

      // Expand
      await tester.tap(find.textContaining('Show reasoning'));
      await tester.pumpAndSettle();
      expect(find.text('draft body'), findsOneWidget);

      // Collapse
      await tester.tap(find.textContaining('Show reasoning'));
      await tester.pumpAndSettle();
      expect(find.text('draft body'), findsNothing);
    });

    testWidgets('each step renders label bold via Text widget', (tester) async {
      _tallSurface(tester);
      const steps = [
        IterationStep(label: 'MyLabel', content: 'MyContent'),
      ];
      await tester.pumpWidget(_wrap(steps));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Show reasoning'));
      await tester.pumpAndSettle();

      final labelWidget = tester.widget<Text>(find.text('MyLabel'));
      expect(labelWidget.style?.fontWeight, FontWeight.bold);
    });
  });

  group('IterationPanel — two-step draft/critique pattern', () {
    testWidgets('renders draft then critique step in order', (tester) async {
      _tallSurface(tester);
      const steps = [
        IterationStep(label: 'Draft', content: 'My initial draft'),
        IterationStep(label: 'Critique', content: 'Needs improvement'),
      ];
      await tester.pumpWidget(_wrap(steps));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Show reasoning'));
      await tester.pumpAndSettle();

      final allText = tester.allWidgets
          .whereType<Text>()
          .map((w) => w.data ?? '')
          .toList();

      final draftIdx = allText.indexOf('Draft');
      final critiqueIdx = allText.indexOf('Critique');
      expect(draftIdx, lessThan(critiqueIdx));
    });
  });
}
