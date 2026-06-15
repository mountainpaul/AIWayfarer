import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/review_provider.dart';

/// Post-trip review (Step 3). Overall rating + per-booking ratings, pre-filled
/// from the trip's actual data. Submitting distills the traveler profile.
class PostTripReviewScreen extends ConsumerStatefulWidget {
  const PostTripReviewScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<PostTripReviewScreen> createState() =>
      _PostTripReviewScreenState();
}

const _paceOptions = <String, String>{
  'too_packed': 'Too packed',
  'just_right': 'Just right',
  'too_slow': 'Too slow',
};

class _PostTripReviewScreenState extends ConsumerState<PostTripReviewScreen> {
  int _overall = 0;
  String? _pace;
  final _highlight = TextEditingController();
  final _lowlight = TextEditingController();
  final _free = TextEditingController();

  // Per-item edit state, keyed by item index.
  final Map<int, int> _itemRatings = {};
  final Map<int, TextEditingController> _itemNotes = {};
  bool _submitting = false;

  @override
  void dispose() {
    _highlight.dispose();
    _lowlight.dispose();
    _free.dispose();
    for (final c in _itemNotes.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _noteFor(int i) =>
      _itemNotes.putIfAbsent(i, () => TextEditingController());

  Future<void> _submit(List<ReviewableItem> reviewables) async {
    setState(() => _submitting = true);
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < reviewables.length; i++) {
      final rating = _itemRatings[i] ?? 0;
      final note = (_itemNotes[i]?.text ?? '').trim();
      if (rating == 0 && note.isEmpty) continue; // skip untouched items
      final r = reviewables[i];
      final item = <String, dynamic>{
        'subject_type': r.subjectType,
        'subject_label': r.subjectLabel,
        if (r.bookingId != null) 'booking_id': r.bookingId,
        if (r.legId != null) 'leg_id': r.legId,
        if (rating > 0) 'rating': rating,
      };
      if (note.isNotEmpty) {
        // A low rating's note is a gripe; otherwise it's a positive.
        (rating > 0 && rating <= 2 ? item['disliked'] = note : item['liked'] = note);
      }
      items.add(item);
    }

    final payload = <String, dynamic>{
      'trip_id': widget.tripId,
      if (_overall > 0) 'overall_rating': _overall,
      if (_pace != null) 'pace_feedback': _pace,
      if (_highlight.text.trim().isNotEmpty) 'highlight': _highlight.text.trim(),
      if (_lowlight.text.trim().isNotEmpty) 'lowlight': _lowlight.text.trim(),
      if (_free.text.trim().isNotEmpty) 'free_text': _free.text.trim(),
      'items': items,
    };

    final ok = await ref.read(reviewMutationsProvider).submit(payload);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review saved — thanks!')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save — already reviewed, or backend unreachable')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(reviewableItemsProvider(widget.tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Review your trip')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (reviewables) => _form(reviewables),
      ),
    );
  }

  Widget _form(List<ReviewableItem> reviewables) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Overall', style: t.titleMedium),
        const SizedBox(height: 4),
        _Stars(value: _overall, onChanged: (v) => setState(() => _overall = v)),
        const SizedBox(height: 16),
        Text('Pace', style: t.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final e in _paceOptions.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _pace == e.key,
                onSelected: (sel) => setState(() => _pace = sel ? e.key : null),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _field(_highlight, 'Highlight', 'The best part of the trip'),
        const SizedBox(height: 12),
        _field(_lowlight, 'Lowlight', 'What you would change'),
        const SizedBox(height: 12),
        _field(_free, 'Anything else', 'Notes for next time'),
        const Divider(height: 32),
        Text('Rate what you did', style: t.titleMedium),
        const SizedBox(height: 4),
        if (reviewables.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No bookings on this trip to rate.',
                style: TextStyle(color: Colors.grey)),
          )
        else
          for (var i = 0; i < reviewables.length; i++) _itemCard(i, reviewables[i]),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submitting ? null : () => _submit(reviewables),
          icon: _submitting
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_outlined),
          label: Text(_submitting ? 'Saving…' : 'Submit review'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _itemCard(int i, ReviewableItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.subjectLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Chip(
                  label: Text(item.subjectType),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            _Stars(
              value: _itemRatings[i] ?? 0,
              onChanged: (v) => setState(() => _itemRatings[i] = v),
            ),
            TextField(
              controller: _noteFor(i),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Note (optional)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      maxLines: null,
    );
  }
}

/// A 1–5 star selector. Tapping the current value clears it back to 0.
class _Stars extends StatelessWidget {
  const _Stars({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var s = 1; s <= 5; s++)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(s <= value ? Icons.star : Icons.star_border),
            color: Colors.amber[700],
            onPressed: () => onChanged(s == value ? 0 : s),
          ),
      ],
    );
  }
}
