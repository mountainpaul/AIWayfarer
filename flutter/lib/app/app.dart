import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/onboarding_screen.dart';
import 'router.dart';
import 'theme.dart';

/// Required by Material date/range pickers (showDateRangePicker) and other
/// localized widgets. Without these, those pickers throw at runtime.
const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
const _supportedLocales = <Locale>[Locale('en')];

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
            localizationsDelegates: _localizationsDelegates,
            supportedLocales: _supportedLocales,
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
          localizationsDelegates: _localizationsDelegates,
          supportedLocales: _supportedLocales,
        );
      },
    );
  }
}
