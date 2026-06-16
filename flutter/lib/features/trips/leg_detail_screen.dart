import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/leg.dart';
import '../../providers/trip_provider.dart';
import '../awards/award_search_sheet.dart';
import 'widgets/booking_form.dart';
import 'widgets/booking_tile.dart';
import 'widgets/journal_tile.dart';
import 'widgets/leg_form.dart';
import 'widgets/packing_form.dart';
import 'widgets/packing_tile.dart';
import 'widgets/task_form.dart';
import 'widgets/task_tile.dart';

class LegDetailScreen extends ConsumerWidget {
  const LegDetailScreen({required this.legId, super.key});

  final String legId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legAsync = ref.watch(legProvider(legId));

    return legAsync.when(
      data: (leg) {
        if (leg == null) {
          return const Center(child: Text('Leg not found'));
        }
        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Container(
                color: WayfarerTheme.parseLegColor(leg.color).withValues(alpha: 0.15),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${leg.emoji ?? ''} ${leg.name}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text('${leg.startDate} - ${leg.endDate}'),
                          if (leg.places != null) Text(leg.places!),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.loyalty_outlined),
                      tooltip: 'Search award availability',
                      onPressed: () =>
                          showAwardSearchSheet(context, legId: legId),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _editLeg(context, ref, leg);
                        if (v == 'delete') _deleteLeg(context, ref, leg);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit leg')),
                        PopupMenuItem(
                            value: 'delete', child: Text('Delete leg')),
                      ],
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Bookings'),
                  Tab(text: 'Tasks'),
                  Tab(text: 'Packing'),
                  Tab(text: 'Journal'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _BookingsTab(legId: legId),
                    _TasksTab(legId: legId),
                    _PackingTab(tripId: leg.tripId),
                    _JournalTab(legId: legId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Future<void> _editLeg(BuildContext context, WidgetRef ref, Leg leg) async {
    final payload = await showLegForm(
      context,
      tripId: leg.tripId,
      sortOrder: leg.sortOrder,
      existing: {
        'name': leg.name,
        'start_date': leg.startDate,
        'end_date': leg.endDate,
        'places': leg.places,
        'notes': leg.notes,
        'is_schengen': leg.isSchengen,
      },
    );
    if (payload == null) return;
    final ok = await ref.read(tripMutationsProvider).updateLeg(leg.id, payload);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update leg')),
      );
    }
  }

  Future<void> _deleteLeg(BuildContext context, WidgetRef ref, Leg leg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete leg?'),
        content: Text('Remove "${leg.name}"? It can be restored from history.'),
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
    if (confirmed != true) return;
    final ok = await ref.read(tripMutationsProvider).deleteLeg(leg.id);
    if (!context.mounted) return;
    if (ok) {
      context.go('/trips'); // leg is gone — back to the list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete leg')),
      );
    }
  }
}

class _BookingsTab extends ConsumerWidget {
  const _BookingsTab({required this.legId});
  final String legId;

  Future<void> _addBooking(BuildContext context, WidgetRef ref) async {
    final payload = await showBookingForm(context, legId: legId);
    if (payload == null) return;
    final ok = await ref.read(tripMutationsProvider).createBooking(payload);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create booking')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsForLegProvider(legId));
    return Stack(
      children: [
        bookings.when(
          data: (list) => list.isEmpty
              ? const Center(child: Text('No bookings yet.'))
              : ListView(
                  children:
                      list.map((b) => BookingTile(booking: b)).toList()),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_booking',
            onPressed: () => _addBooking(context, ref),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.legId});
  final String legId;

  Future<void> _addTask(BuildContext context, WidgetRef ref) async {
    final payload = await showTaskForm(context, legId: legId);
    if (payload == null) return;
    final ok = await ref.read(tripMutationsProvider).createTask(payload);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create task')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksForLegProvider(legId));
    return Stack(
      children: [
        tasks.when(
          data: (list) => list.isEmpty
              ? const Center(child: Text('No tasks for this leg.'))
              : ListView(
                  children:
                      list.map((t) => TaskTile(task: t)).toList()),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_task',
            onPressed: () => _addTask(context, ref),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _PackingTab extends ConsumerWidget {
  const _PackingTab({required this.tripId});
  final String tripId;

  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
    final payload = await showPackingForm(context, tripId: tripId);
    if (payload == null) return;
    final ok = await ref.read(tripMutationsProvider).createPacking(payload);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add item')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(packingForTripProvider(tripId));
    return Stack(
      children: [
        items.when(
          data: (list) => list.isEmpty
              ? const Center(child: Text('No packing items.'))
              : ListView(
                  children: list.map((i) => PackingTile(item: i)).toList()),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_packing',
            onPressed: () => _addItem(context, ref),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _JournalTab extends ConsumerWidget {
  const _JournalTab({required this.legId});
  final String legId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(journalForLegProvider(legId));
    return Stack(
      children: [
        entries.when(
          data: (list) => list.isEmpty
              ? const Center(child: Text('No journal entries yet.'))
              : ListView(
                  children: list.map((e) => JournalTile(entry: e)).toList()),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add note'),
            onPressed: () => _addNoteDialog(context, ref, legId),
          ),
        ),
      ],
    );
  }

  Future<void> _addNoteDialog(
      BuildContext context, WidgetRef ref, String legId) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New journal entry'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final ok = await ref
        .read(tripMutationsProvider)
        .addJournal(legId: legId, content: text.trim());
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline - writes disabled')),
      );
    }
  }
}
