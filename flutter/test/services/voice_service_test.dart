// ignore_for_file: prefer_const_constructors

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
// ignore: depend_on_referenced_packages
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';
import 'package:wayfarer/services/voice_service.dart';

// ---------------------------------------------------------------------------
// Fake SpeechToTextPlatform
// ---------------------------------------------------------------------------

class _FakeSpeechPlatform extends SpeechToTextPlatform
    with MockPlatformInterfaceMixin {
  bool initResult;
  bool listenInvoked = false;
  bool stopInvoked = false;
  bool cancelInvoked = false;
  bool throwOnListen = false;

  _FakeSpeechPlatform({
    this.initResult = true,
  });

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> initialize({
    debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async =>
      initResult;

  @override
  Future<bool> listen({
    String? localeId,
    // ignore: deprecated_member_use
    partialResults = true,
    // ignore: deprecated_member_use
    onDevice = false,
    // ignore: deprecated_member_use
    int listenMode = 0,
    // ignore: deprecated_member_use
    sampleRate = 0,
    stt.SpeechListenOptions? options,
  }) async {
    listenInvoked = true;
    if (throwOnListen) {
      throw PlatformException(
        code: 'listenFailedError',
        message: 'Failed',
      );
    }
    return true;
  }

  @override
  Future<void> stop() async {
    stopInvoked = true;
  }

  @override
  Future<void> cancel() async {
    cancelInvoked = true;
  }

  @override
  Future<List<dynamic>> locales() async => [];
}

// ---------------------------------------------------------------------------
// flutter_tts channel mock helpers
//
// flutter_tts 4.x uses MethodChannel('flutter_tts').
// ---------------------------------------------------------------------------

const _ttsChanName = 'flutter_tts';

void _setupTtsMock({List<String>? recorder}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel(_ttsChanName),
    (MethodCall call) async {
      recorder?.add(call.method);
      return 1;
    },
  );
}

void _clearTtsMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel(_ttsChanName), null);
}

// ---------------------------------------------------------------------------
// IMPORTANT: SpeechToText() is a module-level singleton whose _initWorked
// field persists across tests. Once initialize() succeeds in any test, the
// singleton short-circuits all future initialize() calls. Consequently:
//
//  1. Callbacks (onTextRecognition, etc.) are wired to the platform instance
//     that was active when the first successful initialize() ran.
//  2. We use a SINGLE persistent _FakeSpeechPlatform for the whole test file
//     so that callbacks always fire on the right instance.
//  3. We reset mutable flags on the same fake in each setUp rather than
//     creating a new platform instance.
//  4. The "init returns false" branch cannot be tested in the same binary as
//     the success tests — it is SKIPPED with an explanation.
// ---------------------------------------------------------------------------

