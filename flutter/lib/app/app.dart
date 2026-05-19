import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/onboarding_screen.dart';
import 'router.dart';
import 'theme.dart';

class WayfarerApp extends ConsumerWidget {
  const WayfarerApp({this.showOnboarding = false, super.key});

  final bool showOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<bool>(
      valueListenable: onboardingCompleteNotifier,
      builder: (context, completed, _) {
        if (showOnboarding && !completed) {
          return MaterialApp(
            title: 'AI Wayfarer',
            theme: WayfarerTheme.light(),
            darkTheme: WayfarerTheme.dark(),
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            home: const OnboardingScreen(),
          );
        }

        final router = ref.watch(routerProvider);
        return MaterialApp.router(
          title: 'AI Wayfarer',
          theme: WayfarerTheme.light(),
          darkTheme: WayfarerTheme.dark(),
          themeMode: ThemeMode.system,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
