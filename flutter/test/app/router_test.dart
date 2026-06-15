import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/app/router.dart';
import 'package:wayfarer/models/grounding.dart';
import 'package:wayfarer/providers/briefing_provider.dart';
import 'package:wayfarer/providers/chat_provider.dart';
import 'package:wayfarer/providers/grounding_provider.dart';
import 'package:wayfarer/providers/mode_provider.dart';
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

// ── Helper: all provider overrides needed to render every tab ────────────────
List<Override> _allOverrides() {
  return [
    // briefing → null (no-briefing-yet card)
    briefingProvider.overrideWith((ref) async => null),
    // current leg → null
    currentLegProvider.overrideWith((ref) async => null),
    // next booking → null (derived from currentLeg)
    nextBookingProvider.overrideWith((ref) async => null),
    // open task count → 0
    openTaskCountProvider.overrideWith((ref) async => 0),
    // schengen → null (card hides)
    schengenProvider.overrideWith((ref) async => null),
    // coverage → null (card hides)
    coverageProvider.overrideWith((ref) async => null),
    // budget → null (card hides)
    budgetProvider.overrideWith((ref) async => null),
    // trips list → empty
    tripsProvider.overrideWith((ref) async => []),
    // legs list → empty
    legsProvider.overrideWith((ref) async => []),
    // grounding → stub
    groundingProvider.overrideWith((ref) async => const Grounding(
          localTimeIso: '2026-06-14T12:00:00',
        )),
    // grounding service (used by chat provider) → stub
    groundingServiceProvider.overrideWith((_) => _FakeGroundingService()),
    // chat → empty initial state (no API calls)
    chatProvider.overrideWith((ref) => ChatNotifier(ref)),
    // api client → no-op (settings screen reads apiBaseUrlProvider)
    apiBaseUrlProvider.overrideWith((_) => ApiBaseUrlNotifier(initial: 'http://test.local')),
  ];
}

// ── Convenience: pump the full routed app ───────────────────────────────────
Future<void> _pumpApp(
  WidgetTester tester, {
  List<Override> extra = const [],
  String initialLocation = '/',
}) async {
  SharedPreferences.setMockInitialValues({'api_base_url': 'http://test.local'});

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => _TestShellWrapper(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const _NamedPlaceholder('Home')),
          GoRoute(path: '/chat', builder: (_, __) => const _NamedPlaceholder('Chat')),
          GoRoute(
            path: '/trips',
            builder: (_, __) => const _NamedPlaceholder('Trips'),
            routes: [
              GoRoute(
                path: 'leg/:legId',
                builder: (_, state) => _NamedPlaceholder('Leg:${state.pathParameters['legId']}'),
              ),
              GoRoute(path: 'scan-email', builder: (_, __) => const _NamedPlaceholder('ScanEmail')),
              GoRoute(path: 'awards', builder: (_, __) => const _NamedPlaceholder('Awards')),
            ],
          ),
          GoRoute(path: '/companion', builder: (_, __) => const _NamedPlaceholder('Companion')),
          GoRoute(path: '/settings', builder: (_, __) => const _NamedPlaceholder('Settings')),
          GoRoute(path: '/profile', builder: (_, __) => const _NamedPlaceholder('Profile')),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [..._allOverrides(), ...extra],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Lightweight shell that mirrors the real _ShellScaffold's nav logic ───────
//
// We test the real shell in separate tests below.  For route-navigation tests
// we use this thin wrapper so we don't need to stub screen-level DB calls.
class _TestShellWrapper extends ConsumerWidget {
  const _TestShellWrapper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeProvider);
    final loc = GoRouterState.of(context).uri.path;
    final wide = MediaQuery.sizeOf(context).shortestSide >= 600;
    int index = 0;
    if (loc.startsWith('/chat')) index = 1;
    if (loc.startsWith('/trips')) index = 2;
    if (loc.startsWith('/companion')) index = 3;
    if (loc.startsWith('/settings')) index = 4;
    if (loc.startsWith('/profile')) index = 4;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Wayfarer'),
        actions: [
          Row(children: [
            const Text('Plan'),
            Switch(
              value: mode == AppMode.companion,
              onChanged: (v) => ref.read(modeProvider.notifier).set(
                    v ? AppMode.companion : AppMode.planning,
                  ),
            ),
            const Text('Companion'),
          ]),
        ],
      ),
      body: child,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) {
                const paths = ['/', '/chat', '/trips', '/companion', '/settings'];
                context.go(paths[i]);
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Today'),
                NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
                NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Trips'),
                NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Companion'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
              ],
            ),
    );
  }
}

