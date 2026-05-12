import 'package:flutter/material.dart';

import '../../../models/booking.dart';

class BookingTile extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        isThreeLine: true,
      ),
    );
  }
}
