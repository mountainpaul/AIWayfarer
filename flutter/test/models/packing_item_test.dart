import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer/models/packing_item.dart';

void main() {
  group('PackingItem', () {
    group('fromJson', () {
      test('maps all snake_case fields correctly', () {
        final p = PackingItem.fromJson({
          'id': 'pi-1',
          'trip_id': 'trip-1',
          'category': 'clothing',
          'name': 'Rain jacket',
          'is_packed': true,
          'sort_order': 3,
          'created_at': '2026-06-01T00:00:00Z',
          'updated_at': '2026-06-14T00:00:00Z',
        });

        expect(p.id, 'pi-1');
        expect(p.tripId, 'trip-1');
        expect(p.category, 'clothing');
        expect(p.name, 'Rain jacket');
        expect(p.isPacked, isTrue);
        expect(p.sortOrder, 3);
        expect(p.createdAt, '2026-06-01T00:00:00Z');
        expect(p.updatedAt, '2026-06-14T00:00:00Z');
      });

      test('defaults apply when optional fields are omitted', () {
        final p = PackingItem.fromJson({
          'id': 'pi-2',
          'trip_id': 'trip-1',
          'category': 'documents',
          'name': 'Passport',
        });

        expect(p.isPacked, isFalse);
        expect(p.sortOrder, 0);
        expect(p.createdAt, isNull);
        expect(p.updatedAt, isNull);
      });

      test('isPacked false when JSON value is false', () {
        final p = PackingItem.fromJson({
          'id': 'pi-3',
          'trip_id': 'trip-1',
          'category': 'electronics',
          'name': 'Laptop',
          'is_packed': false,
        });

        expect(p.isPacked, isFalse);
      });
    });

    group('toJson round-trip', () {
      test('serialises and deserialises without data loss', () {
        const p = PackingItem(
          id: 'pi-rt',
          tripId: 'trip-rt',
          category: 'toiletries',
          name: 'Toothbrush',
          isPacked: true,
          sortOrder: 5,
        );

        final json = p.toJson();
        final p2 = PackingItem.fromJson(json);

        expect(p2, equals(p));
      });
    });
  });
}
