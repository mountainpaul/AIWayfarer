import 'package:flutter/material.dart';

import '../../../models/chat_message.dart';

/// Default presentation per spec §3.5: collapsed iteration panel showing
/// draft -> critic -> revised. Quiet mode in Settings would hide this.
class IterationPanel extends StatelessWidget {
  const IterationPanel({required this.steps, super.key});

  final List<IterationStep> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            'Show reasoning (${steps.length} steps)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: steps
              .map((s) => Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.label,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(s.content,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
