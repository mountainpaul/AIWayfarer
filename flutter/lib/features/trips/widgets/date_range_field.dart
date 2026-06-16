import 'package:flutter/material.dart';

/// Format a date as YYYY-MM-DD (the backend's date format).
String fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One tap → a single date-range picker that captures BOTH start and end,
/// instead of two separate single-date dialogs (each needing tap→pick→save).
class DateRangeField extends StatelessWidget {
  const DateRangeField({
    super.key,
    required this.start,
    required this.end,
    required this.onPicked,
    this.label = 'Dates',
    this.hasError = false,
  });

  final DateTime? start;
  final DateTime? end;
  final void Function(DateTime start, DateTime end) onPicked;
  final String label;
  final bool hasError;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      initialDateRange: (start != null && end != null)
          ? DateTimeRange(start: start!, end: end!)
          : null,
    );
    if (picked != null) onPicked(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final has = start != null && end != null;
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () => _pick(context),
      icon: const Icon(Icons.date_range),
      style: hasError
          ? OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error),
            )
          : null,
      label: Text(has ? '${fmtDate(start!)}  →  ${fmtDate(end!)}' : label),
    );
  }
}
