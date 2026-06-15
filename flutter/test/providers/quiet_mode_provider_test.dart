import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/providers/quiet_mode_provider.dart';

ProviderContainer _container({bool initial = false}) {
  final c = ProviderContainer(
    overrides: [
      quietModeProvider.overrideWith(
        (_) => QuietModeNotifier(initial: initial),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('quietModeProvider', () {
    test('defaults to false', () {
      final c = _container();
      expect(c.read(quietModeProvider), isFalse);
    });

    test('seeded initial value of true is reflected in state', () {
      final c = _container(initial: true);
      expect(c.read(quietModeProvider), isTrue);
    });

    test('set(true) updates state', () async {
      final c = _container();
      await c.read(quietModeProvider.notifier).set(true);
      expect(c.read(quietModeProvider), isTrue);
    });

    test('set(false) after true updates state', () async {
      final c = _container(initial: true);
      await c.read(quietModeProvider.notifier).set(false);
      expect(c.read(quietModeProvider), isFalse);
    });

    test('set(true) persists to SharedPreferences', () async {
      final c = _container();
      await c.read(quietModeProvider.notifier).set(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(QuietModeNotifier.prefsKey), isTrue);
    });

    test('set(false) persists false to SharedPreferences', () async {
      final c = _container(initial: true);
      await c.read(quietModeProvider.notifier).set(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(QuietModeNotifier.prefsKey), isFalse);
    });

    test('hydration from seeded pref via initial constructor arg', () async {
      SharedPreferences.setMockInitialValues(
          {QuietModeNotifier.prefsKey: true});
      final prefs = await SharedPreferences.getInstance();
      final seeded = prefs.getBool(QuietModeNotifier.prefsKey) ?? false;

      final c = ProviderContainer(
        overrides: [
          quietModeProvider.overrideWith(
            (_) => QuietModeNotifier(initial: seeded),
          ),
        ],
      );
      addTearDown(c.dispose);

      expect(c.read(quietModeProvider), isTrue);
    });
  });
}
