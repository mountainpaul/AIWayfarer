import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../providers/trip_provider.dart';
import 'widgets/trip_form.dart';

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

  static const _statusColors = {
    'planning': Colors.orange,
    'active': Colors.green,
    'completed': Colors.blueGrey,
  };

  Future<void> _addTrip(BuildContext context, WidgetRef ref) async {
    final payload = await showTripForm(context);
    if (payload == null) return;
    final ok = await ref.read(tripMutationsProvider).createTrip(payload);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create trip')),
      );
    }
  }

  Future<void> _setStatus(WidgetRef ref, String id, String status) =>
      ref.read(tripMutationsProvider).updateTrip(id, {'status': status});

  Future<void> _deleteTrip(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text('Remove "$name"? It can be restored from history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(tripMutationsProvider).deleteTrip(id);
    }
  }

  Widget _tripHeader(BuildContext context, WidgetRef ref, dynamic trip) {
    final color = _statusColors[trip.status] ?? Colors.grey;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.name,
                    style: Theme.of(context).textTheme.titleLarge),
                Text('${trip.startDate} – ${trip.endDate}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Chip(
            label: Text(trip.status, style: const TextStyle(fontSize: 12)),
            backgroundColor: color.withValues(alpha: 0.18),
            side: BorderSide(color: color),
            visualDensity: VisualDensity.compact,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') {
                _deleteTrip(context, ref, trip.id, trip.name);
              } else {
                _setStatus(ref, trip.id, v);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'planning', child: Text('Mark planning')),
              PopupMenuItem(value: 'active', child: Text('Mark active')),
              PopupMenuItem(value: 'completed', child: Text('Mark completed')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('Delete trip')),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legs = ref.watch(legsProvider);
    final trips = ref.watch(tripsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_trip',
        onPressed: () => _addTrip(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Trip'),
      ),
      body: RefreshIndicator(
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
              if (tripList.isEmpty) {
                return _refreshable(const Text('No trips yet. Tap + to add one.'));
              }
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.email_outlined),
                          tooltip: 'Scan email for bookings',
                          onPressed: () => context.go('/trips/scan-email'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.loyalty_outlined),
                          tooltip: 'Award travel & offers',
                          onPressed: () => context.go('/trips/awards'),
                        ),
                      ],
                    ),
                  ),
                  for (final trip in tripList) ...[
                    _tripHeader(context, ref, trip),
                    ...legList.where((l) => l.tripId == trip.id).map(
                          (l) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    WayfarerTheme.parseLegColor(l.color),
                                child: Text(l.emoji ?? l.name.substring(0, 1)),
                              ),
                              title: Text(l.name),
                              subtitle: Text('${l.startDate} - ${l.endDate}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go('/trips/leg/${l.id}'),
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 80), // clear the FAB
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
          loading: () => _refreshable(const CircularProgressIndicator()),
          error: (e, _) => _refreshable(Text('$e')),
        ),
      ),
    );
  }
}
