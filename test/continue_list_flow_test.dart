import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/screens/cart_full_screen.dart';
import 'package:carty_app/screens/reuse_list_screen.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingStorage extends InMemoryCartStorage {
  bool fail = false;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('Disk unavailable');
    await super.write(value);
  }
}

Future<CartStore> _fixture({
  CartStorage? storage,
  bool unsavedBasket = false,
}) async {
  final store = CartStore(storage: storage ?? InMemoryCartStorage());
  addTearDown(store.dispose);
  await store.setBudget(5000);
  await store.addItem(name: 'Milk', unitPricePence: 120, quantity: 0);
  await store.addItem(name: 'Bread', unitPricePence: 180);
  await store.saveList('Monthly shop');
  await store.startNewList();
  if (unsavedBasket) {
    await store.addItem(name: 'Soap', unitPricePence: 200);
    await store.setBudget(8000);
  }
  return store;
}

Future<void> _reveal(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      {'budget-edit', 'active-list-banner'}.contains(key) ? -250 : 250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await _reveal(tester, key);
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  await _reveal(tester, key);
  await tester.enterText(find.byKey(ValueKey(key)), value);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, CartStore store) async {
  await tester.pumpWidget(MyApp(store: store));
  await tester.pumpAndSettle();
}

Future<void> _review(WidgetTester tester, String listId) async {
  await _tap(tester, 'nav-lists');
  await _tap(tester, 'saved-list-load-$listId');
  expect(find.text('Open shopping list'), findsOneWidget);
  await _tap(tester, 'reuse-continue');
}

void main() {
  testWidgets(
    'continue edits the same list and restores it as the active shop',
    (tester) async {
      final storage = InMemoryCartStorage();
      final store = await _fixture(storage: storage);
      final saved = store.savedLists.single;
      final milkId = saved.items.first.id;
      await _open(tester, store);
      await _review(tester, saved.id);
      await _tap(tester, 'reuse-apply');
      expect(find.byType(CartFullScreen), findsOneWidget);
      expect(find.text('Editing Monthly shop'), findsOneWidget);
      expect(store.items.first.quantity, 0);
      expect(store.budgetPence, 5000);
      await _tap(tester, 'item-increment-$milkId');
      expect(store.savedLists.single.items.first.quantity, 1);
      await _tap(tester, 'item-edit-$milkId');
      await _enter(tester, 'item-name-input', 'Whole milk');
      await _enter(tester, 'item-price-input', '1.50');
      await _tap(tester, 'item-save');
      expect(store.savedLists.single.items.first.name, 'Whole milk');
      expect(store.savedLists.single.items.first.unitPricePence, 150);
      await _tap(tester, 'budget-edit');
      await _enter(tester, 'budget-input', '55.00');
      await _tap(tester, 'budget-save');
      expect(store.savedLists.single.budgetPence, 5500);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final restored = CartStore(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      await _open(tester, restored);
      expect(find.text('Editing Monthly shop'), findsOneWidget);
      expect(restored.activeList!.id, saved.id);
      expect(restored.items.first.name, 'Whole milk');
      expect(restored.items.first.unitPricePence, 150);
      await _tap(tester, 'item-increment-$milkId');
      expect(restored.savedLists, hasLength(1));
      expect(restored.savedLists.single.items.first.quantity, 2);
      expect(restored.budgetPence, 5500);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switch cancellation and a dismissed save form keep the current shop',
    (tester) async {
      final store = await _fixture(unsavedBasket: true);
      final saved = store.savedLists.single;
      await _open(tester, store);
      await _review(tester, saved.id);
      await _tap(tester, 'reuse-apply');
      expect(find.text('Save before switching lists?'), findsOneWidget);
      await _tap(tester, 'switch-list-cancel');
      expect(find.byType(ReuseListScreen), findsOneWidget);
      expect(store.items.single.name, 'Soap');
      expect(store.budgetPence, 8000);
      expect(store.activeList, isNull);
      await _tap(tester, 'reuse-apply');
      await _tap(tester, 'switch-list-save');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(store.items.single.name, 'Soap');
      expect(store.savedLists, hasLength(1));
      expect(find.byType(ReuseListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'save and switch preserves the previous basket as a resumable list',
    (tester) async {
      final store = await _fixture(unsavedBasket: true);
      final target = store.savedLists.single;
      await _open(tester, store);
      await _review(tester, target.id);
      await _tap(tester, 'reuse-apply');
      await _tap(tester, 'switch-list-save');
      await _enter(tester, 'list-name-input', 'Household shop');
      await _tap(tester, 'list-save');
      expect(store.activeList!.id, target.id);
      expect(store.savedLists, hasLength(2));
      final previous = store.savedLists.firstWhere(
        (list) => list.name == 'Household shop',
      );
      expect(previous.items.single.name, 'Soap');
      expect(previous.budgetPence, 8000);
      expect(find.byType(CartFullScreen), findsOneWidget);
      await store.incrementQuantity(store.items.first.id);
      expect(
        store.savedLists.firstWhere((list) => list.id == previous.id),
        same(previous),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed autosave blocks switching until retry succeeds', (
    tester,
  ) async {
    final storage = _FailingStorage();
    final store = await _fixture(storage: storage, unsavedBasket: true);
    final target = store.savedLists.single;
    await store.saveList('Household shop');
    final currentId = store.activeList!.id;
    storage.fail = true;
    await store.incrementQuantity(store.items.single.id);
    await _open(tester, store);
    await _review(tester, target.id);
    await _tap(tester, 'reuse-apply');
    expect(find.byKey(const Key('list-leave-retry')), findsOneWidget);
    await _tap(tester, 'switch-list-cancel');
    expect(store.activeList!.id, currentId);
    expect(store.items.single.quantity, 2);
    await _tap(tester, 'reuse-apply');
    await _tap(tester, 'list-leave-retry');
    expect(find.byType(ReuseListScreen), findsOneWidget);
    expect(store.activeList!.id, currentId);
    storage.fail = false;
    await _tap(tester, 'reuse-apply');
    await _tap(tester, 'list-leave-retry');
    expect(store.activeList!.id, target.id);
    final previous = store.savedLists.firstWhere(
      (list) => list.id == currentId,
    );
    expect(previous.items.single.quantity, 2);
    expect(store.storageError, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a copy keeps live edits separate from the original', (
    tester,
  ) async {
    final store = await _fixture();
    final original = store.savedLists.single;
    await store.resumeList(original.id);
    await _open(tester, store);
    await _tap(tester, 'nav-lists');
    expect(find.text('Currently editing'), findsOneWidget);
    await _tap(tester, 'save-list-from-library');
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save a copy'),
      ),
      findsOneWidget,
    );
    await _enter(tester, 'list-name-input', 'Next month');
    await _tap(tester, 'list-save');
    expect(store.savedLists, hasLength(2));
    expect(store.activeList!.name, 'Next month');
    await store.incrementQuantity(store.items.first.id);
    expect(
      store.savedLists.firstWhere((list) => list.id == original.id),
      same(original),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('City continue editing fits narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = await _fixture();
    final id = store.savedLists.single.id;
    await _open(tester, store);
    await _review(tester, id);
    await _tap(tester, 'reuse-apply');
    await _reveal(tester, 'active-list-banner');
    expect(find.text('Editing Monthly shop'), findsOneWidget);
    expect(store.activeList!.id, id);
    expect(tester.takeException(), isNull);
  });
}
