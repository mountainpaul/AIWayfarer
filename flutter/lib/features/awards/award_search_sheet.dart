import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/leg.dart';
import '../../providers/trip_provider.dart';
import '../../services/award_search.dart';

/// Bottom sheet that builds pre-filled award-search links for a leg's route
/// and dates and opens them in the browser.
Future<void> showAwardSearchSheet(
  BuildContext context, {
  required String legId,
  DateTime? date,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _AwardSearchSheet(legId: legId, date: date),
    ),
  );
}

class _AwardSearchSheet extends ConsumerStatefulWidget {
  const _AwardSearchSheet({required this.legId, this.date});
  final String legId;
  final DateTime? date;

  @override
  ConsumerState<_AwardSearchSheet> createState() => _AwardSearchSheetState();
}

class _AwardSearchSheetState extends ConsumerState<_AwardSearchSheet> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _date = widget.date;
    _prefill();
  }

  Future<void> _prefill() async {
    final (origin, dest) = await LegAirportMemory.load(widget.legId);
    if (!mounted) return;
    setState(() {
      _originCtrl.text = origin ?? ref.read(homeAirportProvider);
      if (dest != null) _destCtrl.text = dest;
    });
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  bool get _ready =>
      _originCtrl.text.trim().length == 3 &&
      _destCtrl.text.trim().length == 3 &&
      _date != null;

  Future<void> _open(AwardEngineLink link) async {
    await LegAirportMemory.save(
        widget.legId, _originCtrl.text, _destCtrl.text);
    final ok = await launchUrl(link.url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${link.engine}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final legAsync = ref.watch(legProvider(widget.legId));
    // Default the search date to the leg's start date once loaded.
    legAsync.whenData((leg) {
      if (_date == null && leg != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _date == null) {
            setState(() => _date = leg.startDateTime);
          }
        });
      }
    });

    final links = _ready
        ? buildAwardLinks(
            origin: _originCtrl.text,
            destination: _destCtrl.text,
            date: _date!,
          )
        : const <AwardEngineLink>[];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search award availability',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Opens a live, pre-filled search. PointsYeah and Roame need a '
              'free account to show results.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _originCtrl,
                    decoration: const InputDecoration(
                      labelText: 'From (IATA)',
                      hintText: 'DEN',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _destCtrl,
                    decoration: const InputDecoration(
                      labelText: 'To (IATA)',
                      hintText: 'FCO',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_date == null
                  ? 'Pick date'
                  : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')} (±3 days)'),
            ),
            const SizedBox(height: 16),
            if (!_ready)
              Text(
                'Enter 3-letter airport codes and a date.',
                style: TextStyle(color: Theme.of(context).hintColor),
              )
            else
              ...links.map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton.tonalIcon(
                      onPressed: () => _open(l),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text('Search on ${l.engine}'),
                    ),
                  )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
