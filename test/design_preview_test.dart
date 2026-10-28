import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final hasBudget in [false, true]) {
    testWidgets(
      'City fits large text on a narrow phone with budget: $hasBudget',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = CartStore(storage: InMemoryCartStorage());
        addTearDown(store.dispose);
        if (hasBudget) {
          await store.addItem(name: 'Whole milk', unitPricePence: 120);
          await store.setBudget(100);
        }
        await tester.pumpWidget(MyApp(store: store));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('budget-edit')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('budget-edit')), findsOneWidget);
        expect(find.byKey(const Key('design-picker')), findsNothing);
        expect(
          CartyDesign.of(tester.element(find.byType(NavigationBar))),
          same(CartyDesign.city),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('City keeps shopping state when navigating lists and home', (
    tester,
  ) async {
    final store = CartStore(storage: InMemoryCartStorage());
    addTearDown(store.dispose);
    await store.addItem(name: 'Whole milk', unitPricePence: 120, quantity: 2);
    await store.setBudget(3000);
    await store.saveList('Weekly shop');
    await tester.pumpWidget(MyApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-lists')));
    await tester.pumpAndSettle();
    expect(find.text('Weekly shop'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    expect(store.totalPence, 240);
    expect(store.budgetPence, 3000);
    expect(store.activeList!.name, 'Weekly shop');
    expect(tester.takeException(), isNull);
  });
}
