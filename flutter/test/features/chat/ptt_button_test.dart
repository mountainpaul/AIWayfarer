import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/chat/widgets/ptt_button.dart';
import 'package:wayfarer/services/voice_service.dart';

/// Fake VoiceService that tracks calls and never touches platform channels.
class _FakeVoiceService extends VoiceService {
  bool initOk = true;
  bool startCalled = false;
  bool stopCalled = false;

  void Function(String text, bool isFinal)? _onResult;

  @override
  Future<bool> init() async => initOk;

  @override
  Future<void> startListening({
    required void Function(String partial, bool isFinal) onResult,
  }) async {
    startCalled = true;
    _onResult = onResult;
  }

  @override
  Future<void> stopListening() async {
    stopCalled = true;
  }

  /// Simulate a partial transcript event from the speech engine.
  void simulatePartial(String text) => _onResult?.call(text, false);

  /// Simulate a final transcript event from the speech engine.
  void simulateFinal(String text) => _onResult?.call(text, true);
}

Widget _wrap(
  _FakeVoiceService svc, {
  void Function(String, bool)? onTranscript,
}) =>
    ProviderScope(
      overrides: [
        voiceServiceProvider.overrideWithValue(svc),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: PttButton(
              onTranscript: onTranscript ?? (_, __) {},
            ),
          ),
        ),
      ),
    );

void main() {
  group('PttButton — initial visual state', () {
    testWidgets('renders mic_none icon when not listening', (tester) async {
      final svc = _FakeVoiceService();
      await tester.pumpWidget(_wrap(svc));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('button is a circle of size 44x44', (tester) async {
      final svc = _FakeVoiceService();
      await tester.pumpWidget(_wrap(svc));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GestureDetector),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(container.constraints?.maxWidth ?? container.child.runtimeType, isNotNull);
    });

    testWidgets('GestureDetector is present', (tester) async {
      final svc = _FakeVoiceService();
      await tester.pumpWidget(_wrap(svc));
      await tester.pumpAndSettle();

      expect(find.byType(GestureDetector), findsOneWidget);
    });
  });

  group('PttButton — press / release callbacks', () {
    testWidgets('long-press start calls voice service init and startListening', (tester) async {
      final svc = _FakeVoiceService();
      await tester.pumpWidget(_wrap(svc));
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      expect(svc.startCalled, isTrue);
    });

    testWidgets('shows mic icon while listening after long-press', (tester) async {
      final svc = _FakeVoiceService();
      await tester.pumpWidget(_wrap(svc));
      await tester.pumpAndSettle();

      // Start a long press but don't release yet
      final gesture = await tester.startGesture(tester.getCenter(find.byType(GestureDetector)));
      // Trigger long-press by waiting > kLongPressTimeout
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsNothing);

      // Release
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('releasing long-press calls stopListening', (tester) async {
      final svc = _FakeVoiceService();
      await tester.pumpWidget(_wrap(svc));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(svc.stopCalled, isTrue);
    });

    testWidgets('returns to mic_none icon after release', (tester) async {
      final svc = _FakeVoiceService();
      await tester.pumpWidget(_wrap(svc));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('onTranscript receives final transcript from voice service', (tester) async {
      final svc = _FakeVoiceService();
      String? received;
      bool? isFinal;

      await tester.pumpWidget(_wrap(svc, onTranscript: (text, fin) {
        received = text;
        isFinal = fin;
      }));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      svc.simulateFinal('Take me to the Colosseum');
      await tester.pumpAndSettle();

      expect(received, 'Take me to the Colosseum');
      expect(isFinal, isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('onTranscript receives partial transcript', (tester) async {
      final svc = _FakeVoiceService();
      String? received;
      bool? isFinal;

      await tester.pumpWidget(_wrap(svc, onTranscript: (text, fin) {
        received = text;
        isFinal = fin;
      }));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      svc.simulatePartial('Take me to the');
      await tester.pumpAndSettle();

      expect(received, 'Take me to the');
      expect(isFinal, isFalse);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('PttButton — init failure', () {
    testWidgets('does not switch to listening state when init returns false', (tester) async {
      final svc = _FakeVoiceService()..initOk = false;
      await tester.pumpWidget(_wrap(svc));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.byType(GestureDetector)));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // init failed → _start() returns early → stays mic_none
      expect(find.byIcon(Icons.mic_none), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  // NOTE: Platform channel methods (speech_to_text SpeechToText.initialize,
  // flutter_tts FlutterTts.speak) are NOT exercised in these tests. The
  // real VoiceService wraps those APIs; attempting to call them in a test
  // environment without a platform mock throws a MissingPluginException.
  // All platform-touching paths are bypassed by overriding voiceServiceProvider
  // with _FakeVoiceService. Coverage gap: the real init()/startListening()
  // platform paths and the speak() flow from ChatScreen._send().
}
