import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/trips/email_scan_screen.dart';
import 'package:wayfarer/services/api_client.dart';
import 'package:wayfarer/services/sync_service.dart';
import 'package:wayfarer/services/local_db.dart';

// ── Fake helpers ──────────────────────────────────────────────────────────────

typedef _ScanResult = Map<String, dynamic>;

/// Fake ApiClient that controls scanBookingEmails and importBookings.
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');

  /// If non-null, scanBookingEmails will throw this.
  Object? scanError;

  /// If non-null, importBookings will throw this.
  Object? importError;

  /// The response returned by scanBookingEmails (set a Completer to delay).
  Future<_ScanResult> Function()? scanImpl;

  /// The response returned by importBookings.
  Future<Map<String, dynamic>> Function(List<Map<String, dynamic>>)? importImpl;

  List<Map<String, dynamic>>? lastImportPayload;

  @override
  Future<Map<String, dynamic>> scanBookingEmails({int months = 6}) async {
    if (scanError != null) throw scanError!;
    if (scanImpl != null) return scanImpl!();
    return {'candidates': []};
  }

  @override
  Future<Map<String, dynamic>> importBookings(
      List<Map<String, dynamic>> bookings) async {
    lastImportPayload = bookings;
    if (importError != null) throw importError!;
    if (importImpl != null) return importImpl!(bookings);
    return {'imported': bookings.length};
  }
}

/// No-op SyncService so we don't touch the real DB after import.
class _FakeSyncService extends SyncService {
  _FakeSyncService()
      : super(
          api: _FakeApi(),
          // LocalDb.newForTest() creates an isolated instance without opening
          // a file; snapshot() is overridden below so the db is never queried.
          db: LocalDb.newForTest(),
        );

