import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/trips/widgets/journal_tile.dart';
import 'package:wayfarer/models/journal_entry.dart';

// ---------------------------------------------------------------------------
// Sample models
// ---------------------------------------------------------------------------
const _noteEntry = JournalEntry(
  id: 'je-1',
  legId: 'leg-1',
  content: 'Amazing ramen today.',
  entryType: 'note',
  locationName: 'Ichiran Ramen Shinjuku',
  createdAt: '2026-09-05T12:30:00Z',
);

const _voiceEntry = JournalEntry(
  id: 'je-2',
  content: 'Recorded thoughts on the train.',
  entryType: 'voice',
  createdAt: '2026-09-06T08:00:00Z',
);

const _reflectionEntry = JournalEntry(
  id: 'je-3',
  content: 'A week in Tokyo — reflections.',
  entryType: 'reflection',
);

const _unknownTypeEntry = JournalEntry(
  id: 'je-4',
  content: 'Some other entry.',
  entryType: 'photo',
);

const _noTimestampEntry = JournalEntry(
  id: 'je-5',
  content: 'No timestamp here.',
  entryType: 'note',
  locationName: 'Kyoto',
);

const _malformedTimestampEntry = JournalEntry(
  id: 'je-6',
  content: 'Bad timestamp entry.',
  entryType: 'note',
  createdAt: 'not-a-real-date',
);

const _noLocationEntry = JournalEntry(
  id: 'je-7',
  content: 'Entry without location.',
  entryType: 'note',
  createdAt: '2026-09-07T10:00:00Z',
);

const _locationAndTimestampEntry = JournalEntry(
  id: 'je-8',
  content: 'At the shrine.',
  entryType: 'note',
  locationName: 'Fushimi Inari',
  createdAt: '2026-09-08T09:15:00Z',
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
Widget _wrap(JournalEntry entry) {
  return MaterialApp(
    home: Scaffold(
      body: JournalTile(entry: entry),
    ),
  );
}

void main() {
  group('JournalTile', () {
    // ── Rendering: content ────────────────────────────────────────────────

    testWidgets('renders entry content as title', (tester) async {
      await tester.pumpWidget(_wrap(_noteEntry));
      expect(find.text('Amazing ramen today.'), findsOneWidget);
    });

    testWidgets('renders voice entry content', (tester) async {
      await tester.pumpWidget(_wrap(_voiceEntry));
      expect(find.text('Recorded thoughts on the train.'), findsOneWidget);
    });

    // ── Icons for each entry type ─────────────────────────────────────────

    testWidgets('note type shows note icon', (tester) async {
      await tester.pumpWidget(_wrap(_noteEntry));
      expect(find.byIcon(Icons.note), findsOneWidget);
    });

    testWidgets('voice type shows mic icon', (tester) async {
      await tester.pumpWidget(_wrap(_voiceEntry));
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('reflection type shows auto_stories icon', (tester) async {
      await tester.pumpWidget(_wrap(_reflectionEntry));
      expect(find.byIcon(Icons.auto_stories), findsOneWidget);
    });

    testWidgets('unknown type falls back to note icon', (tester) async {
      await tester.pumpWidget(_wrap(_unknownTypeEntry));
      expect(find.byIcon(Icons.note), findsOneWidget);
    });

    // ── Subtitle: formatted timestamp ────────────────────────────────────

    testWidgets('renders formatted date when createdAt is a valid ISO-8601',
        (tester) async {
      await tester.pumpWidget(_wrap(_noteEntry));
      // DateFormat.yMMMd().add_jm() produces something like "Sep 5, 2026 12:30 PM"
      // We look for the year to confirm formatting ran.
      expect(find.textContaining('2026'), findsOneWidget);
    });

    testWidgets('falls back to raw string when createdAt is malformed',
        (tester) async {
      await tester.pumpWidget(_wrap(_malformedTimestampEntry));
      expect(find.textContaining('not-a-real-date'), findsOneWidget);
    });

    testWidgets('shows no date portion when createdAt is null', (tester) async {
      await tester.pumpWidget(_wrap(_reflectionEntry));
      // Only location/content; no year digits expected in subtitle when no date.
      // Reflection has no locationName either, so subtitle should be empty or
      // just not contain a year.
      expect(find.textContaining('2026'), findsNothing);
    });

    // ── Subtitle: location name ───────────────────────────────────────────

    testWidgets('renders location name in subtitle', (tester) async {
      await tester.pumpWidget(_wrap(_noteEntry));
      expect(find.textContaining('Ichiran Ramen Shinjuku'), findsOneWidget);
    });

    testWidgets('hides location separator when only timestamp present',
        (tester) async {
      await tester.pumpWidget(_wrap(_noLocationEntry));
      // No dash separator since location is absent.
      expect(find.textContaining(' - '), findsNothing);
    });

    testWidgets('hides location when absent but timestamp present',
        (tester) async {
      await tester.pumpWidget(_wrap(_noLocationEntry));
      // No location text beyond the date.
      expect(find.textContaining('Kyoto'), findsNothing);
    });

    testWidgets('shows both timestamp and location separated by dash',
        (tester) async {
      await tester.pumpWidget(_wrap(_locationAndTimestampEntry));
      expect(find.textContaining(' - '), findsOneWidget);
      expect(find.textContaining('Fushimi Inari'), findsOneWidget);
    });

    testWidgets('shows only location when timestamp is null', (tester) async {
      await tester.pumpWidget(_wrap(_noTimestampEntry));
      expect(find.textContaining('Kyoto'), findsOneWidget);
      // No separator because only one piece of info.
      expect(find.textContaining(' - '), findsNothing);
    });

    // ── Structural ────────────────────────────────────────────────────────

    testWidgets('tile is wrapped in a Card', (tester) async {
      await tester.pumpWidget(_wrap(_noteEntry));
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('tile uses a ListTile', (tester) async {
      await tester.pumpWidget(_wrap(_noteEntry));
      expect(find.byType(ListTile), findsOneWidget);
    });

    // ── No provider needed (StatelessWidget) ──────────────────────────────

    testWidgets('renders without ProviderScope — is a StatelessWidget',
        (tester) async {
      // JournalTile does not depend on Riverpod, so this must work directly.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JournalTile(
              entry: JournalEntry(
                id: 'je-plain',
                content: 'Plain test.',
                entryType: 'note',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Plain test.'), findsOneWidget);
      expect(find.byIcon(Icons.note), findsOneWidget);
    });
  });
}
