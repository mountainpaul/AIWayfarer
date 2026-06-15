import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wayfarer/models/chat_message.dart';
import 'package:wayfarer/models/grounding.dart';
import 'package:wayfarer/providers/chat_provider.dart';
import 'package:wayfarer/providers/mode_provider.dart';
import 'package:wayfarer/services/api_client.dart';
import 'package:wayfarer/services/grounding_service.dart';
import 'package:wayfarer/services/local_db.dart';
import 'package:wayfarer/services/location_service.dart';

// ── Fake ApiClient ──────────────────────────────────────────────────────────

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');

  ChatResponse? response;
  Object? throwOnChat;
  String? lastMessage;
  String? lastMode;

  @override
  Future<ChatResponse> chat({
    required String message,
    required Grounding grounding,
    String mode = 'companion',
    String? sessionId,
  }) async {
    lastMessage = message;
    lastMode = mode;
    if (throwOnChat != null) throw throwOnChat!;
    return response ??
        const ChatResponse(
          answer: 'Hello from fake backend',
          confidence: 'high',
        );
  }
}

// ── Fake GroundingService ───────────────────────────────────────────────────

class _FakeLocation extends LocationService {
  @override
  Future<Position?> currentPosition() async => null;
}

class _FakeGroundingService extends GroundingService {
  _FakeGroundingService(LocalDb db)
      : super(
          db: db,
          location: _FakeLocation(),
        );

  final _stub = const Grounding(localTimeIso: '2026-06-14T10:00:00.000');

  @override
  Future<Grounding> compose() async => _stub;
}

// ── Container helper ────────────────────────────────────────────────────────

late LocalDb _db;

ProviderContainer _container({
  required _FakeApi api,
  AppMode mode = AppMode.planning,
}) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      groundingServiceProvider
          .overrideWithValue(_FakeGroundingService(_db)),
      modeProvider.overrideWith((_) => ModeNotifier()..set(mode)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

// ── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // The ChatNotifier._restore() reads from SharedPreferences — seed empty.
    SharedPreferences.setMockInitialValues({});
    _db = LocalDb.newForTest();
    await _db.init(pathOverride: inMemoryDatabasePath);
  });

  tearDown(() async {
    await _db.close();
  });

  group('ChatNotifier — successful send', () {
    test('appends user message immediately and sets sending=true mid-flight',
        () async {
      final api = _FakeApi();
      final c = _container(api: api);

      // Kick off send and capture mid-flight state.
      final sendFuture =
          c.read(chatProvider.notifier).send('What is the weather?');

      // After calling send() the user message is in the list and sending=true.
      final mid = c.read(chatProvider);
      expect(mid.messages.length, greaterThanOrEqualTo(1));
      expect(mid.messages.last.role, 'user');
      expect(mid.messages.last.content, 'What is the weather?');
      expect(mid.sending, isTrue);

      await sendFuture;
    });

    test('appends assistant reply and clears sending after response', () async {
      final api = _FakeApi()
        ..response = const ChatResponse(
          answer: 'Sunny and warm',
          confidence: 'high',
          sources: ['weather.com'],
        );
      final c = _container(api: api);

      await c.read(chatProvider.notifier).send('Weather?');

      final s = c.read(chatProvider);
      expect(s.sending, isFalse);
      expect(s.error, isNull);
      expect(s.messages.length, 2);
      expect(s.messages[0].role, 'user');
      expect(s.messages[1].role, 'assistant');
      expect(s.messages[1].content, 'Sunny and warm');
      expect(s.messages[1].sources, ['weather.com']);
      expect(s.messages[1].confidence, 'high');
    });

    test('sends mode=planning when AppMode is planning', () async {
      final api = _FakeApi();
      final c = _container(api: api, mode: AppMode.planning);

      await c.read(chatProvider.notifier).send('Hello');

      expect(api.lastMode, 'planning');
    });

    test('sends mode=companion when AppMode is companion', () async {
      final api = _FakeApi();
      final c = _container(api: api, mode: AppMode.companion);

      await c.read(chatProvider.notifier).send('Hello');

      expect(api.lastMode, 'companion');
    });

    test('message text is trimmed before sending', () async {
      final api = _FakeApi();
      final c = _container(api: api);

      await c.read(chatProvider.notifier).send('  hello  ');

      expect(api.lastMessage, 'hello');
      expect(c.read(chatProvider).messages.first.content, 'hello');
    });

    test('sets clarifyingQuestion when confidence is low', () async {
      final api = _FakeApi()
        ..response = const ChatResponse(
          answer: 'Could you clarify?',
          confidence: 'low',
        );
      final c = _container(api: api);

      await c.read(chatProvider.notifier).send('?');

      final reply = c.read(chatProvider).messages.last;
      expect(reply.clarifyingQuestion, 'Could you clarify?');
    });

    test('clarifyingQuestion is null when confidence is high', () async {
      final api = _FakeApi()
        ..response = const ChatResponse(
          answer: 'Sure thing',
          confidence: 'high',
        );
      final c = _container(api: api);

      await c.read(chatProvider.notifier).send('Hi');

      final reply = c.read(chatProvider).messages.last;
      expect(reply.clarifyingQuestion, isNull);
    });
  });

  group('ChatNotifier — failed send', () {
    test('surfaces error and clears sending when ApiClient.chat throws',
        () async {
      final api = _FakeApi()..throwOnChat = Exception('Network down');
      final c = _container(api: api);

      await c.read(chatProvider.notifier).send('Hello');

      final s = c.read(chatProvider);
      expect(s.sending, isFalse);
      expect(s.error, isNotNull);
      expect(s.error, contains('Network down'));
      // User message was still appended before the failure.
      expect(s.messages.length, 1);
      expect(s.messages.first.role, 'user');
    });

    test('does NOT crash — provider remains readable after error', () async {
      final api = _FakeApi()..throwOnChat = StateError('boom');
      final c = _container(api: api);

      await c.read(chatProvider.notifier).send('Test');

      // Must be able to read state again without throwing.
      expect(() => c.read(chatProvider), returnsNormally);
    });
  });

  group('ChatNotifier — guard rails', () {
    test('ignores empty / whitespace-only messages', () async {
      final api = _FakeApi();
      final c = _container(api: api);

      await c.read(chatProvider.notifier).send('   ');

      // Nothing added, API never called.
      expect(c.read(chatProvider).messages, isEmpty);
      expect(api.lastMessage, isNull);
    });

    test('clear() resets state to empty', () async {
      final api = _FakeApi();
      final c = _container(api: api);

      await c.read(chatProvider.notifier).send('Hello');
      c.read(chatProvider.notifier).clear();

      final s = c.read(chatProvider);
      expect(s.messages, isEmpty);
      expect(s.sending, isFalse);
      expect(s.error, isNull);
    });
  });
}
