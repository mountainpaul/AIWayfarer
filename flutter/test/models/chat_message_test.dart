import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/chat_message.dart';

void main() {
  group('IterationStep', () {
    group('fromJson', () {
      test('maps label and content', () {
        final step = IterationStep.fromJson({
          'label': 'plan',
          'content': 'I will search for flights.',
        });

        expect(step.label, 'plan');
        expect(step.content, 'I will search for flights.');
      });
    });

    group('toJson round-trip', () {
      test('serialises and deserialises without data loss', () {
        const step = IterationStep(
          label: 'critique',
          content: 'Looks good, no issues found.',
        );

        // IterationStep.toJson() returns a clean Map — no nested Freezed objects.
        final json = step.toJson();
        final step2 = IterationStep.fromJson(json);

        expect(step2, equals(step));
      });
    });
  });

  group('ChatResponse', () {
    group('fromJson', () {
      test('maps all fields from JSON', () {
        final r = ChatResponse.fromJson({
          'answer': 'The flight departs at 9am.',
          'draft': 'Draft text here.',
          'critique': 'Critique text here.',
          'confidence': 'high',
          'sources': ['source-1', 'source-2'],
          'iterations': [
            {'label': 'plan', 'content': 'Planning...'},
            {'label': 'research', 'content': 'Researching...'},
          ],
        });

        expect(r.answer, 'The flight departs at 9am.');
        expect(r.draft, 'Draft text here.');
        expect(r.critique, 'Critique text here.');
        expect(r.confidence, 'high');
        expect(r.sources, ['source-1', 'source-2']);
        expect(r.iterations.length, 2);
        expect(r.iterations[0].label, 'plan');
        expect(r.iterations[0].content, 'Planning...');
        expect(r.iterations[1].label, 'research');
      });

      test('defaults apply when optional fields are omitted', () {
        final r = ChatResponse.fromJson({
          'answer': 'Simple answer.',
        });

        expect(r.answer, 'Simple answer.');
        expect(r.draft, '');
        expect(r.critique, '');
        expect(r.confidence, 'medium');
        expect(r.sources, isEmpty);
        expect(r.iterations, isEmpty);
      });

      test('empty iterations list when not provided', () {
        final r = ChatResponse.fromJson({
          'answer': 'Answer.',
          'confidence': 'low',
        });

        expect(r.iterations, isEmpty);
        expect(r.sources, isEmpty);
      });
    });

    group('toJson round-trip', () {
      // The generated toJson stores nested IterationStep objects directly (not
      // as Maps), so a bare toJson()→fromJson() would fail with a type cast
      // error. We go through jsonEncode/jsonDecode to simulate real network I/O,
      // which is the correct end-to-end round-trip path.
      test('serialises and deserialises without data loss via wire encoding', () {
        const r = ChatResponse(
          answer: 'Round trip answer.',
          draft: 'Some draft.',
          critique: 'Some critique.',
          confidence: 'high',
          sources: ['url-1'],
          iterations: [
            IterationStep(label: 'plan', content: 'Planning step.'),
          ],
        );

        final wire = jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>;
        final r2 = ChatResponse.fromJson(wire);

        expect(r2, equals(r));
      });
    });
  });

  group('ChatMessage', () {
    group('fromJson', () {
      test('maps all snake_case fields correctly', () {
        final m = ChatMessage.fromJson({
          'id': 'msg-1',
          'role': 'assistant',
          'content': 'Hello! How can I help?',
          'created_at': '2026-09-05T14:00:00Z',
          'iterations': [
            {'label': 'plan', 'content': 'Thinking...'},
          ],
          'confidence': 'high',
          'clarifying_question': 'Do you mean tonight?',
          'sources': ['source-a', 'source-b'],
        });

        expect(m.id, 'msg-1');
        expect(m.role, 'assistant');
        expect(m.content, 'Hello! How can I help?');
        expect(m.createdAt, '2026-09-05T14:00:00Z');
        expect(m.iterations.length, 1);
        expect(m.iterations[0].label, 'plan');
        expect(m.confidence, 'high');
        expect(m.clarifyingQuestion, 'Do you mean tonight?');
        expect(m.sources, ['source-a', 'source-b']);
      });

      test('defaults apply when optional fields are omitted', () {
        final m = ChatMessage.fromJson({
          'id': 'msg-2',
          'role': 'user',
          'content': 'What time is my flight?',
        });

        expect(m.createdAt, isNull);
        expect(m.iterations, isEmpty);
        expect(m.confidence, 'high');
        expect(m.clarifyingQuestion, isNull);
        expect(m.sources, isEmpty);
      });

      test('user role maps correctly', () {
        final m = ChatMessage.fromJson({
          'id': 'msg-3',
          'role': 'user',
          'content': 'Tell me about Kyoto temples.',
        });

        expect(m.role, 'user');
        expect(m.content, 'Tell me about Kyoto temples.');
      });
    });

    group('toJson round-trip', () {
      // Same as ChatResponse — go through jsonEncode/jsonDecode to ensure
      // nested IterationStep objects are properly serialised as Maps.
      test('serialises and deserialises without data loss via wire encoding', () {
        const m = ChatMessage(
          id: 'msg-rt',
          role: 'assistant',
          content: 'Round-trip message.',
          createdAt: '2026-09-05T15:00:00Z',
          iterations: [
            IterationStep(label: 'critique', content: 'All good.'),
          ],
          confidence: 'medium',
          clarifyingQuestion: 'Is that right?',
          sources: ['url-x'],
        );

        final wire = jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>;
        final m2 = ChatMessage.fromJson(wire);

        expect(m2, equals(m));
      });
    });
  });
}
