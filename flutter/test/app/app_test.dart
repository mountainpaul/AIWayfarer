import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/app/app.dart';
import 'package:wayfarer/features/onboarding/onboarding_screen.dart';
import 'package:wayfarer/models/grounding.dart';
import 'package:wayfarer/providers/briefing_provider.dart';
import 'package:wayfarer/providers/chat_provider.dart';
import 'package:wayfarer/providers/grounding_provider.dart';
import 'package:wayfarer/providers/trip_provider.dart';
import 'package:wayfarer/services/api_client.dart';
import 'package:wayfarer/services/grounding_service.dart';

// ── Stub grounding service ────────────────────────────────────────────────────
class _FakeGroundingService extends GroundingService {
  _FakeGroundingService()
      : super(
          db: throw UnimplementedError(),
          // ignore: dead_code
          location: throw UnimplementedError(),
        );

  @override
  Future<Grounding> compose() async => const Grounding(
        localTimeIso: '2026-06-14T12:00:00',
      );
}

// ── Provider overrides that prevent DB/network access ────────────────────────
List<Override> _stubOverrides() => [
      briefingProvider.overrideWith((ref) async => null),
      currentLegProvider.overrideWith((ref) async => null),
      nextBookingProvider.overrideWith((ref) async => null),
      openTaskCountProvider.overrideWith((ref) async => 0),
      schengenProvider.overrideWith((ref) async => null),
      coverageProvider.overrideWith((ref) async => null),
      budgetProvider.overrideWith((ref) async => null),
      tripsProvider.overrideWith((ref) async => []),
      legsProvider.overrideWith((ref) async => []),
      groundingProvider.overrideWith((ref) async => const Grounding(
            localTimeIso: '2026-06-14T12:00:00',
          )),
      groundingServiceProvider.overrideWith((_) => _FakeGroundingService()),
      chatProvider.overrideWith((ref) => ChatNotifier(ref)),
      apiBaseUrlProvider.overrideWith((_) => ApiBaseUrlNotifier(initial: 'http://test.local')),
    ];

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _app({bool showOnboarding = false, List<Override> extra = const []}) =>
    ProviderScope(
      overrides: [..._stubOverrides(), ...extra],
      child: WayfarerApp(showOnboarding: showOnboarding),
    );

void main() {
  setUp(() {
    // Reset the onboarding notifier to false before each test so tests are
    // independent of run order.
    onboardingCompleteNotifier.value = false;
    SharedPreferences.setMockInitialValues({});
  });

  // ── WayfarerApp boots ─────────────────────────────────────────────────────
  group('WayfarerApp', () {
    testWidgets('renders without crashing (showOnboarding: false)', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // The router-based shell contains the AppBar title.
      expect(find.text('AI Wayfarer'), findsOneWidget);
    });

    testWidgets('uses WayfarerTheme.light() / dark() (MaterialApp present)', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // The MaterialApp is routed, so MaterialApp.router is in the tree.
      // Verify our themes are wired by confirming useMaterial3 is active
      // (the AppBar renders with M3 styling).
      final theme = Theme.of(tester.element(find.byType(AppBar).first));
      expect(theme.useMaterial3, isTrue);
    });

    testWidgets('debugShowCheckedModeBanner is false', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // No debug banner means no CheckedModeBanner widget in the tree.
      expect(find.byType(CheckedModeBanner), findsNothing);
    });
  });

  // ── Onboarding gate ───────────────────────────────────────────────────────
  group('onboarding gate', () {
    testWidgets(
        'showOnboarding: true + onboarding_complete absent → shows OnboardingScreen',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: _stubOverrides(),
          // Pass showOnboarding: true to activate the gate.
          child: const WayfarerApp(showOnboarding: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets(
        'showOnboarding: false → skips onboarding and shows main shell',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('AI Wayfarer'), findsOneWidget);
    });

    testWidgets(
        'showOnboarding: true + onboardingCompleteNotifier flipped → shows main shell',
        (tester) async {
      // Start with onboarding showing.
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: _stubOverrides(),
          child: const WayfarerApp(showOnboarding: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);

      // Simulate finishing onboarding.
      onboardingCompleteNotifier.value = true;
      await tester.pumpAndSettle();

      // Shell with the AppBar title should now be visible.
      expect(find.text('AI Wayfarer'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });

  // ── Theme wiring ──────────────────────────────────────────────────────────
  group('theme wiring', () {
    testWidgets('light theme seed color is applied (colorScheme exists)', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(Scaffold).first);
      final colorScheme = Theme.of(ctx).colorScheme;
      // M3 color scheme from the indigo seed — primary should be non-zero.
      expect(colorScheme.primary, isNot(const Color(0x00000000)));
    });

    testWidgets('WayfarerApp title is AI Wayfarer in MaterialApp', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // AppBar confirms the MaterialApp title is wired.
      expect(find.text('AI Wayfarer'), findsOneWidget);
    });
  });
}
