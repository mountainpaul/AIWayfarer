import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/voice_service.dart';

/// Push-to-talk: hold to record, release to submit.
class PttButton extends ConsumerStatefulWidget {
  const PttButton({required this.onTranscript, super.key});

  final void Function(String text, bool isFinal) onTranscript;

  @override
  ConsumerState<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends ConsumerState<PttButton> {
  bool _listening = false;
  bool _pressed = false;

  Future<void> _start() async {
    _pressed = true;
    final svc = ref.read(voiceServiceProvider);
    // init() can block on the first-run mic permission dialog; the press may
    // have been released (or the widget disposed) by the time it returns.
    final ok = await svc.init();
    if (!ok || !mounted || !_pressed) return;
    setState(() => _listening = true);
    await svc.startListening(onResult: widget.onTranscript);
  }

  Future<void> _stop() async {
    _pressed = false;
    await ref.read(voiceServiceProvider).stopListening();
    if (mounted) setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = _listening
        ? Colors.red
        : Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _stop(),
      onLongPressCancel: _stop,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(_listening ? Icons.mic : Icons.mic_none, color: color),
      ),
    );
  }
}
