import 'package:flutter/material.dart';

import '../../../models/task.dart';

const _priorities = ['critical', 'high', 'medium', 'low'];

/// Shows a dialog to create or edit a task.
/// Returns the payload map on save, or null on cancel.
Future<Map<String, dynamic>?> showTaskForm(
  BuildContext context, {
  required String legId,
  Task? existing,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => _TaskFormDialog(legId: legId, existing: existing),
  );
}

class _TaskFormDialog extends StatefulWidget {
  const _TaskFormDialog({required this.legId, this.existing});
  final String legId;
  final Task? existing;

  @override
  State<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<_TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late String _priority;
  DateTime? _dueDate;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _notesCtrl = TextEditingController(text: t?.notes ?? '');
    _priority = t?.priority ?? 'medium';
    _dueDate = t?.dueDateTime;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final payload = <String, dynamic>{
      'leg_id': widget.legId,
      'title': _titleCtrl.text.trim(),
      'priority': _priority,
      if (_dueDate != null) 'due_date': _fmt(_dueDate!),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };
    Navigator.pop(context, payload);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Task' : 'New Task'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  autofocus: !_isEditing,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: _priorities
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _pickDueDate,
                  child: Text(
                      _dueDate != null ? 'Due: ${_fmt(_dueDate!)}' : 'Set due date'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
