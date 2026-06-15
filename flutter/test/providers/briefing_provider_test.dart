import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wayfarer/models/briefing.dart';
import 'package:wayfarer/providers/briefing_provider.dart';
import 'package:wayfarer/services/api_client.dart';
import 'package:wayfarer/services/local_db.dart';

// ── Fake ApiClient ──────────────────────────────────────────────────────────

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.local');

  Briefing? todayBriefing;
  Object? throwOnGet;

  @override
  Future<Briefing?> getTodayBriefing() async {
    if (throwOnGet != null) throw throwOnGet!;
    return todayBriefing;
  }

  Future<void> upsertBriefing(Briefing b) async {
    // no-op — LocalDb handles persistence in tests
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

Future<LocalDb> _initDb() async {
  final db = LocalDb.newForTest();
  await db.init(pathOverride: inMemoryDatabasePath);
  return db;
}

ProviderContainer _container({
  required _FakeApi api,
  required LocalDb db,
}) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      localDbProvider.overrideWithValue(db),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

// ── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('briefingProvider — backend returns a briefing', () {
    test('uses the fresh briefing from the backend', () async {
      const fresh = Briefing(
        id: 'b1',
        date: '2026-06-14',
        markdown: '## Today\nAll good.',
        createdAt: '2026-06-14T00:00:00',
      );
      final api = _FakeApi()..todayBriefing = fresh;
      final db = await _initDb();
      addTearDown(db.close);
      final c = _container(api: api, db: db);

      final result = await c.read(briefingProvider.future);

      expect(result, isNotNull);
      expect(result!.id, 'b1');
      expect(result.markdown, contains('Today'));
    });

    test('caches the fresh briefing in LocalDb for offline use', () async {
      const fresh = Briefing(
        id: 'b-cache',
        date: '2026-06-14',
        markdown: '## Cached',
        createdAt: '2026-06-14T00:00:00',
      );
      final api = _FakeApi()..todayBriefing = fresh;
      final db = await _initDb();
      addTearDown(db.close);
      final c = _container(api: api, db: db);

      await c.read(briefingProvider.future);

      // The local cache should now hold the briefing.
      final cached = await db.latestBriefing();
      expect(cached, isNotNull);
      expect(cached!.id, 'b-cache');
    });
  });

  group('briefingProvider — backend returns null (no briefing today)', () {
    test('falls back to the cached briefing in LocalDb', () async {
      const cached = Briefing(
        id: 'b-old',
        date: '2026-06-13',
        markdown: '## Yesterday',
        createdAt: '2026-06-13T00:00:00',
      );
      // Backend returns null (404 handled inside getTodayBriefing → null).
      final api = _FakeApi()..todayBriefing = null;
      final db = await _initDb();
      addTearDown(db.close);
      await db.upsertBriefing(cached);
      final c = _container(api: api, db: db);

      final result = await c.read(briefingProvider.future);

      expect(result, isNotNull);
      expect(result!.id, 'b-old');
    });

    test('returns null when backend returns null and cache is empty', () async {
      final api = _FakeApi()..todayBriefing = null;
      final db = await _initDb();
      addTearDown(db.close);
      final c = _container(api: api, db: db);

      final result = await c.read(briefingProvider.future);

      expect(result, isNull);
    });
  });

  group('briefingProvider — backend throws (offline / network error)', () {
    test('falls back to the cached briefing when network throws', () async {
      const cached = Briefing(
        id: 'b-fallback',
        date: '2026-06-12',
        markdown: '## Fallback',
        createdAt: '2026-06-12T00:00:00',
      );
      final api = _FakeApi()
        ..throwOnGet = ApiUnreachable('no network');
      final db = await _initDb();
      addTearDown(db.close);
      await db.upsertBriefing(cached);
      final c = _container(api: api, db: db);

      final result = await c.read(briefingProvider.future);

      expect(result, isNotNull);
      expect(result!.id, 'b-fallback');
    });

    test('returns null when backend throws and local cache is empty', () async {
      final api = _FakeApi()..throwOnGet = Exception('connection refused');
      final db = await _initDb();
      addTearDown(db.close);
      final c = _container(api: api, db: db);

      final result = await c.read(briefingProvider.future);

      expect(result, isNull);
    });
  });
}
