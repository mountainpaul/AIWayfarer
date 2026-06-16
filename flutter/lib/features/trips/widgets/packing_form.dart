import 'package:flutter/material.dart';

/// Add a packing item. Returns a create payload, or null if cancelled.
Future<Map<String, dynamic>?> showPackingForm(
  BuildContext context, {
  required String tripId,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _PackingFormDialog(tripId: tripId),
  );
}

const _categories = <String>[
  'clothing',
  'layers',
  'footwear',
  'toiletries',
  'electronics',
  'documents',
  'gear',
  'misc',
];

class _PackingFormDialog extends StatefulWidget {
  const _PackingFormDialog({required this.tripId});
  final String tripId;

  @override
  State<_PackingFormDialog> createState() => _PackingFormDialogState();
}

class _PackingFormDialogState extends State<_PackingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _category = 'misc';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'trip_id': widget.tripId,
      'name': _nameCtrl.text.trim(),
      'category': _category,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add packing item'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Item'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'misc'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