class _NamedPlaceholder extends StatelessWidget {
  const _NamedPlaceholder(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => Center(child: Text('Screen:$name'));
}

// ── Actual shell scaffold tests ───────────────────────────────────────────────
//
// We pump the *real* routerProvider to test the real _ShellScaffold.
Future<void> _pumpRealApp(
  WidgetTester tester, {
  List<Override> extra = const [],
}) async {
  SharedPreferences.setMockInitialValues({'api_base_url': 'http://test.local'});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [..._allOverrides(), ...extra],
      child: Consumer(
        builder: (context, ref, _) {
          final router = ref.watch(routerProvider);
          return MaterialApp.router(routerConfig: router);
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ──────────────────────────────────────────────────────────────────────────────
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── _indexForLocation logic ──────────────────────────────────────────────
  group('_indexForLocation', () {
    // We verify the mapping indirectly via the NavigationBar's selectedIndex
    // using the thin test wrapper above.
    // Force phone size so NavigationBar is rendered (shortestSide < 600).
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('/ maps to index 0 (Today)', (tester) async {
      phone(tester);
      await _pumpApp(tester, initialLocation: '/');
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 0);
    });

    testWidgets('/chat maps to index 1', (tester) async {
      phone(tester);
      await _pumpApp(tester, initialLocation: '/chat');
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 1);
    });

    testWidgets('/trips maps to index 2', (tester) async {
      phone(tester);
      await _pumpApp(tester, initialLocation: '/trips');
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 2);
    });

    testWidgets('/companion maps to index 3', (tester) async {
      phone(tester);
      await _pumpApp(tester, initialLocation: '/companion');
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 3);
    });

    testWidgets('/settings maps to index 4', (tester) async {
      phone(tester);
      await _pumpApp(tester, initialLocation: '/settings');
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 4);
    });