  @override
  Future<bool> snapshot() async => true;
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

// Use getter functions so every test gets a fresh mutable copy — the screen
// mutates `already_exists` in-place during import, which would pollute a
// module-level `final` between test runs.

Map<String, dynamic> _candidateNew() => {
      'type': 'flight',
      'name': 'DEN → FCO',
      'start_date': '2026-06-01',
      'location_name': 'Rome',
      'confirmation': 'ABC123',
      'already_exists': false,
    };

Map<String, dynamic> _candidateExists() => {
      'type': 'hotel',
      'name': 'Hotel Quirinale',
      'start_date': '2026-06-02',
      'already_exists': true,
    };

Map<String, dynamic> _candidateTrain() => {
      'type': 'train',
      'name': 'Rome → Florence',
      'start_date': '2026-06-10',
      'already_exists': false,
    };

// ── Widget helper ─────────────────────────────────────────────────────────────

void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(_FakeApi api, {List<Override> extra = const []}) => ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        syncServiceProvider.overrideWithValue(_FakeSyncService()),
        ...extra,
      ],
      child: const MaterialApp(home: EmailScanScreen()),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('EmailScanScreen – initial / idle state', () {
    testWidgets('shows scan prompt and Scan Emails button initially',
        (tester) async {
      final api = _FakeApi();
      await tester.pumpWidget(_app(api));
      await tester.pump();

      expect(find.text('Scan Emails'), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.textContaining('Scan your Gmail'), findsOneWidget);
    });

    testWidgets('no import button in the AppBar until candidates are found',
        (tester) async {
      final api = _FakeApi();
      await tester.pumpWidget(_app(api));
      await tester.pump();

      expect(find.textContaining('Import'), findsNothing);
    });

    testWidgets('AppBar title is correct', (tester) async {
      final api = _FakeApi();
      await tester.pumpWidget(_app(api));
      await tester.pump();

      expect(find.text('Scan Email for Bookings'), findsOneWidget);
    });
  });

  group('EmailScanScreen – scanning state', () {
    testWidgets('shows scanning indicator while scan is in progress',
        (tester) async {
      final scanCompleter = Completer<_ScanResult>();
      final api = _FakeApi()..scanImpl = () => scanCompleter.future;

      await tester.pumpWidget(_app(api));
      await tester.pump();

      // Tap Scan Emails to start the scan.
      await tester.tap(find.text('Scan Emails'));
      await tester.pump(); // setState(_scanning = true) fires

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Scanning emails'), findsOneWidget);
      expect(find.textContaining('30-60 seconds'), findsOneWidget);
    });
  });

  group('EmailScanScreen – scan error state', () {
    testWidgets('shows error UI when scan throws', (tester) async {
      final api = _FakeApi()
        ..scanError = Exception('Network unreachable');

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Network unreachable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('tapping Retry clears error and re-runs scan', (tester) async {
      int callCount = 0;
      final api = _FakeApi()
        ..scanImpl = () async {
          callCount++;
          if (callCount == 1) throw Exception('first fail');
          return {'candidates': []};
        };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      // First scan → error.
      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);

      // Tap retry → second scan → empty results, back to idle.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.text('Scan Emails'), findsOneWidget); // empty state
      expect(callCount, 2);
    });
  });

  group('EmailScanScreen – empty candidates', () {
    testWidgets('shows no candidates message after scan returns empty',
        (tester) async {
      final api = _FakeApi()
        ..scanImpl = () async => {'candidates': []};

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      // Back to idle with Scan Emails button (no candidates).
      expect(find.text('Scan Emails'), findsOneWidget);
      expect(find.textContaining('Import'), findsNothing);
    });
  });

  group('EmailScanScreen – candidates list', () {
    testWidgets('renders candidate list with names and count label',
        (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()
        ..scanImpl = () async => {
              'candidates': [_candidateNew(), _candidateExists()],
            };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 bookings found'), findsOneWidget);
      expect(find.text('DEN → FCO'), findsOneWidget);
      expect(find.text('Hotel Quirinale'), findsOneWidget);
    });

    testWidgets('already-existing candidates are shown with strikethrough',
        (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()
        ..scanImpl = () async => {
              'candidates': [_candidateExists()],
            };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      // The (already imported) subtitle text should be present.
      expect(find.textContaining('already imported'), findsOneWidget);
    });

    testWidgets('new candidates are pre-selected; existing ones are not',
        (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()
        ..scanImpl = () async => {
              'candidates': [_candidateNew(), _candidateExists()],
            };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      // Import button should show "Import 1" (only _candidateNew() is selected).
      expect(find.textContaining('Import 1'), findsOneWidget);
    });

    testWidgets('Import button shows count of selected candidates',
        (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()
        ..scanImpl = () async => {
              'candidates': [_candidateNew(), _candidateTrain()],
            };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      // Both new candidates are pre-selected → Import 2.
      expect(find.textContaining('Import 2'), findsOneWidget);
    });

    testWidgets('deselecting a candidate updates the import count',
        (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()
        ..scanImpl = () async => {
              'candidates': [_candidateNew(), _candidateTrain()],
            };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      // Deselect the first checkbox.
      final checkboxes = find.byType(CheckboxListTile);
      await tester.tap(checkboxes.first);
      await tester.pump();

      expect(find.textContaining('Import 1'), findsOneWidget);
    });

    testWidgets('Deselect All / Select All button works', (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()
        ..scanImpl = () async => {
              'candidates': [_candidateNew(), _candidateTrain()],
            };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      // Both selected → 'Deselect All' shown.
      expect(find.text('Deselect All'), findsOneWidget);

      await tester.tap(find.text('Deselect All'));
      await tester.pump();

      // None selected → import button gone, 'Select All' shown.
      expect(find.text('Select All'), findsOneWidget);
      expect(find.textContaining('Import'), findsNothing);
    });

    testWidgets('booking type icons are rendered', (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()
        ..scanImpl = () async => {
              'candidates': [
                {..._candidateNew(), 'type': 'flight'},
                {..._candidateTrain(), 'type': 'train'},
              ],
            };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.flight), findsOneWidget);
      expect(find.byIcon(Icons.train), findsOneWidget);
    });

    testWidgets('hotel icon is used for hotel type', (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()
        ..scanImpl = () async => {
              'candidates': [
                {
                  'type': 'hotel',
                  'name': 'The Grand',
                  'already_exists': false,
                },
              ],
            };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.hotel), findsOneWidget);
    });
  });

  group('EmailScanScreen – import flow', () {
    testWidgets('tapping Import calls importBookings and shows success banner',
        (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()
        ..scanImpl = () async => {
              'candidates': [_candidateNew()],
            };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      // Tap the Import button in the AppBar.
      await tester.tap(find.textContaining('Import'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Imported 1 bookings successfully.'),
          findsOneWidget);
    });

    testWidgets('imported candidates are marked as already_exists',
        (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()
        ..scanImpl = () async => {
              'candidates': [Map<String, dynamic>.from(_candidateNew())],
            };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Import'));
      await tester.pumpAndSettle();

      // After import, the candidate is marked existing.
      expect(find.textContaining('already imported'), findsOneWidget);
      // Import button should be gone — nothing left to select.
      // (The success banner also contains the word "Imported" so we check
      // specifically for the "Import N" label on the action button.)
      expect(find.text('Import 1'), findsNothing);
    });

    testWidgets('importBookings receives the selected candidates payload',
        (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()
        ..scanImpl = () async => {
              'candidates': [
                Map<String, dynamic>.from(_candidateNew()),
                Map<String, dynamic>.from(_candidateExists()),
              ],
            };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Import'));
      await tester.pumpAndSettle();

      // Only _candidateNew() was selected (not already_exists).
      expect(api.lastImportPayload?.length, 1);
      expect(api.lastImportPayload?.first['name'], 'DEN → FCO');
    });

    testWidgets('import error shows error text', (tester) async {
      _tallSurface(tester);
      final api = _FakeApi()
        ..importError = Exception('import blew up')
        ..scanImpl = () async => {
              'candidates': [Map<String, dynamic>.from(_candidateNew())],
            };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Import'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Import failed'), findsOneWidget);
      expect(find.textContaining('import blew up'), findsOneWidget);
    });

    testWidgets('import shows spinner in button while in progress',
        (tester) async {
      _tallSurface(tester);
      final importCompleter = Completer<Map<String, dynamic>>();
      final api = _FakeApi();
      api.importImpl = (_) => importCompleter.future;
      api.scanImpl = () async => {
        'candidates': [Map<String, dynamic>.from(_candidateNew())],
      };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Import'));
      await tester.pump(); // setState(_importing = true) fires

      // A small CircularProgressIndicator should appear in the Import button.
      expect(
        find.byWidgetPredicate(
          (w) => w is CircularProgressIndicator && w.strokeWidth == 2,
        ),
        findsOneWidget,
      );
    });
  });

  group('EmailScanScreen – post-import banner', () {
    testWidgets('success banner shown in candidates view after import',
        (tester) async {
      _tallSurface(tester);
      final api = _FakeApi();
      api.importImpl = (_) async => {'imported': 1};
      api.scanImpl = () async => {
        'candidates': [Map<String, dynamic>.from(_candidateNew())],
      };

      await tester.pumpWidget(_app(api));
      await tester.pump();

      // Scan → candidates appear.
      await tester.tap(find.text('Scan Emails'));
      await tester.pumpAndSettle();

      // Import → success banner shown inside candidates view.
      await tester.tap(find.textContaining('Import'));
      await tester.pumpAndSettle();

      // The candidates view shows "Imported 1 bookings successfully." banner.
      expect(
        find.textContaining('Imported 1 bookings successfully.'),
        findsOneWidget,
      );
    });
  });
}

