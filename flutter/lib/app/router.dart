import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/awards/awards_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/companion/companion_dashboard.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/travel_profile_screen.dart';
import '../features/trips/email_scan_screen.dart';
import '../features/trips/leg_detail_screen.dart';
import '../features/trips/trips_screen.dart';
import '../providers/mode_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => _ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (_, __) => const ChatScreen(),
          ),
          GoRoute(
            path: '/trips',
            builder: (_, __) => const TripsScreen(),
            routes: [
              GoRoute(
                path: 'leg/:legId',
                builder: (context, state) => LegDetailScreen(
                  legId: state.pathParameters['legId']!,
                ),
              ),
              GoRoute(
                path: 'scan-email',
                builder: (_, __) => const EmailScanScreen(),
              ),
              GoRoute(
                path: 'awards',
                builder: (_, __) => const AwardsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/companion',
            builder: (_, __) => const CompanionDashboard(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const TravelProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

class _ShellScaffold extends ConsumerWidget {
  const _ShellScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeProvider);
    final location = GoRouterState.of(context).uri.path;
    final index = _indexForLocation(location);
    // Tablet/desktop get the side rail; phones get a bottom bar in BOTH
    // orientations. Key off shortestSide (not width) so a phone in landscape —
    // which is "wide" but short — doesn't get the vertical rail and overflow it.
    final wide = MediaQuery.sizeOf(context).shortestSide >= 600;

    final appBar = AppBar(
      title: const Text('AI Wayfarer'),
      actions: [
        Row(
          children: [
            const Text('Plan'),
            Switch(
              value: mode == AppMode.companion,
              onChanged: (v) {
                ref.read(modeProvider.notifier).set(
                      v ? AppMode.companion : AppMode.planning,
                    );
              },
            ),
            const Text('Companion'),
            const SizedBox(width: 8),
          ],
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => _go(context, i),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today),
                  label: Text('Today'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: Text('Chat'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: Text('Trips'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: Text('Companion'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: child,
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        // Clamp system font scaling for the nav bar so a long label like
        // "Companion" stays on one line instead of wrapping.
        maxScaleFactor: 1.0,
        child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _go(context, i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Companion',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        ),
      ),
    );
  }

  int _indexForLocation(String loc) {
    if (loc.startsWith('/chat')) return 1;
    if (loc.startsWith('/trips')) return 2;
    if (loc.startsWith('/companion')) return 3;
    if (loc.startsWith('/settings')) return 4;
    // The travel-profile screen is reached from Settings; keep that tab lit.
    if (loc.startsWith('/profile')) return 4;
    return 0;
  }

  void _go(BuildContext context, int i) {
    switch (i) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/chat');
        break;
      case 2:
        context.go('/trips');
        break;
      case 3:
        context.go('/companion');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }
}
