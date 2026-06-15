import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wayfarer/features/chat/chat_screen.dart';
import 'package:wayfarer/features/chat/widgets/message_bubble.dart';
import 'package:wayfarer/features/chat/widgets/ptt_button.dart';
import 'package:wayfarer/models/chat_message.dart';
import 'package:wayfarer/models/grounding.dart';
import 'package:wayfarer/providers/chat_provider.dart';
import 'package:wayfarer/providers/quiet_mode_provider.dart';
import 'package:wayfarer/services/grounding_service.dart';
import 'package:wayfarer/services/local_db.dart';
import 'package:wayfarer/services/location_service.dart';
import 'package:wayfarer/services/voice_service.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeLocation extends LocationService {
  @override
  Future<Position?> currentPosition() async => null;
}

class _FakeGrounding extends GroundingService {
  _FakeGrounding(LocalDb db)
      : super(db: db, location: _FakeLocation());

  @override
  Future<Grounding> compose() async =>
      const Grounding(localTimeIso: '2026-06-14T10:00:00.000');
}

class _FakeVoiceService extends VoiceService {
  @override
  Future<bool> init() async => false;
  @override
  Future<void> startListening({required void Function(String, bool) onResult}) async {}
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> speak(String text) async {}
}

/// Minimal ChatNotifier substitute: no network, no SharedPreferences.
/// Extends ChatNotifier so it satisfies the provider's StateNotifier<ChatState>
/// type requirement. We seed initial state immediately and override send()
/// to record calls without touching the network.
///
/// Implementation note: ChatNotifier._restore() is library-private so we cannot
/// override it here. Instead we pre-seed SharedPreferences to be empty so that
/// the real _restore() becomes a no-op, and we set the seed state via a
/// post-frame callback scheduled after construction.
class _FakeChatNotifier extends ChatNotifier {
  _FakeChatNotifier(super.ref);

  final List<String> sent = [];

  /// Apply a desired seed state. Call this *after* the notifier is created
  /// (via overrideWith) and before pumpWidget / pumpAndSettle so the state
  /// takes effect before the widget reads it. Since _restore() is async and
  /// has already been awaited by pumpAndSettle, setting state here wins.
  void seed(ChatState s) {
    state = s;
  }

