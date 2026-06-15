import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/briefing.dart';

void main() {
  group('Briefing', () {
    group('fromJson', () {
      test('maps all fields correctly', () {
        final b = Briefing.fromJson({
          'id': 'brief-1',
          'date': '2026-09-05',
          'markdown': '# Morning Briefing\n\nToday you head to Kyoto.',
          'created_at': '2026-09-05T06:00:00Z',
        });

        expect(b.id, 'brief-1');
        expect(b.date, '2026-09-05');
        expect(b.markdown, contains('Morning Briefing'));
        expect(b.createdAt, '2026-09-05T06:00:00Z');
      });

      test('createdAt is null when omitted', () {
        final b = Briefing.fromJson({
          'id': 'brief-2',
          'date': '2026-09-06',
          'markdown': 'Short briefing.',
        });

        expect(b.id, 'brief-2');
        expect(b.date, '2026-09-06');
        expect(b.markdown, 'Short briefing.');
        expect(b.createdAt, isNull);
      });
    });

    group('toJson round-trip', () {
      test('serialises and deserialises without data loss', () {
        const b = Briefing(
          id: 'brief-rt',
          date: '2026-09-07',
          markdown: '## Day 7\n\nRest day.',
          createdAt: '2026-09-07T06:00:00Z',
        );

        final json = b.toJson();
        final b2 = Briefing.fromJson(json);

        expect(b2, equals(b));
      });
    });
  });
}
