import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Push-to-talk first per spec §8. Wake-word mode left as a TODO for v0.6+.
class VoiceService {
  VoiceService();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<bool> init() async {
    if (_initialized) return true;
    if (kIsWeb) return false; // Speech/TTS not supported on web
    final ok = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _initialized = ok;
    return ok;
  }

  bool get isAvailable => _initialized;
  bool get isListening => _speech.isListening;

  /// Start listening; the callback receives partial + final transcripts.
  Future<void> startListening({
    required void Function(String partial, bool isFinal) onResult,
  }) async {
    if (!_initialized) await init();
    await _speech.listen(
      onResult: (result) => onResult(
        result.recognizedWords,
        result.finalResult,
      ),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
    );
  }

  Future<void> stopListening() => _speech.stop();
  Future<void> cancelListening() => _speech.cancel();

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() => _tts.stop();

  // TODO(v0.6+): wake-word mode while charging. See spec §8.
}

final voiceServiceProvider = Provider<VoiceService>((_) => VoiceService());