    testWidgets('/profile maps to index 4 (Settings tab stays lit)', (tester) async {
      phone(tester);
      await _pumpApp(tester, initialLocation: '/profile');
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 4);
    });

    testWidgets('/trips/scan-email keeps trips tab (index 2)', (tester) async {
      phone(tester);
      await _pumpApp(tester, initialLocation: '/trips/scan-email');
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 2);
    });

    testWidgets('/trips/awards keeps trips tab (index 2)', (tester) async {
      phone(tester);
      await _pumpApp(tester, initialLocation: '/trips/awards');
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 2);
    });
  });

  // ── NavigationBar tap → correct screen ──────────────────────────────────
  group('NavigationBar tap navigation', () {
    void setPhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('tapping Chat destination shows Chat screen', (tester) async {
      setPhone(tester);
      await _pumpApp(tester, initialLocation: '/');
      expect(find.text('Screen:Home'), findsOneWidget);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Chat'));
      await tester.pumpAndSettle();

      expect(find.text('Screen:Chat'), findsOneWidget);
    });

    testWidgets('tapping Trips destination shows Trips screen', (tester) async {
      setPhone(tester);
      await _pumpApp(tester, initialLocation: '/');

      await tester.tap(find.widgetWithText(NavigationDestination, 'Trips'));
      await tester.pumpAndSettle();

      expect(find.text('Screen:Trips'), findsOneWidget);
    });

    testWidgets('tapping Companion destination shows Companion screen', (tester) async {
      setPhone(tester);
      await _pumpApp(tester, initialLocation: '/');

      await tester.tap(find.widgetWithText(NavigationDestination, 'Companion'));
      await tester.pumpAndSettle();

      expect(find.text('Screen:Companion'), findsOneWidget);
    });

    testWidgets('tapping Settings destination shows Settings screen', (tester) async {
      setPhone(tester);
      await _pumpApp(tester, initialLocation: '/');

      await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Screen:Settings'), findsOneWidget);
    });

    testWidgets('tapping Today destination returns to Home', (tester) async {
      setPhone(tester);
      await _pumpApp(tester, initialLocation: '/chat');
      expect(find.text('Screen:Chat'), findsOneWidget);

      await tester.tap(find.widgetWithText(NavigationDestination, 'Today'));
      await tester.pumpAndSettle();

      expect(find.text('Screen:Home'), findsOneWidget);
    });
  });

  // ── Responsive layout: wide vs narrow ───────────────────────────────────
  group('responsive layout', () {
    testWidgets('narrow phone shows NavigationBar, not NavigationRail', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpRealApp(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('wide tablet shows NavigationRail, not NavigationBar', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpRealApp(tester);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('phone in landscape (wide but shortestSide < 600) shows NavigationBar', (tester) async {
      // 740 wide, 360 tall — shortestSide == 360 < 600
      tester.view.physicalSize = const Size(740, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpRealApp(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  // ── Plan/Companion mode toggle ───────────────────────────────────────────
  group('Plan/Companion switch', () {
    testWidgets('Switch starts off (planning mode)', (tester) async {
      await _pumpRealApp(tester);

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);
    });

    testWidgets('tapping Switch flips to companion mode', (tester) async {
      await _pumpRealApp(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
    });

    testWidgets('tapping Switch twice returns to planning mode', (tester) async {
      await _pumpRealApp(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);
    });

    testWidgets('Plan and Companion labels are visible in AppBar', (tester) async {
      await _pumpRealApp(tester);

      // 'Plan' appears only in the AppBar switch row.
      expect(find.text('Plan'), findsOneWidget);
      // 'Companion' appears in both the switch row AND the nav destination
      // label — so at least one is guaranteed.
      expect(find.text('Companion'), findsWidgets);
    });
  });

  // ── routerProvider: initial route ────────────────────────────────────────
  group('routerProvider routes', () {
    testWidgets('initial route / renders HomeScreen', (tester) async {
      await _pumpRealApp(tester);
      // HomeScreen renders a RefreshIndicator wrapping a ListView with cards.
      // With all providers stubbed to empty, it shows the "No briefing" card.
      expect(find.byType(RefreshIndicator), findsWidgets);
    });

    testWidgets('AppBar title is AI Wayfarer', (tester) async {
      await _pumpRealApp(tester);
      expect(find.text('AI Wayfarer'), findsOneWidget);
    });
  });

  // ── NavigationRail tap → correct route (_go switch, wide layout) ─────────
  //
  // These tests pump the REAL _ShellScaffold so the real _go() switch is
  // exercised, not the thin wrapper. We force tablet size (shortestSide ≥ 600).
  group('NavigationRail tap navigation (real shell, wide layout)', () {
    void tablet(WidgetTester tester) {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('rail shows 5 destinations', (tester) async {
      tablet(tester);
      await _pumpRealApp(tester);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, hasLength(5));
    });

    testWidgets('rail selectedIndex is 0 on initial route /', (tester) async {
      tablet(tester);
      await _pumpRealApp(tester);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 0);
    });

    testWidgets('tapping Chat rail destination navigates to /chat', (tester) async {
      tablet(tester);
      await _pumpRealApp(tester);

      // NavigationRail labels are plain Text widgets inside InkWells.
      // Find by text inside the rail.
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 1);
    });

    testWidgets('tapping Trips rail destination navigates to /trips', (tester) async {
      tablet(tester);
      await _pumpRealApp(tester);

      await tester.tap(find.text('Trips'));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 2);
    });

    testWidgets('tapping Companion rail destination navigates to /companion', (tester) async {
      tablet(tester);
      await _pumpRealApp(tester);

      // 'Companion' appears both in the AppBar mode-switch label and the rail
      // destination. Tap the one that is a descendant of the NavigationRail.
      final railFinder = find.byType(NavigationRail);
      await tester.tap(find.descendant(of: railFinder, matching: find.text('Companion')));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 3);
    });

    testWidgets('tapping Settings rail destination navigates to /settings', (tester) async {
      tablet(tester);
      await _pumpRealApp(tester);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 4);
    });

    testWidgets('tapping Today rail destination from /chat returns to /', (tester) async {
      tablet(tester);
      // Start at /chat.
      SharedPreferences.setMockInitialValues({'api_base_url': 'http://test.local'});
      await tester.pumpWidget(
        ProviderScope(
          overrides: _allOverrides(),
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Navigate to chat first.
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
        1,
      );

      // Now tap Today.
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 0);
    });
  });
}