  @override
  Future<void> send(String text) async {
    if (text.trim().isEmpty || state.sending) return;
    sent.add(text.trim());
    final userMsg = ChatMessage(
      id: 'u-fake',
      role: 'user',
      content: text.trim(),
    );
    const assistantMsg = ChatMessage(
      id: 'a-fake',
      role: 'assistant',
      content: 'Fake reply',
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      sending: false,
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

late LocalDb _db;

void _tallSurface(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 3000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

/// Pumps the widget tree and waits for async init (_restore) to settle,
/// then optionally applies a seed state.
Future<_FakeChatNotifier> _pump(
  WidgetTester tester, {
  ChatState? seed,
}) async {
  // We capture the notifier via a box so we can return it.
  _FakeChatNotifier? captured;

  await tester.pumpWidget(ProviderScope(
    overrides: [
      chatProvider.overrideWith((ref) {
        final n = _FakeChatNotifier(ref);
        captured = n;
        return n;
      }),
      quietModeProvider.overrideWith((_) => QuietModeNotifier(initial: false)),
      voiceServiceProvider.overrideWithValue(_FakeVoiceService()),
      groundingServiceProvider.overrideWithValue(_FakeGrounding(_db)),
    ],
    child: const MaterialApp(home: Scaffold(body: ChatScreen())),
  ));

  // Wait for _restore() async to complete (reads empty prefs → no-op).
  await tester.pumpAndSettle();

  final notifier = captured!;
  if (seed != null) {
    notifier.seed(seed);
    await tester.pump();
  }
  return notifier;
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _db = LocalDb.newForTest();
    await _db.init(pathOverride: inMemoryDatabasePath);
  });

  tearDown(() async {
    await _db.close();
  });

  group('ChatScreen — empty state', () {
    testWidgets('shows placeholder text when messages list is empty', (tester) async {
      await _pump(tester);

      expect(find.textContaining('Ask anything'), findsOneWidget);
      expect(find.byType(MessageBubble), findsNothing);
    });

    testWidgets('shows text input field', (tester) async {
      await _pump(tester);

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows send button when not loading', (tester) async {
      await _pump(tester);

      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('hint text is "Ask AI Wayfarer..."', (tester) async {
      await _pump(tester);

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.decoration?.hintText, 'Ask AI Wayfarer...');
    });

    testWidgets('shows PTT button', (tester) async {
      await _pump(tester);

      expect(find.byType(PttButton), findsOneWidget);
    });

    testWidgets('shows voice-reply toggle icon button (off initially)', (tester) async {
      await _pump(tester);

      expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);
    });
  });

  group('ChatScreen — message history display', () {
    testWidgets('renders MessageBubble for each message', (tester) async {
      _tallSurface(tester);
      await _pump(tester, seed: ChatState(messages: const [
        ChatMessage(id: '1', role: 'user', content: 'Hello'),
        ChatMessage(id: '2', role: 'assistant', content: 'Hi there!'),
        ChatMessage(id: '3', role: 'user', content: 'How are you?'),
      ]));

      expect(find.byType(MessageBubble), findsNWidgets(3));
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('How are you?'), findsOneWidget);
    });

    testWidgets('does NOT show placeholder when messages are present', (tester) async {
      await _pump(tester, seed: ChatState(messages: const [
        ChatMessage(id: '1', role: 'user', content: 'Hey'),
      ]));

      expect(find.textContaining('Ask anything'), findsNothing);
    });

    testWidgets('renders single assistant message bubble', (tester) async {
      _tallSurface(tester);
      await _pump(tester, seed: ChatState(messages: const [
        ChatMessage(id: 'a1', role: 'assistant', content: 'Welcome to AI Wayfarer!'),
      ]));

      expect(find.byType(MessageBubble), findsOneWidget);
      expect(find.text('Welcome to AI Wayfarer!'), findsOneWidget);
    });
  });

  group('ChatScreen — sending state', () {
    testWidgets('shows CircularProgressIndicator when sending=true', (tester) async {
      await _pump(tester, seed: ChatState(
        messages: const [ChatMessage(id: '1', role: 'user', content: 'Sending...')],
        sending: true,
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
    });

    testWidgets('send IconButton is disabled when sending=true', (tester) async {
      await _pump(tester, seed: ChatState(messages: const [], sending: true));

      final sendButtons = tester.widgetList<IconButton>(find.byType(IconButton));
      final sendBtn = sendButtons.last;
      expect(sendBtn.onPressed, isNull);
    });
  });

  group('ChatScreen — error banner', () {
    testWidgets('shows error text when state.error is non-null', (tester) async {
      await _pump(tester, seed: ChatState(error: 'Connection timed out'));

      expect(find.textContaining('Error:'), findsOneWidget);
      expect(find.textContaining('Connection timed out'), findsOneWidget);
    });

    testWidgets('no error text when state.error is null', (tester) async {
      await _pump(tester);

      expect(find.textContaining('Error:'), findsNothing);
    });
  });

  group('ChatScreen — send interaction', () {
    testWidgets('typing and tapping send calls notifier.send()', (tester) async {
      _tallSurface(tester);
      final notifier = await _pump(tester);

      await tester.enterText(find.byType(TextField), 'Book me a flight to Rome');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(notifier.sent, contains('Book me a flight to Rome'));
    });

    testWidgets('submitting via keyboard onSubmitted calls notifier.send()', (tester) async {
      _tallSurface(tester);
      final notifier = await _pump(tester);

      await tester.enterText(find.byType(TextField), 'Weather in Paris?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(notifier.sent, contains('Weather in Paris?'));
    });

    testWidgets('empty text does not call notifier.send()', (tester) async {
      final notifier = await _pump(tester);

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(notifier.sent, isEmpty);
    });

    testWidgets('text field is cleared after successful send', (tester) async {
      _tallSurface(tester);
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'Hello world');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text ?? '', isEmpty);
    });

    testWidgets('messages appear in ListView after send', (tester) async {
      _tallSurface(tester);
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'What time is it?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.byType(MessageBubble), findsWidgets);
      expect(find.text('What time is it?'), findsOneWidget);
    });
  });

  group('ChatScreen — voice-reply toggle', () {
    testWidgets('tapping volume button toggles to volume_up', (tester) async {
      await _pump(tester);

      expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.volume_off_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_outlined), findsNothing);
    });

    testWidgets('tapping volume_up toggles back to volume_off_outlined', (tester) async {
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.volume_off_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.volume_up));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);
    });
  });
}
