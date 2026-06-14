import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/leg.dart';
import '../../providers/trip_provider.dart';
import '../../services/api_client.dart';
import 'award_search_sheet.dart';

/// Awards hub: loyalty offers scanned from Gmail + award-search links per leg.
class AwardsScreen extends ConsumerStatefulWidget {
  const AwardsScreen({super.key});

  @override
  ConsumerState<AwardsScreen> createState() => _AwardsScreenState();
}

class _AwardsScreenState extends ConsumerState<AwardsScreen> {
  bool _scanning = false;
  String? _error;
  List<Map<String, dynamic>>? _offers;

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final result = await ref.read(apiClientProvider).scanLoyaltyOffers();
      if (!mounted) return;
      final raw = result['offers'] as List<dynamic>? ?? [];
      setState(() {
        _scanning = false;
        _offers = raw.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final legsAsync = ref.watch(legsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Loyalty offers', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Scans your Gmail for airline and hotel loyalty promos '
          '(transfer bonuses, award sales, point promos).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (_scanning)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Scanning and parsing with AI — 30-60 seconds...'),
                ],
              ),
            ),
          )
        else
          FilledButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.email_outlined),
            label: Text(_offers == null ? 'Scan email for offers' : 'Rescan'),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_offers != null && _offers!.isEmpty && !_scanning)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('No current offers found in your email.'),
          ),
        if (_offers != null)
          ..._offers!.map((o) => _OfferCard(offer: o)),
        const Divider(height: 40),
        Text('Award flight search',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Open a pre-filled award search (Seats.aero, PointsYeah, Roame) '
          'for a leg\'s route and dates.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        legsAsync.when(
          data: (legs) {
            final today = DateTime.now();
            final upcoming = legs
                .where((l) => !l.endDateTime
                    .isBefore(DateTime(today.year, today.month, today.day)))
                .toList();
            if (upcoming.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No upcoming legs.'),
              );
            }
            return Column(
              children: upcoming
                  .map((l) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.flight_takeoff),
                          title: Text('${l.emoji ?? ''} ${l.name}'.trim()),
                          subtitle: Text('${l.startDate} - ${l.endDate}'),
                          trailing: const Icon(Icons.search),
                          onTap: () =>
                              showAwardSearchSheet(context, legId: l.id),
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
        ),
      ],
    );
  }
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.offer});
  final Map<String, dynamic> offer;

  IconData get _icon => switch (offer['kind'] as String?) {
        'flight' => Icons.flight,
        'hotel' => Icons.hotel,
        _ => Icons.card_giftcard,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expires = offer['expires'] as String?;
    final promo = offer['promo_code'] as String?;
    final legId = offer['leg_id'] as String?;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offer['title'] as String? ?? 'Offer',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(offer['program'] as String? ?? '',
                style: Theme.of(context).textTheme.bodySmall),
            if ((offer['summary'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(offer['summary'] as String),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (expires != null)
                  Chip(
                    label: Text('Expires $expires'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (promo != null)
                  Chip(
                    label: Text('Code: $promo'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (legId != null) _LegChip(legId: legId),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegChip extends ConsumerWidget {
  const _LegChip({required this.legId});
  final String legId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leg = ref.watch(legProvider(legId)).valueOrNull;
    if (leg == null) return const SizedBox.shrink();
    return ActionChip(
      avatar: const Icon(Icons.map, size: 16),
      label: Text(leg.name),
      visualDensity: VisualDensity.compact,
      onPressed: () => showAwardSearchSheet(context, legId: legId),
    );
  }
}
