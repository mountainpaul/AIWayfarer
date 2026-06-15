import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/chat_message.dart';
import 'package:wayfarer/providers/quiet_mode_provider.dart';
import 'package:wayfarer/features/chat/widgets/message_bubble.dart';

Widget _wrap(ChatMessage message, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );

void main() {
  group('MessageBubble — user messages', () {
    testWidgets('renders user message content', (tester) async {
      const msg = ChatMessage(
        id: 'u1',
        role: 'user',
        content: 'What flights are available?',
      );
      await tester.pumpWidget(_wrap(msg));
      await tester.pumpAndSettle();

      expect(find.text('What flights are available?'), findsOneWidget);
    });

    testWidgets('user message is right-aligned', (tester) async {
      const msg = ChatMessage(
        id: 'u1',
        role: 'user',
        content: 'Hello',
      );
      await tester.pumpWidget(_wrap(msg));
      await tester.pumpAndSettle();

      // The outermost Column inside MessageBubble's top-level Padding drives
      // alignment. Find the MessageBubble itself, then pick its first Column.
      final columns = tester.widgetList<Column>(
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.byType(Column),
        ),
      ).toList();
      expect(columns, isNotEmpty);
      expect(columns.first.crossAxisAlignment, CrossAxisAlignment.end);
    });

    testWidgets('does not show sources chip row for user message', (tester) async {
      const msg = ChatMessage(
        id: 'u1',
        role: 'user',
        content: 'Hello',
        sources: ['some-source.com'],
      );
      await tester.pumpWidget(_wrap(msg));
      await tester.pumpAndSettle();

      // Chip only renders for assistant messages with sources
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('does not show IterationPanel for user message', (tester) async {
      const msg = ChatMessage(
        id: 'u1',
        role: 'user',
        content: 'Hello',
        iterations: [IterationStep(label: 'Draft', content: 'step content')],
      );
      await tester.pumpWidget(_wrap(msg));
      await tester.pumpAndSettle();

      expect(find.text('Draft'), findsNothing);
    });
  });

  group('MessageBubble — assistant messages', () {
    testWidgets('renders assistant message content', (tester) async {
      const msg = ChatMessage(
        id: 'a1',
        role: 'assistant',
        content: 'Here is your flight information.',
      );
      await tester.pumpWidget(_wrap(msg));
      await tester.pumpAndSettle();

      expect(find.text('Here is your flight information.'), findsOneWidget);
    });

    testWidgets('assistant message is left-aligned', (tester) async {
      const msg = ChatMessage(
        id: 'a1',
        role: 'assistant',
        content: 'Hello there',
      );
      await tester.pumpWidget(_wrap(msg));
      await tester.pumpAndSettle();

      final columns = tester.widgetList<Column>(
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.byType(Column),
        ),
      ).toList();
      expect(columns, isNotEmpty);
      expect(columns.first.crossAxisAlignment, CrossAxisAlignment.start);
    });

    testWidgets('renders sources as Chips', (tester) async {
      const msg = ChatMessage(
        id: 'a1',
        role: 'assistant',
        content: 'Check this out.',
        sources: ['weather.com', 'flightaware.com'],
      );
      await tester.pumpWidget(_wrap(msg));
      await tester.pumpAndSettle();

      expect(find.text('weather.com'), findsOneWidget);
      expect(find.text('flightaware.com'), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(2));
    });

    testWidgets('shows no sources chips when sources list is empty', (tester) async {
      const msg = ChatMessage(
        id: 'a1',
        role: 'assistant',
        content: 'Simple reply.',
      );
      await tester.pumpWidget(_wrap(msg));
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('shows clarifying ActionChip when confidence=low and clarifyingQuestion set', (tester) async {
      const msg = ChatMessage(
        id: 'a1',
        role: 'assistant',
        content: 'Which airport do you mean?',
        confidence: 'low',
        clarifyingQuestion: 'Which airport do you mean?',
      );
      await tester.pumpWidget(_wrap(msg));
      await tester.pumpAndSettle();

      expect(find.byType(ActionChip), findsOneWidget);
      expect(find.text('Which airport do you mean?'), findsWidgets);
    });

    testWidgets('no ActionChip when confidence=high', (tester) async {
      const msg = ChatMessage(
        id: 'a1',
        role: 'assistant',
        content: 'Sure, no problem.',
        confidence: 'high',
      );
      await tester.pumpWidget(_wrap(msg));
      await tester.pumpAndSettle();

      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('no ActionChip when clarifyingQuestion is null even if confidence=low', (tester) async {
      const msg = ChatMessage(
        id: 'a1',
        role: 'assistant',
        content: 'Sure.',
        confidence: 'low',
      );
      await tester.pumpWidget(_wrap(msg));
      await tester.pumpAndSettle();

      expect(find.byType(ActionChip), findsNothing);
    });
  });

  group('MessageBubble — IterationPanel visibility', () {
    const msgWithSteps = ChatMessage(
      id: 'a2',
      role: 'assistant',
      content: 'Final answer.',
      iterations: [
        IterationStep(label: 'Draft', content: 'first draft text'),
        IterationStep(label: 'Critique', content: 'critique text'),
      ],
    );

    testWidgets('shows IterationPanel when quietMode=false and iterations non-empty', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        msgWithSteps,
        overrides: [
          quietModeProvider.overrideWith((_) => QuietModeNotifier(initial: false)),
        ],
      ));
      await tester.pumpAndSettle();

      // The ExpansionTile header is always visible
      expect(find.textContaining('Show reasoning'), findsOneWidget);
      expect(find.textContaining('2 steps'), findsOneWidget);
    });

    testWidgets('hides IterationPanel when quietMode=true', (tester) async {
      await tester.pumpWidget(_wrap(
        msgWithSteps,
        overrides: [
          quietModeProvider.overrideWith((_) => QuietModeNotifier(initial: true)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Show reasoning'), findsNothing);
    });

    testWidgets('no IterationPanel when iterations list is empty', (tester) async {
      const msg = ChatMessage(
        id: 'a3',
        role: 'assistant',
        content: 'No iterations.',
      );
      await tester.pumpWidget(_wrap(
        msg,
        overrides: [
          quietModeProvider.overrideWith((_) => QuietModeNotifier(initial: false)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Show reasoning'), findsNothing);
    });

    testWidgets('expanding IterationPanel shows step labels and content', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        msgWithSteps,
        overrides: [
          quietModeProvider.overrideWith((_) => QuietModeNotifier(initial: false)),
        ],
      ));
      await tester.pumpAndSettle();

      // Tap to expand the ExpansionTile
      await tester.tap(find.textContaining('Show reasoning'));
      await tester.pumpAndSettle();

      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('first draft text'), findsOneWidget);
      expect(find.text('Critique'), findsOneWidget);
      expect(find.text('critique text'), findsOneWidget);
    });
  });
}
