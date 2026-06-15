import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/providers/mode_provider.dart';

ProviderContainer _container() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('modeProvider', () {
    test('defaults to planning', () {
      final c = _container();
      expect(c.read(modeProvider), AppMode.planning);
    });

    test('set() changes state', () {
      final c = _container();
      c.read(modeProvider.notifier).set(AppMode.companion);
      expect(c.read(modeProvider), AppMode.companion);
    });

    test('toggle() switches planning -> companion', () {
      final c = _container();
      c.read(modeProvider.notifier).toggle();
      expect(c.read(modeProvider), AppMode.companion);
    });

    test('toggle() switches companion -> planning', () {
      final c = _container();
      c.read(modeProvider.notifier).set(AppMode.companion);
      c.read(modeProvider.notifier).toggle();
      expect(c.read(modeProvider), AppMode.planning);
    });

    test('toggle() twice returns to original', () {
      final c = _container();
      c.read(modeProvider.notifier).toggle();
      c.read(modeProvider.notifier).toggle();
      expect(c.read(modeProvider), AppMode.planning);
    });
  });
}