// Single fake that lives for the lifetime of the test binary.
final _speech = _FakeSpeechPlatform(initResult: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Install the persistent fake ONCE before all tests.
  setUpAll(() {
    SpeechToTextPlatform.instance = _speech;
  });

  setUp(() {
    // Reset call-tracking flags between tests (reuse same instance).
    _speech.listenInvoked = false;
    _speech.stopInvoked = false;
    _speech.cancelInvoked = false;
    _speech.throwOnListen = false;
    _setupTtsMock();
  });

  tearDown(_clearTtsMock);

  // -------------------------------------------------------------------------
  // init()
  // -------------------------------------------------------------------------

  group('init()', () {
    test('returns true and marks service available when platform succeeds',
        () async {
      final service = VoiceService();

      final result = await service.init();

      expect(result, isTrue);
      expect(service.isAvailable, isTrue);
    });

    test('returns true immediately on second call (already initialized)',
        () async {
      final service = VoiceService();
      await service.init();

      // VoiceService._initialized is true; the singleton is also already
      // initialised. Both guards short-circuit.
      final result = await service.init();

      expect(result, isTrue);
    });

    // The "platform returns false" branch requires a fresh SpeechToText
    // singleton whose _initWorked is still false. This is not achievable
    // in the same test binary without modifying production code.
    test(
        'SKIPPED: platform failure branch untestable due to SpeechToText singleton',
        () {
      markTestSkipped(
        'SpeechToText() is a singleton whose _initWorked field cannot be '
        'reset between test runs without modifying prod code. '
        'Run in an isolated test binary to cover this branch.',
      );
    });
  });

  // -------------------------------------------------------------------------
  // startListening()
  // -------------------------------------------------------------------------

  group('startListening()', () {
    test('delegates to platform listen', () async {
      final service = VoiceService();
      await service.init();

      await service.startListening(onResult: (_, __) {});

      expect(_speech.listenInvoked, isTrue);
    });

    test('invokes onResult callback when platform fires recognition event',
        () async {
      final service = VoiceService();
      await service.init();

      String? capturedPartial;
      bool? capturedFinal;

      await service.startListening(
        onResult: (partial, isFinal) {
          capturedPartial = partial;
          capturedFinal = isFinal;
        },
      );

      // Fire the recognition event via the persistent platform fake.
      // SpeechToText.initialize() wired onTextRecognition to this instance.
      _speech.onTextRecognition?.call(
        '{"alternates":[{"recognizedWords":"hello","confidence":0.9}],'
        '"finalResult":false}',
      );

      expect(capturedPartial, equals('hello'));
      expect(capturedFinal, isFalse);
    });

    test('delivers finalResult=true when recognizer signals final', () async {
      final service = VoiceService();
      await service.init();

      bool? capturedFinal;
      String? capturedWords;

      await service.startListening(
        onResult: (partial, isFinal) {
          capturedWords = partial;
          capturedFinal = isFinal;
        },
      );

      _speech.onTextRecognition?.call(
        '{"alternates":[{"recognizedWords":"goodbye","confidence":0.95}],'
        '"finalResult":true}',
      );

      expect(capturedWords, equals('goodbye'));
      expect(capturedFinal, isTrue);
    });

    test('auto-inits when not yet initialized', () async {
      final service = VoiceService();
      // Do NOT call init() explicitly — startListening should trigger it.

      await service.startListening(onResult: (_, __) {});

      expect(_speech.listenInvoked, isTrue);
      expect(service.isAvailable, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // stopListening()
  // -------------------------------------------------------------------------

  group('stopListening()', () {
    test('delegates to platform stop', () async {
      final service = VoiceService();
      await service.init();
      await service.startListening(onResult: (_, __) {});

      await service.stopListening();

      expect(_speech.stopInvoked, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // cancelListening()
  // -------------------------------------------------------------------------

  group('cancelListening()', () {
    test('delegates to platform cancel', () async {
      final service = VoiceService();
      await service.init();

      await service.cancelListening();

      expect(_speech.cancelInvoked, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // speak()
  // -------------------------------------------------------------------------

  group('speak()', () {
    test('calls tts.stop then tts.speak for non-empty text', () async {
      final List<String> calls = [];
      _setupTtsMock(recorder: calls);

      final service = VoiceService();
      await service.init();
      await service.speak('Hello world');

      expect(calls, containsAll(['stop', 'speak']));
      // stop must precede speak.
      expect(calls.indexOf('stop'), lessThan(calls.indexOf('speak')));
    });

    test('does nothing for empty text', () async {
      final List<String> calls = [];
      _setupTtsMock(recorder: calls);

      final service = VoiceService();
      await service.init();
      await service.speak('');

      expect(calls, isNot(contains('speak')));
    });
  });

  // -------------------------------------------------------------------------
  // stopSpeaking()
  // -------------------------------------------------------------------------

  group('stopSpeaking()', () {
    test('calls tts.stop', () async {
      final List<String> calls = [];
      _setupTtsMock(recorder: calls);

      final service = VoiceService();
      await service.stopSpeaking();

      expect(calls, contains('stop'));
    });
  });

  // -------------------------------------------------------------------------
  // isListening
  // -------------------------------------------------------------------------

  group('isListening', () {
    test('is false when listen has not been called', () async {
      final service = VoiceService();
      await service.init();

      // Platform fake does not set the _listening flag on the SpeechToText
      // singleton (that happens via an onStatus event), so isListening stays
      // false until the platform confirms listening started.
      expect(service.isListening, isFalse);
    });
  });
}
