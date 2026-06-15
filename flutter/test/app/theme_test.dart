import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/app/theme.dart';

void main() {
  group('WayfarerTheme.light()', () {
    late ThemeData light;

    setUpAll(() {
      light = WayfarerTheme.light();
    });

    test('uses Material 3', () {
      expect(light.useMaterial3, isTrue);
    });

    test('brightness is light', () {
      expect(light.colorScheme.brightness, Brightness.light);
    });

    test('card elevation is 1', () {
      expect(light.cardTheme.elevation, 1.0);
    });

    test('card margin matches spec', () {
      expect(
        light.cardTheme.margin,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      );
    });
  });

  group('WayfarerTheme.dark()', () {
    late ThemeData dark;

    setUpAll(() {
      dark = WayfarerTheme.dark();
    });

    test('uses Material 3', () {
      expect(dark.useMaterial3, isTrue);
    });

    test('brightness is dark', () {
      expect(dark.colorScheme.brightness, Brightness.dark);
    });

    test('card elevation is 1', () {
      expect(dark.cardTheme.elevation, 1.0);
    });

    test('card margin matches spec', () {
      expect(
        dark.cardTheme.margin,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      );
    });
  });

  group('light vs dark differ', () {
    test('brightness differs', () {
      final light = WayfarerTheme.light();
      final dark = WayfarerTheme.dark();
      expect(
        light.colorScheme.brightness,
        isNot(dark.colorScheme.brightness),
      );
    });

    test('primary colors differ (seed produces different outputs)', () {
      final light = WayfarerTheme.light();
      final dark = WayfarerTheme.dark();
      expect(
        light.colorScheme.primary,
        isNot(dark.colorScheme.primary),
      );
    });
  });

  group('WayfarerTheme.parseLegColor()', () {
    test('parses a 6-char hex without #', () {
      // Pure red
      final c = WayfarerTheme.parseLegColor('ff0000');
      expect((c.r * 255.0).round().clamp(0, 255), 255);
      expect((c.g * 255.0).round().clamp(0, 255), 0);
      expect((c.b * 255.0).round().clamp(0, 255), 0);
    });

    test('parses a 6-char hex with #', () {
      final c = WayfarerTheme.parseLegColor('#00ff00');
      expect((c.g * 255.0).round().clamp(0, 255), 255);
      expect((c.r * 255.0).round().clamp(0, 255), 0);
    });

    test('parses an 8-char ARGB hex', () {
      // Full opacity blue
      final c = WayfarerTheme.parseLegColor('ff0000ff');
      expect((c.b * 255.0).round().clamp(0, 255), 255);
    });

    test('returns fallback for null', () {
      final c = WayfarerTheme.parseLegColor(null);
      expect(c, Colors.indigo);
    });

    test('returns fallback for empty string', () {
      final c = WayfarerTheme.parseLegColor('');
      expect(c, Colors.indigo);
    });

    test('returns fallback for invalid hex', () {
      final c = WayfarerTheme.parseLegColor('zzzzzz');
      expect(c, Colors.indigo);
    });

    test('returns custom fallback', () {
      const custom = Color(0xFFABCDEF);
      final c = WayfarerTheme.parseLegColor(null, fallback: custom);
      expect(c, custom);
    });

    test('wrong-length hex returns fallback', () {
      // 5 chars — neither 6 nor 8
      final c = WayfarerTheme.parseLegColor('fff00');
      expect(c, Colors.indigo);
    });
  });
}
