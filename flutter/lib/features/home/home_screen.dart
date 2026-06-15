import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/trip.dart';
import '../../providers/briefing_provider.dart';
import '../../providers/review_provider.dart';
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
          // Post-trip review prompt — shown when a completed trip has no review.
          ref.watch(tripsNeedingReviewProvider).maybeWhen(
            data: (trips) => trips.isEmpty
                ? const SizedBox.shrink()
                : _ReviewPromptCard(trip: trips.first),
            orElse: () => const SizedBox.shrink(),
          ),

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

          // Schengen 90/180 card (server-computed; hidden when offline or no
          // Schengen days). Surfaces a warning well before an overstay.
          ref.watch(schengenProvider).maybeWhen(
            data: (s) => (s == null || (s['peak_days'] ?? 0) == 0)
                ? const SizedBox.shrink()
                : _SchengenCard(report: s),
            orElse: () => const SizedBox.shrink(),
          ),

          // Accommodation-coverage card (server-computed; hidden when offline).
          ref.watch(coverageProvider).maybeWhen(
            data: (items) =>
                items == null || items.isEmpty
                    ? const SizedBox.shrink()
                    : _CoverageCard(items: items),
            orElse: () => const SizedBox.shrink(),
          ),

          // Budget rollup card (server-computed; hidden when offline).
          ref.watch(budgetProvider).maybeWhen(
            data: (b) {
              final lines = (b?['by_currency'] as List?) ?? const [];
              return lines.isEmpty
                  ? const SizedBox.shrink()
                  : _BudgetCard(lines: lines.cast<Map<String, dynamic>>());
            },
            orElse: () => const SizedBox.shrink(),
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

class _SchengenCard extends StatelessWidget {
  const _SchengenCard({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final status = report['status'] as String? ?? 'ok';
    final used = report['days_used'] ?? 0;
    final limit = report['limit_days'] ?? 90;
    final remaining = report['days_remaining'] ?? 0;
    final color = switch (status) {
      'exceeded' => Colors.red,
      'warning' => Colors.orange,
      _ => Colors.green,
    };
    final detail = StringBuffer('$remaining of $limit days remaining');
    if (report['ever_exceeds'] == true) {
      detail.write(' · ⚠ exceeds 90 by ${report['peak_date']}');
    } else if (status != 'ok') {
      detail.write(' · approaching the limit');
    }
    return Card(
      child: ListTile(
        leading: Icon(Icons.flight_takeoff, color: color),
        title: Text('Schengen: $used / $limit days used'),
        subtitle: Text(detail.toString()),
        trailing: Icon(Icons.circle, color: color, size: 12),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.lines});
  final List<Map<String, dynamic>> lines;

  static String _amt(num cents) => (cents / 100).toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final overspent =
        lines.any((l) => (l['remaining_cents'] ?? 0) < 0);
    final subtitle = lines.map((l) {
      final cur = l['currency'];
      final planned = l['planned_cents'] ?? 0;
      final actual = l['actual_cents'] ?? 0;
      final rem = l['remaining_cents'] ?? 0;
      return '$cur ${_amt(actual)} of ${_amt(planned)} spent · ${_amt(rem)} left';
    }).join('\n');
    return Card(
      child: ListTile(
        leading: Icon(Icons.account_balance_wallet,
            color: overspent ? Colors.red : null),
        title: const Text('Budget'),
        subtitle: Text(subtitle),
        isThreeLine: lines.length > 1,
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final gaps =
        items.where((i) => (i['unbooked_nights'] ?? 0) > 0).toList();
    if (gaps.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.hotel, color: Colors.green),
          title: Text('All lodging booked'),
          subtitle: Text('Every leg has accommodation for every night.'),
        ),
      );
    }
    final summary = gaps
        .map((g) => '${g['leg_name']} (${g['unbooked_nights']})')
        .join(', ');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.hotel, color: Colors.orange),
        title: Text('${gaps.length} leg(s) need lodging'),
        subtitle: Text('Unbooked nights — $summary'),
      ),
    );
  }
}

class _ReviewPromptCard extends StatelessWidget {
  const _ReviewPromptCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.rate_review_outlined,
            color: scheme.onTertiaryContainer),
        title: Text('How was ${trip.name}?',
            style: TextStyle(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w600)),
        subtitle: Text('Tap to add a quick review — it sharpens future planning.',
            style: TextStyle(color: scheme.onTertiaryContainer)),
        trailing: Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
        onTap: () => context.go('/trips/review/${trip.id}'),
      ),
    );
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
