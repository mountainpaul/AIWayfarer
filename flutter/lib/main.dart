import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'services/api_client.dart';
import 'services/local_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDb.instance.init();

  // Hydrate the API base URL before any Dio is constructed, so the first
  // request goes to the user's configured backend, not the Env default.
  final prefs = await SharedPreferences.getInstance();
  final storedBaseUrl = prefs.getString(ApiBaseUrlNotifier.prefsKey);

  runApp(
    ProviderScope(
      overrides: [
        if (storedBaseUrl != null && storedBaseUrl.isNotEmpty)
          apiBaseUrlProvider.overrideWith(
            (_) => ApiBaseUrlNotifier(initial: storedBaseUrl),
          ),
      ],
      child: const WayfarerApp(),
    ),
  );
}
