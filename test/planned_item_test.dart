import 'package:carty_app/models/cart_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy items preserve picked quantities without inventing confirmations',
    () {
      final legacy = {
        'id': 'milk',
        'name': 'Milk',
        'unitPricePence': 150,
        'quantity': 2,
      };
      final item = CartItem.fromJson(legacy)!;
      expect(item.plannedQuantity, 2);
      expect(item.estimatedTotalPence, 300);
      expect(item.totalPence, 300);
      expect(item.priceConfirmed, isFalse);
      expect(CartItem.fromJson({...legacy, 'quantity': 0})!.plannedQuantity, 1);
    },
  );

  test('picking and confirming a price preserves the original plan', () {
    const planned = CartItem(
      id: 'milk',
      name: 'Milk',
      unitPricePence: 150,
      quantity: 0,
      plannedQuantity: 3,
      estimatedUnitPricePence: 150,
    );
    final picked = planned.copyWith(
      quantity: 2,
      unitPricePence: 175,
      priceConfirmed: true,
    );
    expect(picked.totalPence, 350);
    expect(picked.estimatedTotalPence, 450);
    expect(picked.needsPicking, isTrue);
    expect(picked.copyWith(quantity: 3).isFullyPicked, isTrue);
    final restored = CartItem.fromJson(picked.toJson())!;
    expect(restored.toJson(), picked.toJson());
    expect(planned.quantity, 0);
  });

  test(
    'malformed plan fields are rejected instead of losing a stored plan',
    () {
      const item = CartItem(
        id: 'milk',
        name: 'Milk',
        unitPricePence: 150,
        quantity: 1,
      );
      for (final bad in [
        {'plannedQuantity': -1},
        {'plannedQuantity': null},
        {'plannedQuantity': 10000},
        {'estimatedUnitPricePence': 0},
        {'estimatedUnitPricePence': 1.5},
        {'priceConfirmed': 'yes'},
      ]) {
        expect(CartItem.fromJson({...item.toJson(), ...bad}), isNull);
      }
    },
  );
}
