import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../providers/trip_provider.dart';
import '../../services/api_client.dart';
import '../../services/sync_service.dart';

/// Flipped to true when onboarding finishes, causing the app to rebuild.
final onboardingCompleteNotifier = ValueNotifier<bool>(false);

/// First-launch setup wizard: API URL → permissions → sync.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _urlController = TextEditingController();
  int _page = 0;
  bool _syncing = false;
  bool _syncOk = false;
  String? _syncError;
  bool _locationGranted = false;
  bool _micGranted = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = ref.read(apiBaseUrlProvider);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  static const _totalPages = 5; // welcome, url, permissions, sync, demo

  void _next() {
    if (_page < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await ref.read(apiBaseUrlProvider.notifier).set(url);
    _next();
  }

  Future<void> _requestLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    setState(() {
      _locationGranted = perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always;
    });
  }

  Future<void> _requestMic() async {
    final stt = SpeechToText();
    final available = await stt.initialize();
    setState(() => _micGranted = available);
  }

  Future<void> _runSync() async {
    setState(() {
      _syncing = true;
      _syncError = null;
    });
    try {
      // Use SyncService so the data is actually persisted to local SQLite —
      // fetching the snapshot directly would show "loaded" then discard it.
      final ok = await ref.read(syncServiceProvider).snapshot();
      if (!mounted) return;
      if (ok) {
        setState(() {
          _syncOk = true;
          _syncing = false;
        });
        ref.read(syncTriggerProvider.notifier).state++;
      } else {
        setState(() {
          _syncing = false;
          _syncError = 'Could not reach the backend.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _syncError = 'Could not connect: $e';
      });
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      onboardingCompleteNotifier.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _page = i),
          children: [
            _buildWelcomePage(),
            _buildUrlPage(),
            _buildPermissionsPage(),
            _buildSyncPage(),
            _buildDemoPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.explore, size: 80, color: Colors.indigo),
          const SizedBox(height: 24),
          Text('AI Wayfarer',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          const Text(
            'Your travel planning and live companion.\nLet\'s get set up.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: _next,
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_outlined, size: 64),
          const SizedBox(height: 16),
          Text('Connect to Backend',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Enter the URL of your Wayfarer backend server.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'API base URL',
              hintText: 'http://192.168.1.8:8000',
            ),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _saveUrl(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saveUrl,
            child: const Text('Save & Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_outlined, size: 64),
          const SizedBox(height: 16),
          Text('Permissions',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Wayfarer uses your location for grounding and your mic for voice input.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: Icon(_locationGranted
                ? Icons.check_circle
                : Icons.location_on_outlined,
                color: _locationGranted ? Colors.green : null),
            title: const Text('Location'),
            subtitle: Text(_locationGranted ? 'Granted' : 'Tap to grant'),
            onTap: _requestLocation,
          ),
          ListTile(
            leading: Icon(_micGranted
                ? Icons.check_circle
                : Icons.mic_outlined,
                color: _micGranted ? Colors.green : null),
            title: const Text('Microphone'),
            subtitle: Text(_micGranted ? 'Granted' : 'Tap to grant'),
            onTap: _requestMic,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _next,
            child: const Text('Continue'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _next,
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoPage() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text('Here\'s what Wayfarer looks like in action',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                // User message
                _demoBubble(
                  'What time does the ferry leave tomorrow?',
                  isUser: true,
                  scheme: scheme,
                ),
                // Assistant message
                _demoBubble(
                  '**Trasmed GNV ferry** departs Palermo at **21:00** '
                  'tomorrow (Apr 26), arriving Cagliari at 08:00 on Apr 27.\n\n'
                  'Your booking is confirmed. The port terminal is at '
                  'Molo Piave — about 15 min by taxi from your hotel.',
                  isUser: false,
                  scheme: scheme,
                ),
                // Iteration hint
                _demoIterationHint(scheme),
                const SizedBox(height: 16),
                // Second exchange
                _demoBubble(
                  'Is there a train from Catania to Palermo on the 25th?',
                  isUser: true,
                  scheme: scheme,
                ),
                _demoBubble(
                  '**I\'m not confident enough to answer this directly.** '
                  'Trenitalia shows services, but I can\'t verify if the '
                  'Apr 25 schedule has been updated for strike action.\n\n'
                  'Would you like me to check the Trenitalia website directly, '
                  'or would a bus alternative (Flixbus, ~3h) work as a backup?',
                  isUser: false,
                  scheme: scheme,
                  isLowConfidence: true,
                ),
                const SizedBox(height: 8),
                // Explainer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What just happened:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface)),
                      const SizedBox(height: 4),
                      Text(
                        '• Wayfarer knew your ferry booking and port location\n'
                        '• It ran a 6-point critic check before answering\n'
                        '• When unsure, it asked instead of guessing\n'
                        '• Hold the mic button to ask by voice',
                        style: TextStyle(color: scheme.onSurface, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _finish,
            child: const Text('Start Using Wayfarer'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _demoBubble(String text, {
    required bool isUser,
    required ColorScheme scheme,
    bool isLowConfidence = false,
  }) {
    final bg = isUser ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final fg = isUser ? scheme.onPrimaryContainer : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(text, style: TextStyle(color: fg, fontSize: 14)),
            ),
            if (isLowConfidence) ...[
              const SizedBox(height: 4),
              Chip(
                avatar: const Icon(Icons.help_outline, size: 16),
                label: const Text('Low confidence',
                    style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _demoIterationHint(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Row(
        children: [
          Icon(Icons.expand_more, size: 16, color: scheme.outline),
          Text(' Show reasoning (2 steps)',
              style: TextStyle(fontSize: 12, color: scheme.outline)),
        ],
      ),
    );
  }

  Widget _buildSyncPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _syncOk ? Icons.check_circle : Icons.sync,
            size: 64,
            color: _syncOk ? Colors.green : null,
          ),
          const SizedBox(height: 16),
          Text(_syncOk ? 'You\'re all set!' : 'Sync Trip Data',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (!_syncOk)
            const Text(
              'Pull your trip data from the backend.',
              textAlign: TextAlign.center,
            ),
          if (_syncOk)
            const Text(
              'Trip data loaded successfully.',
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          if (_syncing) const CircularProgressIndicator(),
          if (_syncError != null) ...[
            Text(_syncError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          if (!_syncOk && !_syncing)
            FilledButton(
              onPressed: _runSync,
              child: const Text('Sync Now'),
            ),
          if (_syncOk) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _next,
              child: const Text('Next'),
            ),
          ],
        ],
      ),
    );
  }
}
