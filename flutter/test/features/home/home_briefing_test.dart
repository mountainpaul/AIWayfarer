// Tests for the _GenerateBriefingCard that renders when briefingProvider
// resolves to null. Verifies:
// - "No briefing yet for today." text and Generate button render
// - Tapping Generate calls apiClient.generateBriefing() (fake override)
// - Busy spinner appears while the request is in-flight
// - Snackbar appears on error

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer/features/home/home_screen.dart';
import 'package:wayfarer/models/briefing.dart';
import 'package:wayfarer/providers/briefing_provider.dart';
import 'package:wayfarer/providers/trip_provider.dart';
import 'package:wayfarer/services/api_client.dart';

// ── Fake ApiClient ─────────────────────────────────────────────────────────────

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');

  int generateCallCount = 0;
  bool shouldThrow = false;
  // Completer lets tests pause the call mid-flight to assert busy state.
  Completer<Briefing>? _pending;

  void holdNext() {
    _pending = Completer<Briefing>();
  }

  void releaseNext(Briefing b) => _pending?.complete(b);

  @override
  Future<Briefing> generateBriefing({String? date}) async {
    generateCallCount++;
    if (_pending != null) {
      final result = await _pending!.future;
      _pending = null;
      return result;
    }
    if (shouldThrow) throw Exception('backend unreachable');
    return const Briefing(id: 'b-new', date: '2026-06-15', markdown: 'Fresh.');
  }

  // Silence all other endpoints so the widget tree doesn't need extra stubs.
  @override
  Future<Map<String, dynamic>> getSchengen({String? asOf, String? tripId}) async => {};
  @override
  Future<List<Map<String, dynamic>>> getCoverage({String? tripId}) async => [];
  @override
  Future<Map<String, dynamic>> getBudget({String? tripId}) async => {};
}

// ── Helpers ───────────────────────────────────────────────────────────────────

void _tallSurface(WidgetTester t) {
  t.view.physicalSize = const Size(1200, 4000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

/// Returns overrides that yield a null briefing and stub the remaining home
/// providers so HomeScreen renders without hitting any real service.
List<Override> _nullBriefingOverrides(_FakeApi api) => [
      apiClientProvider.overrideWithValue(api),
      briefingProvider.overrideWith((ref) async => null),
      currentLegProvider.overrideWith((ref) async => null),
      nextBookingProvider.overrideWith((ref) async => null),
      openTaskCountProvider.overrideWith((ref) async => 0),
      schengenProvider.overrideWith((ref) async => null),
      coverageProvider.overrideWith((ref) async => null),
      budgetProvider.overrideWith((ref) async => null),
    ];

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('_GenerateBriefingCard', () {
    group('rendering', () {
      testWidgets(
          'shows "No briefing yet for today." when briefingProvider is null',
          (tester) async {
        _tallSurface(tester);
        final api = _FakeApi();
        await tester.pumpWidget(_app(_nullBriefingOverrides(api)));
        await tester.pumpAndSettle();

        expect(find.text('No briefing yet for today.'), findsOneWidget);
      });

      testWidgets('shows a Generate FilledButton', (tester) async {
        _tallSurface(tester);
        final api = _FakeApi();
        await tester.pumpWidget(_app(_nullBriefingOverrides(api)));
        await tester.pumpAndSettle();

        expect(find.text('Generate'), findsOneWidget);
      });
    });

    group('tapping Generate', () {
      testWidgets('calls apiClient.generateBriefing() once', (tester) async {
        _tallSurface(tester);
        final api = _FakeApi();
        await tester.pumpWidget(_app(_nullBriefingOverrides(api)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Generate'));
        await tester.pumpAndSettle();

        expect(api.generateCallCount, equals(1));
      });

      testWidgets('shows busy state (CircularProgressIndicator) while in-flight',
          (tester) async {
        _tallSurface(tester);
        final api = _FakeApi()..holdNext();
        await tester.pumpWidget(_app(_nullBriefingOverrides(api)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Generate'));
        // Pump just one frame — don't settle so the future stays pending.
        await tester.pump();

        // The busy indicator is a small SizedBox(width:16, height:16) wrapping
        // a CircularProgressIndicator with strokeWidth:2 — just check the type.
        expect(find.byType(CircularProgressIndicator), findsWidgets);

        // Release the future so cleanup is clean.
        api.releaseNext(
          const Briefing(id: 'b2', date: '2026-06-15', markdown: 'Done.'),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('button label changes to "Generating…" while busy',
          (tester) async {
        _tallSurface(tester);
        final api = _FakeApi()..holdNext();
        await tester.pumpWidget(_app(_nullBriefingOverrides(api)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Generate'));
        await tester.pump();

        expect(find.text('Generating…'), findsOneWidget);

        api.releaseNext(
          const Briefing(id: 'b3', date: '2026-06-15', markdown: 'Done.'),
        );
        await tester.pumpAndSettle();
      });
    });

    group('error handling', () {
      testWidgets('shows snackbar when generateBriefing throws', (tester) async {
        _tallSurface(tester);
        final api = _FakeApi()..shouldThrow = true;
        await tester.pumpWidget(_app(_nullBriefingOverrides(api)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Generate'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Could not generate'),
          findsOneWidget,
        );
      });

      testWidgets('Generate button is re-enabled after error', (tester) async {
        _tallSurface(tester);
        final api = _FakeApi()..shouldThrow = true;
        await tester.pumpWidget(_app(_nullBriefingOverrides(api)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Generate'));
        await tester.pumpAndSettle();

        // Button should be enabled again (not null-onPressed).
        final button = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Generate'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(button.onPressed, isNotNull);
      });
    });
  });
}
