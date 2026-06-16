import 'package:flutter/material.dart';

import 'date_range_field.dart';

/// Add (or edit) a leg. Returns a create/update payload, or null if cancelled.
/// The slug is generated server-side from the name, so it isn't asked for here.
Future<Map<String, dynamic>?> showLegForm(
  BuildContext context, {
  required String tripId,
  required int sortOrder,
  Map<String, dynamic>? existing,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _LegFormDialog(
      tripId: tripId,
      sortOrder: sortOrder,
      existing: existing,
    ),
  );
}

class _LegFormDialog extends StatefulWidget {
  const _LegFormDialog({
    required this.tripId,
    required this.sortOrder,
    this.existing,
  });

  final String tripId;
  final int sortOrder;
  final Map<String, dynamic>? existing;

  @override
  State<_LegFormDialog> createState() => _LegFormDialogState();
}

class _LegFormDialogState extends State<_LegFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _placesCtrl;
  late final TextEditingController _notesCtrl;
  DateTime? _start;
  DateTime? _end;
  bool _schengen = false;
  bool _datesError = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name'] as String? ?? '');
    _placesCtrl = TextEditingController(text: e?['places'] as String? ?? '');
    _notesCtrl = TextEditingController(text: e?['notes'] as String? ?? '');
    if (e?['start_date'] != null) _start = DateTime.tryParse(e!['start_date']);
    if (e?['end_date'] != null) _end = DateTime.tryParse(e!['end_date']);
    _schengen = (e?['is_schengen'] as bool?) ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _placesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final nameOk = _formKey.currentState!.validate();
    final datesOk = _start != null && _end != null;
    if (!datesOk) setState(() => _datesError = true);
    if (!nameOk || !datesOk) return;

    final places = _placesCtrl.text.trim();
    final notes = _notesCtrl.text.trim();
    Navigator.pop(context, {
      'trip_id': widget.tripId,
      'name': _nameCtrl.text.trim(),
      'start_date': fmtDate(_start!),
      'end_date': fmtDate(_end!),
      'is_schengen': _schengen,
      if (places.isNotEmpty) 'places': places,
      if (notes.isNotEmpty) 'notes': notes,
      'sort_order': widget.sortOrder,
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_isEditing ? 'Edit leg' : 'New leg'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Leg name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DateRangeField(
                start: _start,
                end: _end,
                hasError: _datesError,
                label: 'Pick dates',
                onPicked: (s, e) => setState(() {
                  _start = s;
                  _end = e;
                  _datesError = false;
                }),
              ),
              if (_datesError)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Pick a date range',
                      style: TextStyle(color: scheme.error, fontSize: 12)),
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _placesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Places (optional)',
                  hintText: 'e.g. Innsbruck, Hall in Tirol',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Schengen area'),
                value: _schengen,
                onChanged: (v) => setState(() => _schengen = v),
              ),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
