import 'package:flutter/material.dart';

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

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  Future<void> _pick(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_start == null || _end == null) return;
    Navigator.pop(context, {
      'name': _nameCtrl.text.trim(),
      'start_date': _fmt(_start!),
      'end_date': _fmt(_end!),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit trip' : 'New trip'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Trip name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(true),
                    child: Text(_start != null ? _fmt(_start!) : 'Start date'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(false),
                    child: Text(_end != null ? _fmt(_end!) : 'End date'),
                  ),
                ),
              ],
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
