import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/design/design_theme.dart';
import 'package:carty_app/models/grocery_category.dart';
import 'package:carty_app/screens/cart_full_screen.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:carty_app/widgets/cart_area/cart_item_tile.dart';
import 'package:carty_app/widgets/recommendation_shelves.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

CartStore workspace() {
  final store = CartStore(storage: InMemoryCartStorage());
  addTearDown(store.dispose);
  return store;
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'category filtering combines with search and To pick without editing data',
    (tester) async {
      phone(tester);
      final store = workspace();
      await store.addItem(name: 'Milk', unitPricePence: 150, quantity: 0);
      await store.addItem(name: 'Cheese', unitPricePence: 250, quantity: 1);
      await store.addItem(name: 'Bread', unitPricePence: 210, quantity: 0);
      final original = store.exportSnapshot();
      final milkId = store.items.first.id;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDesignTheme(CartyDesign.city),
          home: CartFullScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, const ValueKey('basket-categories-dairyAndEggs'));
      await tap(tester, const Key('cart-filter-pending'));
      await tester.ensureVisible(find.byKey(const Key('cart-search')));
      await tester.enterText(find.byKey(const Key('cart-search')), 'mi');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(milkId)),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final tiles = tester
          .widgetList<CartItemTile>(find.byType(CartItemTile))
          .toList();
      expect(tiles.map((tile) => tile.item.name), ['Milk']);
      expect(
        find.byKey(const ValueKey('basket-heading-dairyAndEggs')),
        findsOneWidget,
      );
      expect(store.exportSnapshot(), original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a chosen category survives a name change and saving the form', (
    tester,
  ) async {
    phone(tester);
    final store = workspace();
    await store.startNewList();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDesignTheme(CartyDesign.city),
        home: CartFullScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, const Key('add-item'));
    await tester.enterText(find.byKey(const Key('item-name-input')), 'Milk');
    await tester.enterText(find.byKey(const Key('item-price-input')), '1.50');
    await tap(tester, const Key('item-category-input'));
    final household = find.text('Household').last;
    await tester.ensureVisible(household);
    await tester.tap(household);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('item-name-input')));
    await tester.enterText(find.byKey(const Key('item-name-input')), 'Apples');
    await tap(tester, const Key('item-save'));
    expect(store.items.single.category, GroceryCategory.household);
    expect(store.items.single.resolvedCategory, GroceryCategory.household);
    expect(store.items.single.quantity, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recommendation category chips retain horizontal browsing and allow clearing',
    (tester) async {
      phone(tester);
      final store = workspace();
      await store.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDesignTheme(CartyDesign.city),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ShoppingRecommendationsSection(store: store),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(
        tester,
        const ValueKey('recommendation-categories-dairyAndEggs'),
      );
      expect(
        find.byKey(const ValueKey('recommendation-card-milk')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('recommendation-card-eggs')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('recommendation-card-bread')),
        findsNothing,
      );
      await tap(tester, const ValueKey('recommendation-categories-all'));
      expect(
        find.byKey(const ValueKey('recommendation-card-bread')),
        findsOneWidget,
      );
      expect(store.items, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
