import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../providers/grounding_provider.dart';
import '../../providers/trip_provider.dart';

/// Companion mode dashboard - "where am I / what's next / open issues" (§1).
class CompanionDashboard extends ConsumerWidget {
  const CompanionDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grounding = ref.watch(groundingProvider);
    final currentLeg = ref.watch(currentLegProvider);
    final nextBooking = ref.watch(nextBookingProvider);
    final openTasks = ref.watch(openTaskCountProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(groundingProvider);
        ref.invalidate(currentLegProvider);
        ref.invalidate(nextBookingProvider);
        ref.invalidate(openTaskCountProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Where am I',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  grounding.when(
                    data: (g) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (g.gpsLat != null && g.gpsLon != null)
                          Text(
                              'GPS: ${g.gpsLat!.toStringAsFixed(4)}, ${g.gpsLon!.toStringAsFixed(4)}'
                              '${g.gpsAccuracyM != null ? ' (+/- ${g.gpsAccuracyM!.toStringAsFixed(0)}m)' : ''}')
                        else
                          const Text('GPS unavailable'),
                        Text('Local: ${g.localTimeIso}'),
                        if (g.timezone != null) Text('TZ: ${g.timezone}'),
                      ],
                    ),
                    loading: () =>
                        const SizedBox(height: 32, child: LinearProgressIndicator()),
                    error: (e, _) => Text('$e'),
                  ),
                ],
              ),
            ),
          ),
          currentLeg.when(
            data: (l) => l == null
                ? const SizedBox.shrink()
                : Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: WayfarerTheme.parseLegColor(l.color),
                        child: Text(l.emoji ?? l.name.substring(0, 1)),
                      ),
                      title: Text('Current leg: ${l.name}'),
                      subtitle: Text(l.places ?? ''),
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          nextBooking.when(
            data: (b) => b == null
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No upcoming booking on this leg.'),
                    ),
                  )
                : Card(
                    child: ListTile(
                      leading: const Icon(Icons.event),
                      title: Text('Next: ${b.name}'),
                      subtitle: Text(
                        [
                          if (b.startDate != null)
                            _fmt(b.startDate!),
                          if (b.locationName != null) b.locationName,
                        ].whereType<String>().join(' - '),
                      ),
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          openTasks.when(
            data: (n) => Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: Text('$n open tasks'),
                subtitle: const Text('See Trips for details.'),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _fmt(String iso) {
    try {
      return DateFormat.MMMd().add_jm().format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }
}
