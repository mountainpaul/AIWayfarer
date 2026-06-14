import 'package:flutter/material.dart';

import '../../../models/booking.dart';
import '../../awards/award_search_sheet.dart';

const _bookingTypes = [
  'flight',
  'hotel',
  'ferry',
  'car',
  'train',
  'activity',
  'rifugio',
  'other',
];

const _bookingStatuses = [
  'booked',
  'pending',
  'needs_booking',
  'researching',
];

/// Shows a dialog to create or edit a booking.
/// Returns the payload map on save, or null on cancel.
Future<Map<String, dynamic>?> showBookingForm(
  BuildContext context, {
  required String legId,
  Booking? existing,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => _BookingFormDialog(legId: legId, existing: existing),
  );
}

class _BookingFormDialog extends StatefulWidget {
  const _BookingFormDialog({required this.legId, this.existing});
  final String legId;
  final Booking? existing;

  @override
  State<_BookingFormDialog> createState() => _BookingFormDialogState();
}

class _BookingFormDialogState extends State<_BookingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _notesCtrl;
  late String _type;
  late String _status;
  DateTime? _startDate;
  DateTime? _endDate;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _locationCtrl = TextEditingController(text: b?.locationName ?? '');
    _notesCtrl = TextEditingController(text: b?.notes ?? '');
    _type = b?.type ?? 'hotel';
    _status = b?.status ?? 'needs_booking';
    _startDate = b?.startDateTime;
    _endDate = b?.endDateTime;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = (isStart ? _startDate : _endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final payload = <String, dynamic>{
      'leg_id': widget.legId,
      'name': _nameCtrl.text.trim(),
      'type': _type,
      'status': _status,
      if (_startDate != null) 'start_date': _fmt(_startDate!),
      if (_endDate != null) 'end_date': _fmt(_endDate!),
      if (_locationCtrl.text.trim().isNotEmpty)
        'location_name': _locationCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };
    Navigator.pop(context, payload);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Booking' : 'New Booking'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  autofocus: !_isEditing,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _bookingTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _bookingStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
                // Consider points before booking: for an unbooked flight,
                // offer a jump into a pre-filled award search.
                if (_type == 'flight' &&
                    (_status == 'needs_booking' || _status == 'researching'))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => showAwardSearchSheet(
                          context,
                          legId: widget.legId,
                          date: _startDate,
                        ),
                        icon: const Icon(Icons.loyalty_outlined, size: 16),
                        label: const Text('Check award availability'),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(true),
                        child: Text(_startDate != null
                            ? _fmt(_startDate!)
                            : 'Start date'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(false),
                        child: Text(
                            _endDate != null ? _fmt(_endDate!) : 'End date'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(labelText: 'Location'),
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
