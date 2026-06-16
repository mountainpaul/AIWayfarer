// Tests for DateRangeField widget and the fmtDate helper.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/trips/widgets/date_range_field.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps a [DateRangeField] inside a full MaterialApp with localization
/// delegates (required for showDateRangePicker).
Future<void> _pump(
  WidgetTester tester, {
  DateTime? start,
  DateTime? end,
  void Function(DateTime, DateTime)? onPicked,
  String label = 'Dates',
  bool hasError = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Center(
          child: DateRangeField(
            start: start,
            end: end,
            onPicked: onPicked ?? (_, __) {},
            label: label,
            hasError: hasError,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// fmtDate unit tests
// ---------------------------------------------------------------------------

void main() {
  group('fmtDate', () {
    test('formats a date with single-digit month and day with zero-padding',
        () {
      final d = DateTime(2026, 1, 5);
      expect(fmtDate(d), equals('2026-01-05'));
    });

    test('formats a date with double-digit month and day correctly', () {
      final d = DateTime(2026, 12, 25);
      expect(fmtDate(d), equals('2026-12-25'));
    });

    test('pads single-digit day correctly', () {
      final d = DateTime(2025, 7, 1);
      expect(fmtDate(d), equals('2025-07-01'));
    });

    test('pads single-digit month correctly', () {
      final d = DateTime(2026, 3, 14);
      expect(fmtDate(d), equals('2026-03-14'));
    });
  });

  // ---------------------------------------------------------------------------
  // DateRangeField widget tests
  // ---------------------------------------------------------------------------

  group('DateRangeField — label rendering', () {
    testWidgets('shows custom label when start and end are null',
        (tester) async {
      _tallSurface(tester);
      await _pump(tester, label: 'Pick dates');

      expect(find.text('Pick dates'), findsOneWidget);
    });

    testWidgets('shows default label when no label supplied and dates are null',
        (tester) async {
      _tallSurface(tester);
      await _pump(tester);

      // Default label is 'Dates'.
      expect(find.text('Dates'), findsOneWidget);
    });

    testWidgets('shows "start  →  end" rendering when dates are set',
        (tester) async {
      _tallSurface(tester);
      final start = DateTime(2026, 6, 23);
      final end = DateTime(2026, 6, 24);
      await _pump(tester, start: start, end: end);

      // fmtDate formats both dates; rendered as "2026-06-23  →  2026-06-24".
      expect(
        find.text('${fmtDate(start)}  →  ${fmtDate(end)}'),
        findsOneWidget,
      );
    });

    testWidgets('shows label (not start→end) when only start is set',
        (tester) async {
      _tallSurface(tester);
      await _pump(tester, start: DateTime(2026, 6, 23), label: 'Pick dates');

      // end is null, so label shown instead of formatted dates.
      expect(find.text('Pick dates'), findsOneWidget);
    });

    testWidgets('shows label (not start→end) when only end is set',
        (tester) async {
      _tallSurface(tester);
      await _pump(tester, end: DateTime(2026, 6, 24), label: 'Pick dates');

      // start is null, so label shown instead of formatted dates.
      expect(find.text('Pick dates'), findsOneWidget);
    });
  });

  group('DateRangeField — hasError styling', () {
    testWidgets('renders without error styling when hasError is false',
        (tester) async {
      _tallSurface(tester);
      await _pump(tester, hasError: false);

      // OutlinedButton should be present.
      expect(find.byType(OutlinedButton), findsOneWidget);
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      // No error style — the style is null (uses default).
      expect(button.style, isNull);
    });

    testWidgets('applies error foreground color when hasError is true',
        (tester) async {
      _tallSurface(tester);
      await _pump(tester, hasError: true);

      expect(find.byType(OutlinedButton), findsOneWidget);
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      // Error styling is applied (style is non-null when hasError is true).
      expect(button.style, isNotNull);
    });
  });

  group('DateRangeField — tap opens picker', () {
    testWidgets('tapping the button opens the date-range picker dialog',
        (tester) async {
      _tallSurface(tester);
      await _pump(tester, label: 'Pick dates');

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      // showDateRangePicker renders a dialog containing a 'Save' button.
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('DateRangeField — icon', () {
    testWidgets('renders the date_range icon', (tester) async {
      _tallSurface(tester);
      await _pump(tester);

      expect(find.byIcon(Icons.date_range), findsOneWidget);
    });
  });
}
