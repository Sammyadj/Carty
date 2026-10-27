import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final variant in DesignVariant.values) {
    testWidgets('${variant.name} supports narrow phones and large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addItem(name: 'Whole milk', unitPricePence: 120);
      await store.setBudget(100);
      await tester.pumpWidget(MyApp(store: store, initialDesign: variant));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('design-picker')));
      await tester.pumpAndSettle();
      expect(find.text('Find your Carty.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('switching designs preserves shopping state and navigation', (
    tester,
  ) async {
    final store = CartStore(storage: InMemoryCartStorage());
    addTearDown(store.dispose);
    await store.addItem(name: 'Whole milk', unitPricePence: 120, quantity: 2);
    await store.setBudget(3000);
    await store.saveList('Weekly shop');
    await tester.pumpWidget(MyApp(store: store));
    await tester.pumpAndSettle();
    for (final variant in DesignVariant.values) {
      await tester.tap(find.byKey(const Key('design-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('design-${variant.name}')));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(NavigationBar));
      expect(CartyDesign.of(context).variant, variant);
      expect(store.totalPence, 240);
      expect(store.budgetPence, 3000);
      expect(store.savedLists.single.name, 'Weekly shop');
      await tester.tap(find.byKey(const Key('nav-lists')));
      await tester.pumpAndSettle();
      expect(find.text('Weekly shop'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nav-home')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
