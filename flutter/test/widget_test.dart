import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wayfarer/app/app.dart';

void main() {
  testWidgets(
    'app boots without crashing',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: WayfarerApp()));
      await tester.pump();
      expect(find.text('AI Wayfarer'), findsWidgets);
    },
    // Skipped until we wire a LocalDb test fixture. The app's providers
    // transitively depend on LocalDb.instance.init(), which needs path_provider
    // mocked and sqflite_common_ffi for in-memory storage. Tracked in
    // MANUAL_TODO — out of scope for v0.5.
    skip: 'requires LocalDb test fixture (path_provider mock + sqflite_common_ffi)',
  );
}
