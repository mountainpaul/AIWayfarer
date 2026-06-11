import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../providers/trip_provider.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  /// Loading/error states must stay scrollable or the pull-to-refresh
  /// gesture is dead exactly when a retry is most needed.
  static Widget _refreshable(Widget center) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(child: center),
        ],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legs = ref.watch(legsProvider);
    final trips = ref.watch(tripsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        final ok = await refreshFromBackend(ref);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Backend unreachable — showing cached data')),
          );
        }
      },
      child: legs.when(
        data: (legList) => trips.when(
          data: (tripList) {
            final tripName = tripList.isEmpty ? 'No trips' : tripList.first.name;
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(tripName,
                            style: Theme.of(context).textTheme.headlineSmall),
                      ),
                      IconButton(
                        icon: const Icon(Icons.email_outlined),
                        tooltip: 'Scan email for bookings',
                        onPressed: () => context.go('/trips/scan-email'),
                      ),
                    ],
                  ),
                ),
                ...legList.map((l) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: WayfarerTheme.parseLegColor(l.color),
                          child: Text(l.emoji ?? l.name.substring(0, 1)),
                        ),
                        title: Text(l.name),
                        subtitle: Text('${l.startDate} - ${l.endDate}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/trips/leg/${l.id}'),
                      ),
                    )),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        ),
        loading: () => _refreshable(const CircularProgressIndicator()),
        error: (e, _) => _refreshable(Text('$e')),
      ),
    );
  }
}
