import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/trip_provider.dart';
import '../../services/api_client.dart';
import '../../services/sync_service.dart';

/// Screen to scan Gmail for booking confirmations and import them.
class EmailScanScreen extends ConsumerStatefulWidget {
  const EmailScanScreen({super.key});

  @override
  ConsumerState<EmailScanScreen> createState() => _EmailScanScreenState();
}

class _EmailScanScreenState extends ConsumerState<EmailScanScreen> {
  bool _scanning = false;
  String? _error;
  List<Map<String, dynamic>> _candidates = [];
  final Set<int> _selected = {};
  bool _importing = false;
  int? _importedCount;

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _candidates = [];
      _selected.clear();
      _importedCount = null;
    });

    try {
      final result = await ref.read(apiClientProvider).scanBookingEmails();
      final raw = result['candidates'] as List<dynamic>? ?? [];
      final candidates = raw.cast<Map<String, dynamic>>();

      setState(() {
        _scanning = false;
        _candidates = candidates;
        // Pre-select all that don't already exist
        for (var i = 0; i < candidates.length; i++) {
          if (candidates[i]['already_exists'] != true) {
            _selected.add(i);
          }
        }
      });
    } catch (e) {
      setState(() {
        _scanning = false;
        _error = '$e';
      });
    }
  }

  Future<void> _import() async {
    if (_selected.isEmpty) return;

    setState(() => _importing = true);

    final toImport = _selected.map((i) => _candidates[i]).toList();

    try {
      final result = await ref.read(apiClientProvider).importBookings(toImport);
      final count = result['imported'] as int? ?? 0;

      // Refresh local data
      await ref.read(syncServiceProvider).snapshot();
      ref.read(syncTriggerProvider.notifier).state++;

      setState(() {
        _importing = false;
        _importedCount = count;
        // Mark imported ones as existing
        for (final i in _selected) {
          _candidates[i]['already_exists'] = true;
        }
        _selected.clear();
      });
    } catch (e) {
      setState(() {
        _importing = false;
        _error = 'Import failed: $e';
      });
    }
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'flight':
        return Icons.flight;
      case 'hotel':
      case 'rifugio':
        return Icons.hotel;
      case 'ferry':
        return Icons.directions_boat;
      case 'car':
        return Icons.directions_car;
      case 'train':
        return Icons.train;
      case 'activity':
        return Icons.attractions;
      default:
        return Icons.bookmark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Email for Bookings'),
        actions: [
          if (_candidates.isNotEmpty && _selected.isNotEmpty)
            TextButton.icon(
              onPressed: _importing ? null : _import,
              icon: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text('Import ${_selected.length}'),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_scanning) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning emails and parsing with AI...'),
            SizedBox(height: 8),
            Text('This may take 30-60 seconds.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(onPressed: _scan, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.email_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Scan your Gmail for booking confirmations\n'
                '(flights, trains, hotels, ferries)',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.search),
                label: const Text('Scan Emails'),
              ),
              if (_importedCount != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Successfully imported $_importedCount bookings.',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_importedCount != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.green.shade50,
            child: Text(
              'Imported $_importedCount bookings successfully.',
              style: TextStyle(color: Colors.green.shade800),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('${_candidates.length} bookings found',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selected.length == _candidates.length) {
                      _selected.clear();
                    } else {
                      _selected.clear();
                      for (var i = 0; i < _candidates.length; i++) {
                        if (_candidates[i]['already_exists'] != true) {
                          _selected.add(i);
                        }
                      }
                    }
                  });
                },
                child: Text(_selected.length == _candidates.length
                    ? 'Deselect All'
                    : 'Select All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _candidates.length,
            itemBuilder: (context, i) {
              final c = _candidates[i];
              final exists = c['already_exists'] == true;
              return CheckboxListTile(
                value: _selected.contains(i),
                onChanged: exists
                    ? null
                    : (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(i);
                          } else {
                            _selected.remove(i);
                          }
                        });
                      },
                secondary: Icon(_iconFor(c['type'] as String?)),
                title: Text(
                  c['name'] as String? ?? 'Unknown',
                  style: TextStyle(
                    decoration: exists ? TextDecoration.lineThrough : null,
                    color: exists ? Colors.grey : null,
                  ),
                ),
                subtitle: Text(
                  [
                    if (c['start_date'] != null) c['start_date'],
                    if (c['location_name'] != null) c['location_name'],
                    if (c['confirmation'] != null) 'Ref: ${c['confirmation']}',
                    if (exists) '(already imported)',
                  ].join(' · '),
                  style: TextStyle(
                    color: exists ? Colors.grey : null,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
