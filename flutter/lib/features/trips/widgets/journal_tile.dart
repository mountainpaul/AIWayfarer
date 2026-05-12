import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/journal_entry.dart';

class JournalTile extends StatelessWidget {
  const JournalTile({required this.entry, super.key});

  final JournalEntry entry;

  IconData _iconFor(String type) {
    switch (type) {
      case 'voice':
        return Icons.mic;
      case 'reflection':
        return Icons.auto_stories;
      case 'note':
      default:
        return Icons.note;
    }
  }

  @override
  Widget build(BuildContext context) {
    String? when;
    if (entry.createdAt != null) {
      try {
        when = DateFormat.yMMMd()
            .add_jm()
            .format(DateTime.parse(entry.createdAt!).toLocal());
      } catch (_) {
        when = entry.createdAt;
      }
    }

    return Card(
      child: ListTile(
        leading: Icon(_iconFor(entry.entryType)),
        title: Text(entry.content),
        subtitle: Text(
          [if (when != null) when, entry.locationName].whereType<String>().join(' - '),
        ),
      ),
    );
  }
}
