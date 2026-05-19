import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/quiet_mode_provider.dart';
import '../../services/api_client.dart';

/// Settings: API base URL, voice mode, push-to-talk vs wake-word.
/// API URL persists via shared_preferences (wired in main.dart + ApiBaseUrlNotifier).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlController;
  bool _wakeWord = false;

  @override
  void initState() {
    super.initState();
    _urlController =
        TextEditingController(text: ref.read(apiBaseUrlProvider));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the field in sync if the URL changes from outside this screen.
    ref.listen<String>(apiBaseUrlProvider, (_, next) {
      if (_urlController.text != next) _urlController.text = next;
    });

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Backend',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'API base URL',
              border: OutlineInputBorder(),
              hintText: 'http://localhost:8000',
            ),
            onSubmitted: (v) async {
              await ref.read(apiBaseUrlProvider.notifier).set(v.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API base URL saved')),
                );
              }
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Model is configured server-side via the ANTHROPIC_MODEL env var.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const Divider(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Voice',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        SwitchListTile(
          title: const Text('Wake-word mode (when charging)'),
          subtitle: const Text('Push-to-talk is the default. Stub - not yet implemented.'),
          value: _wakeWord,
          onChanged: (v) => setState(() => _wakeWord = v),
        ),
        const Divider(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Presentation',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        SwitchListTile(
          title: const Text('Quiet mode'),
          subtitle: const Text(
              'Hide draft -> critic iteration; show only the final answer.'),
          value: ref.watch(quietModeProvider),
          onChanged: (v) => ref.read(quietModeProvider.notifier).set(v),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
