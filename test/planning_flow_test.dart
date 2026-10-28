import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'plan at home, pick in the shop, and preserve the original estimate',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.startNewList();
      await store.setBudget(1000);
      await tester.pumpWidget(MyApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-item')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('item-name-input')), 'Milk');
      await tester.enterText(find.byKey(const Key('item-price-input')), '1.50');
      await tester.enterText(find.byKey(const Key('item-quantity-input')), '2');
      await tapVisible(tester, find.byKey(const Key('item-save')));
      expect(store.items.single.quantity, 0);
      expect(store.items.single.plannedQuantity, 2);
      expect(store.estimatedTotalPence, 300);
      expect(store.totalPence, 0);
      await tapVisible(tester, find.text('Shop'));
      final id = store.items.single.id;
      await tester.scrollUntilVisible(
        find.byKey(Key('item-edit-$id')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapVisible(tester, find.byKey(Key('item-edit-$id')));
      await tester.enterText(find.byKey(const Key('item-price-input')), '1.75');
      await tester.enterText(find.byKey(const Key('item-quantity-input')), '1');
      await tapVisible(tester, find.byKey(const Key('item-price-confirmed')));
      await tapVisible(tester, find.byKey(const Key('item-save')));
      expect(store.items.single.priceConfirmed, isTrue);
      expect(store.totalPence, 175);
      expect(store.estimatedTotalPence, 300);
      expect(store.pendingCount, 1);
      await tapVisible(tester, find.byKey(Key('item-picked-$id')));
      expect(store.items.single.quantity, 2);
      expect(store.totalPence, 350);
      expect(store.remainingPence, 650);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'planning controls and estimate form support a narrow phone with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.startNewList();
      await tester.pumpWidget(MyApp(store: store));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('add-item')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('item-name-input')), 'Bread');
      await tester.enterText(find.byKey(const Key('item-price-input')), '2.10');
      await tapVisible(tester, find.byKey(const Key('item-save')));
      expect(store.items.single.quantity, 0);
      expect(store.estimatedTotalPence, 210);
      expect(tester.takeException(), isNull);
    },
  );
}
