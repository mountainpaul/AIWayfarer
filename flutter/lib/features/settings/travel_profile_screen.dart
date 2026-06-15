import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/traveler_profile.dart';
import '../../providers/profile_provider.dart';

/// Travel Profile questionnaire (Step 2). Editable any time — feeds the
/// backend `traveler_profile`, whose distilled summary grounds chat planning.
///
/// Standardized token vocabularies for the four typed columns. Values match the
/// examples documented on the backend column comments; kept here as the single
/// source of truth for the dropdowns.
const _lodgingOptions = <String>[
  'boutique',
  'luxury',
  'hotel_chain',
  'budget_guesthouse',
  'hostel',
  'vacation_rental',
];
const _transportOptions = <String>[
  'rental_car',
  'public_transit',
  'trains',
  'rideshare',
  'walking',
];
const _paceOptions = <String>['relaxed', 'moderate', 'packed'];
const _budgetOptions = <String>['economy', 'mid_range', 'splurge'];
const _interestOptions = <String>[
  'food',
  'history',
  'hiking',
  'museums',
  'nightlife',
  'beaches',
  'shopping',
  'photography',
  'local_culture',
  'nature',
];

String _humanize(String token) =>
    token.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

class TravelProfileScreen extends ConsumerStatefulWidget {
  const TravelProfileScreen({super.key});

  @override
  ConsumerState<TravelProfileScreen> createState() =>
      _TravelProfileScreenState();
}

class _TravelProfileScreenState extends ConsumerState<TravelProfileScreen> {
  // Local edit state, seeded once from the loaded profile.
  bool _seeded = false;
  String? _lodging;
  String? _transport;
  String? _pace;
  String? _budget;
  final Set<String> _interests = {};
  final _avoidsController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _avoidsController.dispose();
    super.dispose();
  }

  void _seed(TravelerProfile p) {
    _lodging = p.lodgingStyle;
    _transport = p.transportPreference;
    _pace = p.travelPace;
    _budget = p.budgetTier;
    _interests
      ..clear()
      ..addAll(p.interests);
    _avoidsController.text = p.avoids.join(', ');
    _seeded = true;
  }

  Future<void> _save(TravelerProfile current) async {
    setState(() => _saving = true);
    final avoids = _avoidsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    // Preserve any unknown blob keys; only overwrite the two we manage.
    final blob = Map<String, dynamic>.from(current.preferencesBlob)
      ..['interests'] = _interests.toList()
      ..['avoids'] = avoids;
    final patch = <String, dynamic>{
      'lodging_style': _lodging,
      'transport_preference': _transport,
      'travel_pace': _pace,
      'budget_tier': _budget,
      'preferences_blob': blob,
    };
    final ok = await ref.read(profileMutationsProvider).update(patch);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Travel profile saved' : 'Could not save — backend unreachable'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Profile')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Backend unreachable. Connect to load and edit your travel profile.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!_seeded) _seed(profile);
          return _form(profile);
        },
      ),
    );
  }

  Widget _form(TravelerProfile profile) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _dropdown('Lodging style', _lodgingOptions, _lodging,
            (v) => setState(() => _lodging = v)),
        const SizedBox(height: 12),
        _dropdown('Transport preference', _transportOptions, _transport,
            (v) => setState(() => _transport = v)),
        const SizedBox(height: 12),
        _dropdown('Travel pace', _paceOptions, _pace,
            (v) => setState(() => _pace = v)),
        const SizedBox(height: 12),
        _dropdown('Budget tier', _budgetOptions, _budget,
            (v) => setState(() => _budget = v)),
        const Divider(height: 32),
        Text('Interests', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final i in _interestOptions)
              FilterChip(
                label: Text(_humanize(i)),
                selected: _interests.contains(i),
                onSelected: (sel) => setState(() {
                  sel ? _interests.add(i) : _interests.remove(i);
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _avoidsController,
          decoration: const InputDecoration(
            labelText: 'Avoids',
            border: OutlineInputBorder(),
            helperText: 'Comma-separated, e.g. 5am flights, long layovers',
          ),
        ),
        const Divider(height: 32),
        _summaryCard(profile),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : () => _save(profile),
          icon: _saving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving…' : 'Save profile'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _dropdown(String label, List<String> options, String? value,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('—')),
        for (final o in options)
          DropdownMenuItem<String>(value: o, child: Text(_humanize(o))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _summaryCard(TravelerProfile profile) {
    final summary = (profile.profileSummary ?? '').trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, size: 18),
                SizedBox(width: 8),
                Text('AI-learned summary',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summary.isEmpty
                  ? 'No summary yet. It will be distilled from your preferences and post-trip reviews.'
                  : summary,
              style: TextStyle(
                color: summary.isEmpty ? Colors.grey : null,
                fontStyle: summary.isEmpty ? FontStyle.italic : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
