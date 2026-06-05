import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/booking.dart';
import '../../../providers/trip_provider.dart';
import 'booking_form.dart';

class BookingTile extends ConsumerWidget {
  const BookingTile({required this.booking, super.key});

  final Booking booking;

  IconData _iconFor(String type) {
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

  Color _statusColor(BuildContext context) {
    switch (booking.status) {
      case 'booked':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'needs_booking':
        return Colors.red;
      case 'researching':
        return Colors.blue;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final payload = await showBookingForm(
      context,
      legId: booking.legId,
      existing: booking,
    );
    if (payload == null) return;
    final ok =
        await ref.read(tripMutationsProvider).updateBooking(booking.id, payload);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update booking')),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete booking?'),
        content: Text('Remove "${booking.name}"?'),
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
    final ok = await ref.read(tripMutationsProvider).deleteBooking(booking.id);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete booking')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateLine = [
      if (booking.startDate != null) booking.startDate,
      if (booking.endDate != null) '-> ${booking.endDate}',
    ].join(' ');

    return Card(
      child: ListTile(
        leading: Icon(_iconFor(booking.type)),
        title: Text(booking.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dateLine.isNotEmpty) Text(dateLine),
            if (booking.locationName != null) Text(booking.locationName!),
            if (booking.confirmation != null)
              Text('Conf: ${booking.confirmation}',
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booking.status,
                    style: TextStyle(
                      color: _statusColor(context),
                      fontSize: 11,
                    ),
                  ),
                ),
                if (booking.costCents != null) ...[
                  const SizedBox(height: 4),
                  Text(booking.formattedCost,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _edit(context, ref);
                if (v == 'delete') _delete(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
