import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/packing_item.dart';
import '../../../providers/trip_provider.dart';

class PackingTile extends ConsumerWidget {
  const PackingTile({required this.item, super.key});

  final PackingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: item.isPacked,
          onChanged: (v) async {
            if (v == null) return;
            final ok =
                await ref.read(tripMutationsProvider).togglePacked(item.id);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Offline - writes disabled')),
              );
            }
          },
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isPacked ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(item.category),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove item',
          onPressed: () async {
            final ok =
                await ref.read(tripMutationsProvider).deletePacking(item.id);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Offline - writes disabled')),
              );
            }
          },
        ),
      ),
    );
  }
}
