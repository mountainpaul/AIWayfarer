import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../providers/trip_provider.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legs = ref.watch(legsProvider);
    final trips = ref.watch(tripsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(syncTriggerProvider.notifier).state++;
      },
      child: legs.when(
        data: (legList) => trips.when(
          data: (tripList) {
            final tripName = tripList.isEmpty ? 'No trips' : tripList.first.name;
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(tripName,
                      style: Theme.of(context).textTheme.headlineSmall),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
