import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/chat_message.dart';
import '../../../providers/quiet_mode_provider.dart';
import 'iteration_panel.dart';

class MessageBubble extends ConsumerWidget {
  const MessageBubble({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quietMode = ref.watch(quietModeProvider);
    final isUser = message.role == 'user';
    final scheme = Theme.of(context).colorScheme;
    final bg = isUser ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final fg = isUser ? scheme.onPrimaryContainer : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: isUser
                ? Text(message.content, style: TextStyle(color: fg))
                : MarkdownBody(
                    data: message.content,
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        launchUrl(Uri.parse(href),
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    styleSheet:
                        MarkdownStyleSheet.fromTheme(Theme.of(context))
                            .copyWith(p: TextStyle(color: fg)),
                  ),
          ),
          if (!isUser && message.confidence == 'low' &&
              message.clarifyingQuestion != null) ...[
            const SizedBox(height: 6),
            ActionChip(
              avatar: const Icon(Icons.help_outline, size: 18),
              label: Text(message.clarifyingQuestion!),
              onPressed: () {
                // Tapping the chip should let the user answer; left as a TODO
                // because composing a structured reply is its own UX problem.
              },
            ),
          ],
          if (!isUser && !quietMode && message.iterations.isNotEmpty) ...[
            const SizedBox(height: 6),
            IterationPanel(steps: message.iterations),
          ],
          if (!isUser && message.sources.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: message.sources
                  .map((s) => Chip(
                        label:
                            Text(s, style: const TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
