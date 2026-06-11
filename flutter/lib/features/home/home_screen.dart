import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../providers/briefing_provider.dart';
import '../../providers/trip_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefing = ref.watch(briefingProvider);
    final currentLeg = ref.watch(currentLegProvider);
    final nextBooking = ref.watch(nextBookingProvider);
    final openTaskCount = ref.watch(openTaskCountProvider);

    return RefreshIndicator(
      onRefresh: () async {
        final ok = await refreshFromBackend(ref);
        ref.invalidate(briefingProvider);
        ref.invalidate(currentLegProvider);
        ref.invalidate(nextBookingProvider);
        ref.invalidate(openTaskCountProvider);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Backend unreachable — showing cached data')),
          );
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Briefing card. Backend returns markdown (spec §9). For v0.5 we
          // render as plain text — adding a markdown renderer is a polish
          // task tracked in MANUAL_TODO.
          briefing.when(
            data: (b) => b == null
                ? const _EmptyCard(text: 'No briefing yet. Pull to refresh.')
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        b.markdown,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(error: '$e'),
          ),

          // Current leg card
          currentLeg.when(
            data: (l) => l == null
                ? const _EmptyCard(text: 'No active leg today.')
                : Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: WayfarerTheme.parseLegColor(l.color),
                        child: Text(l.emoji ?? l.name.substring(0, 1)),
                      ),
                      title: Text(l.name),
                      subtitle: Text(
                          '${l.startDate} - ${l.endDate}\n${l.places ?? ''}'),
                      isThreeLine: true,
                    ),
                  ),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(error: '$e'),
          ),

          // Next booking card
          nextBooking.when(
            data: (b) => b == null
                ? const _EmptyCard(text: 'No upcoming bookings.')
                : Card(
                    child: ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(b.name),
                      subtitle: Text(_bookingSubtitle(b.startDate, b.locationName)),
                    ),
                  ),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(error: '$e'),
          ),

          // Open tasks card
          openTaskCount.when(
            data: (n) => Card(
              child: ListTile(
                leading: const Icon(Icons.checklist),
                title: Text('$n open tasks'),
                subtitle: const Text('Tap Trips to see and complete them.'),
              ),
            ),
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(error: '$e'),
          ),
        ],
      ),
    );
  }

  String _bookingSubtitle(String? start, String? loc) {
    final parts = <String>[];
    if (start != null) {
      try {
        final dt = DateTime.parse(start);
        parts.add(DateFormat.yMMMd().add_jm().format(dt));
      } catch (_) {
        parts.add(start);
      }
    }
    if (loc != null) parts.add(loc);
    return parts.join(' - ');
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer)),
        ),
      );
}
