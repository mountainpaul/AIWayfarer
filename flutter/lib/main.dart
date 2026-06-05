import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app/app.dart';
import 'providers/quiet_mode_provider.dart';
import 'services/api_client.dart';
import 'services/local_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  await LocalDb.instance.init();

  final prefs = await SharedPreferences.getInstance();
  final storedBaseUrl = prefs.getString(ApiBaseUrlNotifier.prefsKey);
  final storedQuietMode = prefs.getBool(QuietModeNotifier.prefsKey) ?? false;
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  runApp(
    ProviderScope(
      overrides: [
        if (storedBaseUrl != null && storedBaseUrl.isNotEmpty)
          apiBaseUrlProvider.overrideWith(
            (_) => ApiBaseUrlNotifier(initial: storedBaseUrl),
          ),
        quietModeProvider.overrideWith(
          (_) => QuietModeNotifier(initial: storedQuietMode),
        ),
      ],
      child: WayfarerApp(showOnboarding: !onboardingComplete),
    ),
  );
}
