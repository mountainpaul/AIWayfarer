import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/task.dart';
import '../../../providers/trip_provider.dart';
import 'task_form.dart';

class TaskTile extends ConsumerWidget {
  const TaskTile({required this.task, super.key});

  final Task task;

  Color _priorityColor(BuildContext context) {
    switch (task.priority) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
      default:
        return Colors.grey;
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final payload = await showTaskForm(
      context,
      legId: task.legId ?? '',
      existing: task,
    );
    if (payload == null) return;
    final ok =
        await ref.read(tripMutationsProvider).updateTask(task.id, payload);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update task')),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Remove "${task.title}"?'),
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
    final ok = await ref.read(tripMutationsProvider).deleteTask(task.id);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete task')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: task.isDone,
          onChanged: (v) async {
            if (v == null) return;
            final ok =
                await ref.read(tripMutationsProvider).toggleTaskDone(task.id);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Offline - writes disabled')),
              );
            }
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _priorityColor(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(task.priority,
                  style: TextStyle(
                    color: _priorityColor(context),
                    fontSize: 11,
                  )),
            ),
            if (task.dueDate != null) ...[
              const SizedBox(width: 8),
              Text('due ${task.dueDate}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _edit(context, ref);
            if (v == 'delete') _delete(context, ref);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
