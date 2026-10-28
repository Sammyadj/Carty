import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/design/carty_design.dart';
import 'package:carty_app/design/design_theme.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/screens/product_library_screen.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:carty_app/widgets/recommendation_shelves.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
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

void phone(WidgetTester tester, {bool large = false}) {
  tester.view.physicalSize = large
      ? const Size(320, 780)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  testWidgets(
    'favourite from Basket and review it later without duplicating an existing item',
    (tester) async {
      phone(tester);
      final store = workspace();
      await store.addItem(name: 'Milk', unitPricePence: 150);
      final id = store.items.single.id;
      await tester.pumpWidget(MyApp(store: store));
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(ValueKey('item-favourite-$id')));
      expect(store.preferenceFor('Milk')!.favourite, isTrue);
      await tap(tester, find.byKey(const Key('products-open')));
      await tap(tester, find.byKey(const ValueKey('library-product-milk')));
      expect(find.text('Edit item'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(store.items, hasLength(1));
      await store.startNewList();
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('library-product-milk')));
      expect(find.text('Add an item'), findsOneWidget);
      await tap(tester, find.byKey(const Key('item-save')));
      expect(store.items.single.name, 'Milk');
      expect(store.items.single.unitPricePence, 150);
      expect(store.items.single.quantity, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hide a recommendation, undo it, and restore it from management',
    (tester) async {
      phone(tester);
      final store = workspace();
      await store.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDesignTheme(CartyDesign.city),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedBuilder(
                animation: store,
                builder: (_, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: ShoppingRecommendationsSection(store: store),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('product-actions-milk')));
      await tester.tap(find.text('Hide this suggestion'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('recommendation-card-milk')),
        findsNothing,
      );
      expect(store.preferenceFor('Milk')!.hidden, isTrue);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('recommendation-card-milk')),
        findsOneWidget,
      );
      await tap(tester, find.byKey(const ValueKey('product-actions-milk')));
      await tester.tap(find.text('Hide this suggestion'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Manage'));
      await tap(tester, find.text('Hidden & less often'));
      await tap(tester, find.byKey(const ValueKey('product-actions-milk')));
      await tester.tap(find.text('Show suggestions again'));
      await tester.pumpAndSettle();
      expect(store.preferenceFor('Milk'), isNull);
      expect(store.items, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'regulars count completed shops rather than quantities or pending products',
    (tester) async {
      phone(tester);
      final store = workspace();
      for (var i = 0; i < 2; i++) {
        await store.addItem(name: 'Milk', unitPricePence: 150, quantity: 5);
        await store.addItem(name: 'Bread', unitPricePence: 200, quantity: 0);
        await store.completeShopping('Trip $i');
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDesignTheme(CartyDesign.city),
          home: ProductLibraryScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Regulars'));
      expect(
        find.byKey(const ValueKey('library-product-milk')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('library-product-bread')), findsNothing);
      expect(
        find.textContaining('Picked in 2 of 2 recent shops'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'product management and menus fit narrow screens with larger text',
    (tester) async {
      phone(tester, large: true);
      final store = workspace();
      await store.setProductPreference(
        name: 'Long product name for a household favourite',
        unitPricePence: 250,
        favourite: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDesignTheme(CartyDesign.city),
          home: ProductLibraryScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tap(
        tester,
        find.byKey(
          const ValueKey(
            'product-actions-long product name for a household favourite',
          ),
        ),
      );
      await tester.tap(find.text('Suggest less often'));
      await tester.pumpAndSettle();
      expect(store.productPreferences.single.lessOften, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
