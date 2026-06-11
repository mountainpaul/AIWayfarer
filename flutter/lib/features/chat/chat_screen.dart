import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_provider.dart';
import '../../services/voice_service.dart';
import 'widgets/message_bubble.dart';
import 'widgets/ptt_button.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _voiceReply = false;
  String _partial = '';

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    // Guard the Enter-key and PTT paths too — ChatNotifier.send() drops the
    // message while another is in flight, and we'd have cleared the field.
    if (text.isEmpty || ref.read(chatProvider).sending) return;
    _controller.clear();
    await ref.read(chatProvider.notifier).send(text);
    // The user may have switched tabs during the LLM round-trip.
    if (!mounted) return;
    _scrollToBottom();

    if (_voiceReply) {
      final last = ref.read(chatProvider).messages.lastOrNull;
      if (last != null && last.role == 'assistant') {
        await ref.read(voiceServiceProvider).speak(last.content);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    return Column(
      children: [
        Expanded(
          child: state.messages.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Ask anything. AI Wayfarer grounds answers in your trip,\nyour location, and the time of day.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: state.messages.length,
                  itemBuilder: (_, i) =>
                      MessageBubble(message: state.messages[i]),
                ),
        ),
        if (state.error != null)
          Container(
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            child: Text(
              'Error: ${state.error}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        if (_partial.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_partial,
                  style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).hintColor)),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                PttButton(
                  onTranscript: (text, isFinal) {
                    if (isFinal) {
                      setState(() => _partial = '');
                      _controller.text = text;
                      _send();
                    } else {
                      setState(() => _partial = text);
                    }
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Ask AI Wayfarer...',
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Speak replies',
                  icon: Icon(_voiceReply
                      ? Icons.volume_up
                      : Icons.volume_off_outlined),
                  onPressed: () =>
                      setState(() => _voiceReply = !_voiceReply),
                ),
                IconButton(
                  icon: state.sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  onPressed: state.sending ? null : _send,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
