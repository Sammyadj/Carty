import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:carty_app/widgets/cart_area/cart_item_tile.dart';
import 'package:carty_app/widgets/summary_area/summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<CartStore> _openApp(WidgetTester tester, {CartStore? store}) async {
  final cart = store ?? CartStore(storage: InMemoryCartStorage());
  await cart.load();
  addTearDown(cart.dispose);
  await tester.pumpWidget(MyApp(store: cart));
  await tester.pumpAndSettle();
  return cart;
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final control = find.byKey(ValueKey(key));
  if (control.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      control,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

Finder _summaryAmount(String amount) =>
    find.descendant(of: find.byType(SummaryCard), matching: find.text(amount));

Future<void> _showSummary(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byType(SummaryCard),
    -300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.byType(SummaryCard));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('item form rejects invalid data and adds a valid item', (
    tester,
  ) async {
    final store = await _openApp(tester);

    await _tapKey(tester, 'add-item');
    await _tapKey(tester, 'item-save');
    expect(store.items, isEmpty);
    expect(find.byKey(const ValueKey('item-name-input')), findsOneWidget);

    await _enter(tester, 'item-name-input', '  Milk  ');
    await _enter(tester, 'item-price-input', '-2');
    await _tapKey(tester, 'item-save');
    expect(store.items, isEmpty);

    await _enter(tester, 'item-price-input', '2.50');
    await _enter(tester, 'item-quantity-input', '2');
    await _tapKey(tester, 'item-save');

    expect(store.items.single.name, 'Milk');
    expect(store.items.single.quantity, 2);
    expect(store.totalPence, 500);
    expect(_summaryAmount('£5.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('budget form validates and warns when cart exceeds budget', (
    tester,
  ) async {
    final store = await _openApp(tester);
    await _tapKey(tester, 'budget-edit');
    await _enter(tester, 'budget-input', '0');
    await _tapKey(tester, 'budget-save');
    expect(store.budgetPence, isNull);

    await _enter(tester, 'budget-input', '4.00');
    await _tapKey(tester, 'budget-save');
    expect(store.budgetPence, 400);

    await store.addItem(name: 'Bread', unitPricePence: 250, quantity: 2);
    await tester.pumpAndSettle();
    expect(find.text('Over budget'), findsOneWidget);
    expect(_summaryAmount('£5.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing in full cart updates its summary and home on return', (
    tester,
  ) async {
    final store = CartStore(storage: InMemoryCartStorage());
    await store.load();
    await store.setBudget(2000);
    await store.addItem(name: 'Bread', unitPricePence: 250);
    await _openApp(tester, store: store);
    final id = store.items.single.id;

    await _tapKey(tester, 'cart-open');
    await _tapKey(tester, 'item-edit-$id');
    await _enter(tester, 'item-name-input', 'Wholemeal bread');
    await _enter(tester, 'item-price-input', '3.75');
    await _enter(tester, 'item-quantity-input', '2');
    await _tapKey(tester, 'item-save');

    expect(store.totalPence, 750);
    expect(find.text('Wholemeal bread'), findsOneWidget);
    await _showSummary(tester);
    expect(_summaryAmount('£7.50'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _showSummary(tester);
    expect(_summaryAmount('£7.50'), findsOneWidget);
    expect(_summaryAmount('£12.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quantity can become pending zero without becoming negative', (
    tester,
  ) async {
    final store = CartStore(storage: InMemoryCartStorage());
    await store.load();
    await store.addItem(name: 'Eggs', unitPricePence: 300);
    await _openApp(tester, store: store);
    final id = store.items.single.id;

    await _tapKey(tester, 'item-decrement-$id');
    expect(store.items.single.quantity, 0);
    expect(store.totalPence, 0);
    expect(find.text('Not picked yet'), findsOneWidget);

    final decrement = find.byKey(ValueKey('item-decrement-$id'));
    expect(tester.widget<IconButton>(decrement).onPressed, isNull);

    await _tapKey(tester, 'item-increment-$id');
    expect(store.items.single.quantity, 1);
    await _showSummary(tester);
    expect(_summaryAmount('£3.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing requires confirmation and retains the budget', (
    tester,
  ) async {
    final store = CartStore(storage: InMemoryCartStorage());
    await store.load();
    await store.setBudget(1000);
    await store.addItem(name: 'Milk', unitPricePence: 120);
    await _openApp(tester, store: store);

    await _tapKey(tester, 'clear-cart');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(store.items, hasLength(1));

    await _tapKey(tester, 'clear-cart');
    await _tapKey(tester, 'clear-confirm');
    expect(store.items, isEmpty);
    expect(store.budgetPence, 1000);
    await _showSummary(tester);
    expect(_summaryAmount('£0.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved list fresh mode resets cart and preserves original list', (
    tester,
  ) async {
    final store = CartStore(storage: InMemoryCartStorage());
    await store.load();
    await store.setBudget(2500);
    await store.addItem(name: 'Pasta', unitPricePence: 175, quantity: 3);
    await _openApp(tester, store: store);

    await _tapKey(tester, 'save-list');
    await _enter(tester, 'list-name-input', 'Weekly shop');
    await _tapKey(tester, 'list-save');
    expect(store.savedLists, hasLength(1));
    final saved = store.savedLists.single;

    await _tapKey(tester, 'saved-list-load-${saved.id}');
    await _tapKey(tester, 'reuse-fresh');
    await _tapKey(tester, 'reuse-continue');
    expect(store.items.single.quantity, 3);
    await _tapKey(tester, 'reuse-apply');

    expect(store.items.single.name, 'Pasta');
    expect(store.items.single.quantity, 0);
    expect(store.budgetPence, isNull);
    expect(store.totalPence, 0);
    expect(store.savedLists.single.items.single.quantity, 3);
    expect(store.savedLists.single.budgetPence, 2500);
    expect(tester.takeException(), isNull);
  });

  testWidgets('emoji names are validated before closing the list dialog', (
    tester,
  ) async {
    final store = CartStore(storage: InMemoryCartStorage());
    await store.addItem(name: 'Milk', unitPricePence: 120);
    await _openApp(tester, store: store);
    await _tapKey(tester, 'save-list');
    await _enter(tester, 'list-name-input', List.filled(40, '🛒').join());
    await _tapKey(tester, 'list-save');
    expect(store.savedLists, isEmpty);
    expect(find.text('Please use a shorter list name'), findsOneWidget);
    expect(find.byKey(const ValueKey('list-name-input')), findsOneWidget);
    await _enter(tester, 'list-name-input', 'Weekly groceries');
    await _tapKey(tester, 'list-save');
    expect(store.savedLists.single.name, 'Weekly groceries');
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists and tips navigation opens real views and returns home', (
    tester,
  ) async {
    final store = CartStore(storage: InMemoryCartStorage());
    await store.addItem(name: 'Milk', unitPricePence: 120);
    await store.saveList('Weekly groceries');
    await _openApp(tester, store: store);

    await _tapKey(tester, 'nav-lists');
    expect(find.text('Weekly groceries'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('save-list-from-library')),
      findsOneWidget,
    );
    await _tapKey(tester, 'nav-tips');
    expect(find.text('A smarter way to shop.'), findsOneWidget);
    expect(find.text('Compare the price, not just the pack'), findsOneWidget);
    await _tapKey(tester, 'nav-home');
    expect(find.byType(SummaryCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('near-budget dashboard provides a visible warning', (
    tester,
  ) async {
    final store = CartStore(storage: InMemoryCartStorage());
    await store.setBudget(1000);
    await store.addItem(name: 'Weekly essentials', unitPricePence: 850);
    await _openApp(tester, store: store);
    expect(find.text('You’re close to your budget.'), findsOneWidget);
    expect(_summaryAmount('£1.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'basket search and pending filter leave stored products unchanged',
    (tester) async {
      final store = CartStore(storage: InMemoryCartStorage());
      await store.addItem(name: 'Milk', unitPricePence: 120);
      await store.addItem(name: 'Bread', unitPricePence: 150, quantity: 0);
      await _openApp(tester, store: store);
      await _tapKey(tester, 'cart-open');
      await _enter(tester, 'cart-search', 'Bread');
      await tester.pumpAndSettle();
      final breadId = store.items.last.id;
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('item-edit-$breadId')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.descendant(
          of: find.byType(CartItemTile),
          matching: find.text('Bread'),
        ),
        findsOneWidget,
      );
      expect(find.text('Milk'), findsNothing);
      await _enter(tester, 'cart-search', '');
      await tester.pumpAndSettle();
      await _tapKey(tester, 'cart-filter-pending');
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('item-edit-$breadId')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.descendant(
          of: find.byType(CartItemTile),
          matching: find.text('Bread'),
        ),
        findsOneWidget,
      );
      expect(find.text('Milk'), findsNothing);
      expect(store.items, hasLength(2));
      expect(store.totalPence, 120);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dashboard and editor fit a narrow phone with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final store = CartStore(storage: InMemoryCartStorage());
    await store.load();
    await store.setBudget(10000);
    await store.addItem(
      name: 'Long product name that wraps on a small phone screen',
      unitPricePence: 250,
      quantity: 2,
    );
    await _openApp(tester, store: store);
    expect(tester.takeException(), isNull);

    await _tapKey(tester, 'add-item');
    await _enter(tester, 'item-name-input', 'Apples');
    await _enter(tester, 'item-price-input', '1.50');
    await _tapKey(tester, 'item-save');
    expect(store.items, hasLength(2));
    expect(tester.takeException(), isNull);
  });
}
