import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
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

Future<CartStore> open(
  WidgetTester tester, {
  CartStorage? storage,
  bool items = true,
}) async {
  final store = CartStore(storage: storage ?? InMemoryCartStorage());
  addTearDown(store.dispose);
  await store.setBudget(2000);
  if (items) await store.addItem(name: 'Milk', unitPricePence: 120);
  await tester.pumpWidget(MyApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

Future<void> tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('full basket new-list action resets the active shop', (
    tester,
  ) async {
    final store = await open(tester);
    final control = find.byKey(const Key('cart-open'));
    await tester.scrollUntilVisible(
      control,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    await tester.tap(control);
    await tester.pumpAndSettle();
    await tap(tester, 'new-list');
    await tap(tester, 'new-list-discard');
    expect(store.items, isEmpty);
    expect(store.budgetPence, isNull);
    expect(find.text('Your basket'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save prompt fits a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    await tap(tester, 'new-list');
    expect(find.byKey(const Key('new-list-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tap(tester, 'new-list-cancel');
  });

  testWidgets('cancel and dismissed save form keep the current list', (
    tester,
  ) async {
    final store = await open(tester);
    await tap(tester, 'new-list');
    await tap(tester, 'new-list-cancel');
    expect(store.items.single.name, 'Milk');
    expect(store.budgetPence, 2000);
    await tap(tester, 'new-list');
    await tap(tester, 'new-list-save');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.items.single.name, 'Milk');
    expect(store.savedLists, isEmpty);
  });

  testWidgets('save and start new preserves old list and resets the budget', (
    tester,
  ) async {
    final store = await open(tester);
    await tap(tester, 'new-list');
    await tap(tester, 'new-list-save');
    await tester.enterText(find.byKey(const Key('list-name-input')), 'Weekly');
    await tap(tester, 'list-save');
    expect(store.items, isEmpty);
    expect(store.budgetPence, isNull);
    expect(store.savedLists.single.items.single.name, 'Milk');
    expect(store.savedLists.single.budgetPence, 2000);
  });

  testWidgets('explicit discard starts new without creating a saved list', (
    tester,
  ) async {
    final store = await open(tester);
    await tap(tester, 'new-list');
    await tap(tester, 'new-list-discard');
    expect(store.items, isEmpty);
    expect(store.budgetPence, isNull);
    expect(store.savedLists, isEmpty);
  });

  testWidgets('unchanged saved basket starts new without a save prompt', (
    tester,
  ) async {
    final store = await open(tester);
    await store.saveList('Weekly');
    await tester.pumpAndSettle();
    await tap(tester, 'new-list');
    expect(find.byKey(const Key('new-list-save')), findsNothing);
    expect(store.items, isEmpty);
    expect(store.savedLists.single.name, 'Weekly');
  });

  testWidgets('Lists create action returns to an empty Home basket', (
    tester,
  ) async {
    final store = await open(tester);
    await tap(tester, 'nav-lists');
    await tap(tester, 'new-list-from-library');
    await tap(tester, 'new-list-discard');
    expect(find.byKey(const Key('add-item')), findsOneWidget);
    expect(store.items, isEmpty);
    expect(store.budgetPence, isNull);
  });

  testWidgets(
    'budget-only shop can be cancelled or discarded without empty save',
    (tester) async {
      final store = await open(tester, items: false);
      await tap(tester, 'new-list');
      expect(find.byKey(const Key('new-list-save')), findsNothing);
      await tap(tester, 'new-list-cancel');
      expect(store.budgetPence, 2000);
      await tap(tester, 'new-list');
      await tap(tester, 'new-list-discard');
      expect(store.budgetPence, isNull);
    },
  );

  testWidgets('failed save leaves active basket intact', (tester) async {
    final storage = _FailingStorage();
    final store = await open(tester, storage: storage);
    storage.fail = true;
    await tap(tester, 'new-list');
    await tap(tester, 'new-list-save');
    await tester.enterText(find.byKey(const Key('list-name-input')), 'Weekly');
    await tap(tester, 'list-save');
    expect(store.items.single.name, 'Milk');
    expect(store.budgetPence, 2000);
    expect(store.storageError, isNotNull);
    await tap(tester, 'new-list');
    expect(find.byKey(const Key('list-leave-retry')), findsOneWidget);
    expect(store.items.single.name, 'Milk');
  });
}
