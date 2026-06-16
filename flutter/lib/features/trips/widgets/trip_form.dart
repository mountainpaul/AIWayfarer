import 'package:flutter/material.dart';

import 'date_range_field.dart';

/// Shows the add/edit-trip dialog. Returns a create/update payload map, or null
/// if cancelled. [existing] (a Trip-shaped map) prefills for editing.
Future<Map<String, dynamic>?> showTripForm(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _TripFormDialog(existing: existing),
  );
}

class _TripFormDialog extends StatefulWidget {
  const _TripFormDialog({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_TripFormDialog> createState() => _TripFormDialogState();
}

class _TripFormDialogState extends State<_TripFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  DateTime? _start;
  DateTime? _end;
  bool _datesError = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name'] as String? ?? '');
    if (e?['start_date'] != null) _start = DateTime.tryParse(e!['start_date']);
    if (e?['end_date'] != null) _end = DateTime.tryParse(e!['end_date']);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final nameOk = _formKey.currentState!.validate();
    final datesOk = _start != null && _end != null;
    if (!datesOk) setState(() => _datesError = true);
    if (!nameOk || !datesOk) return;
    Navigator.pop(context, {
      'name': _nameCtrl.text.trim(),
      'start_date': fmtDate(_start!),
      'end_date': fmtDate(_end!),
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_isEditing ? 'Edit trip' : 'New trip'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Trip name'),
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
          ],
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
