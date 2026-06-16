import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/features/trips/widgets/packing_tile.dart';
import 'package:wayfarer/models/packing_item.dart';
import 'package:wayfarer/providers/trip_provider.dart';

// ---------------------------------------------------------------------------
// Fake TripMutations
// ---------------------------------------------------------------------------
class _FakeMutations extends TripMutations {
  _FakeMutations() : super(_NullRef());

  String? toggledItemId;
  String? deletedItemId;
  bool returnValue = true;

  @override
  Future<bool> togglePacked(String id) async {
    toggledItemId = id;
    return returnValue;
  }

  @override
  Future<bool> deletePacking(String id) async {
    deletedItemId = id;
    return returnValue;
  }
}

class _NullRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

// ---------------------------------------------------------------------------
// Sample models
// ---------------------------------------------------------------------------
const _unpackedItem = PackingItem(
  id: 'pi-1',
  tripId: 'trip-1',
  category: 'clothing',
  name: 'Rain jacket',
  isPacked: false,
);

const _packedItem = PackingItem(
  id: 'pi-2',
  tripId: 'trip-1',
  category: 'documents',
  name: 'Passport',
  isPacked: true,
);

const _electronicsItem = PackingItem(
  id: 'pi-3',
  tripId: 'trip-1',
  category: 'electronics',
  name: 'Laptop',
  isPacked: false,
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
Widget _wrap(PackingItem item, {_FakeMutations? mutations}) {
  return ProviderScope(
    overrides: [
      if (mutations != null)
        tripMutationsProvider.overrideWithValue(mutations),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: PackingTile(item: item),
      ),
    ),
  );
}

void main() {
  group('PackingTile', () {
    // ── Rendering ─────────────────────────────────────────────────────────

    testWidgets('renders item name', (tester) async {
      await tester.pumpWidget(_wrap(_unpackedItem));
      expect(find.text('Rain jacket'), findsOneWidget);
    });

    testWidgets('renders category in subtitle', (tester) async {
      await tester.pumpWidget(_wrap(_unpackedItem));
      expect(find.text('clothing'), findsOneWidget);
    });

    testWidgets('renders different item with its own name and category',
        (tester) async {
      await tester.pumpWidget(_wrap(_electronicsItem));
      expect(find.text('Laptop'), findsOneWidget);
      expect(find.text('electronics'), findsOneWidget);
    });

    // ── Checkbox state ─────────────────────────────────────────────────────

    testWidgets('unpacked item has unchecked checkbox', (tester) async {
      await tester.pumpWidget(_wrap(_unpackedItem));
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('packed item has checked checkbox', (tester) async {
      await tester.pumpWidget(_wrap(_packedItem));
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    // ── Strikethrough on packed item ──────────────────────────────────────

    testWidgets('packed item title has strikethrough decoration', (tester) async {
      await tester.pumpWidget(_wrap(_packedItem));
      final text = tester.widget<Text>(find.text('Passport'));
      expect(text.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('unpacked item title has no strikethrough', (tester) async {
      await tester.pumpWidget(_wrap(_unpackedItem));
      final text = tester.widget<Text>(find.text('Rain jacket'));
      expect(text.style?.decoration, isNot(TextDecoration.lineThrough));
    });

    // ── Checkbox tap calls togglePacked ──────────────────────────────────

    testWidgets('tapping checkbox calls togglePacked with item id',
        (tester) async {
      final mutations = _FakeMutations();
      await tester.pumpWidget(_wrap(_unpackedItem, mutations: mutations));

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(mutations.toggledItemId, 'pi-1');
    });

    testWidgets('tapping checkbox on packed item also calls togglePacked',
        (tester) async {
      final mutations = _FakeMutations();
      await tester.pumpWidget(_wrap(_packedItem, mutations: mutations));

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(mutations.toggledItemId, 'pi-2');
    });

    // ── Toggle failure shows offline snackbar ─────────────────────────────

    testWidgets('togglePacked failure shows offline snackbar', (tester) async {
      final mutations = _FakeMutations()..returnValue = false;
      await tester.pumpWidget(_wrap(_unpackedItem, mutations: mutations));

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(find.text('Offline - writes disabled'), findsOneWidget);
    });

    testWidgets('successful toggle shows no snackbar', (tester) async {
      final mutations = _FakeMutations(); // returnValue = true by default
      await tester.pumpWidget(_wrap(_unpackedItem, mutations: mutations));

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(find.text('Offline - writes disabled'), findsNothing);
    });

    // ── Delete icon button ────────────────────────────────────────────────

    testWidgets('delete IconButton with Icons.delete_outline is present',
        (tester) async {
      await tester.pumpWidget(_wrap(_unpackedItem));
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('tapping delete icon calls deletePacking with item id',
        (tester) async {
      final mutations = _FakeMutations();
      await tester.pumpWidget(_wrap(_unpackedItem, mutations: mutations));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(mutations.deletedItemId, 'pi-1');
    });

    testWidgets('tapping delete on a different item passes the correct id',
        (tester) async {
      final mutations = _FakeMutations();
      await tester.pumpWidget(_wrap(_packedItem, mutations: mutations));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(mutations.deletedItemId, 'pi-2');
    });

    testWidgets('deletePacking failure (returns false) shows offline snackbar',
        (tester) async {
      final mutations = _FakeMutations()..returnValue = false;
      await tester.pumpWidget(_wrap(_unpackedItem, mutations: mutations));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Offline - writes disabled'), findsOneWidget);
    });

    testWidgets('successful delete shows no snackbar', (tester) async {
      final mutations = _FakeMutations(); // returnValue = true by default
      await tester.pumpWidget(_wrap(_unpackedItem, mutations: mutations));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Offline - writes disabled'), findsNothing);
    });

    // ── Wrapped in a Card ─────────────────────────────────────────────────

    testWidgets('tile is rendered inside a Card', (tester) async {
      await tester.pumpWidget(_wrap(_unpackedItem));
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('tile uses a ListTile', (tester) async {
      await tester.pumpWidget(_wrap(_unpackedItem));
      expect(find.byType(ListTile), findsOneWidget);
    });
  });
}
