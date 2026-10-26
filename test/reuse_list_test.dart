import 'package:carty_app/base/res/styles/app_theme.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/models/saved_shopping_list.dart';
import 'package:carty_app/screens/reuse_list_screen.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:carty_app/widgets/saved_list_card.dart';
import 'package:carty_app/widgets/saved_lists_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<CartStore> _savedListStore() async {
  final store = CartStore(storage: InMemoryCartStorage());
  await store.load();
  await store.setBudget(2500);
  await store.addItem(name: 'Milk', unitPricePence: 120, quantity: 2);
  await store.addItem(name: 'Bread', unitPricePence: 150);
  await store.saveList('Weekly groceries');
  await store.clearCart();
  await store.setBudget(900);
  await store.addItem(name: 'Tea', unitPricePence: 275);
  addTearDown(store.dispose);
  return store;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
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

Future<void> _openReuse(
  WidgetTester tester,
  CartStore store, {
  ValueChanged<bool?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: TextButton(
              key: const ValueKey('open-reuse'),
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder:
                        (_) => ReuseListScreen(
                          store: store,
                          list: store.savedLists.single,
                        ),
                  ),
                );
                onResult?.call(result);
              },
              child: const Text('Open saved list'),
            ),
          );
        },
      ),
    ),
  );
  await _tap(tester, 'open-reuse');
}

void main() {
  testWidgets('duplicate is the default and review does not alter the basket', (
    tester,
  ) async {
    final store = await _savedListStore();
    await _openReuse(tester, store);

    final duplicate = tester.widget<RadioListTile<bool>>(
      find.byKey(const ValueKey('reuse-duplicate')),
    );
    expect(duplicate.value, isFalse);
    expect(duplicate.groupValue, isFalse);
    expect(find.byKey(const ValueKey('reuse-apply')), findsNothing);

    await _tap(tester, 'reuse-continue');

    expect(find.text('Review list'), findsOneWidget);
    expect(find.textContaining('not live quotes'), findsOneWidget);
    expect(find.textContaining('replaces your current basket'), findsOneWidget);
    expect(find.text('Quantity: 2'), findsOneWidget);
    expect(find.text('£1.20 each'), findsOneWidget);
    expect(store.items.single.name, 'Tea');
    expect(store.budgetPence, 900);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'back from review keeps the mode and cancelling keeps the basket',
    (tester) async {
      final store = await _savedListStore();
      bool? result;
      await _openReuse(tester, store, onResult: (value) => result = value);

      await _tap(tester, 'reuse-fresh');
      await _tap(tester, 'reuse-continue');
      await _tap(tester, 'reuse-back');

      expect(find.text('How would you like to start?'), findsOneWidget);
      final fresh = tester.widget<RadioListTile<bool>>(
        find.byKey(const ValueKey('reuse-fresh')),
      );
      expect(fresh.groupValue, isTrue);

      await _tap(tester, 'reuse-cancel');
      expect(result, isFalse);
      expect(store.items.single.name, 'Tea');
      expect(store.budgetPence, 900);
      expect(store.savedLists.single.items.first.quantity, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'duplicate applies only at confirmation and preserves the saved list',
    (tester) async {
      final store = await _savedListStore();
      final saved = store.savedLists.single;
      bool? result;
      await _openReuse(tester, store, onResult: (value) => result = value);
      await _tap(tester, 'reuse-continue');

      expect(store.items.single.name, 'Tea');
      await _tap(tester, 'reuse-apply');

      expect(result, isTrue);
      expect(store.items.map((item) => item.name), ['Milk', 'Bread']);
      expect(store.items.map((item) => item.quantity), [2, 1]);
      expect(store.budgetPence, 2500);
      expect(store.savedLists.single, same(saved));
      expect(store.items.first.id, isNot(saved.items.first.id));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fresh review previews zero quantities and resets budget on apply',
    (tester) async {
      final store = await _savedListStore();
      final original = store.savedLists.single;
      await _openReuse(tester, store);
      await _tap(tester, 'reuse-fresh');
      await _tap(tester, 'reuse-continue');

      expect(find.text('Quantity: 0'), findsNWidgets(2));
      expect(store.items.single.name, 'Tea');
      await _tap(tester, 'reuse-apply');

      expect(store.items.map((item) => item.quantity), [0, 0]);
      expect(store.items.map((item) => item.unitPricePence), [120, 150]);
      expect(store.totalPence, 0);
      expect(store.budgetPence, isNull);
      expect(original.items.map((item) => item.quantity), [2, 1]);
      expect(original.budgetPence, 2500);
      expect(store.savedLists.single, same(original));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('system back from review returns to mode selection', (
    tester,
  ) async {
    final store = await _savedListStore();
    await _openReuse(tester, store);
    await _tap(tester, 'reuse-continue');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('How would you like to start?'), findsOneWidget);
    expect(store.items.single.name, 'Tea');
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved card use and delete actions stay separate', (
    tester,
  ) async {
    final store = await _savedListStore();
    final list = store.savedLists.single;
    var used = 0;
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SavedListCard(
            list: list,
            onUse: () => used++,
            onDelete: () => deleted++,
          ),
        ),
      ),
    );

    await _tap(tester, 'saved-list-delete-${list.id}');
    expect(deleted, 1);
    expect(used, 0);
    await _tap(tester, 'saved-list-load-${list.id}');
    expect(used, 1);
    expect(deleted, 1);
    expect(find.textContaining('Saved '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'library disables saving an empty basket and updates with products',
    (tester) async {
      final store = CartStore(storage: InMemoryCartStorage());
      await store.load();
      addTearDown(store.dispose);
      var created = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SavedListsView(
              store: store,
              onUseList: (_) {},
              onCreateList: () => created++,
              onDeleteList: (_) {},
            ),
          ),
        ),
      );
      final button = find.byKey(const ValueKey('save-list-from-library'));
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(find.text('Make your next shop easier'), findsOneWidget);

      await store.addItem(name: 'Apples', unitPricePence: 120);
      await tester.pumpAndSettle();
      await _tap(tester, 'save-list-from-library');
      expect(created, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reuse and saved cards fit narrow screens with large text', (
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
    await store.addItem(
      name: 'A long name for a favourite brand of wholemeal breakfast bread',
      unitPricePence: 250,
      quantity: 12,
    );
    await store.saveList(
      'A long saved list name for the whole family shopping',
    );
    addTearDown(store.dispose);
    await _openReuse(tester, store);
    await _tap(tester, 'reuse-fresh');
    await _tap(tester, 'reuse-continue');
    expect(tester.takeException(), isNull);
    await _tap(tester, 'reuse-back');
    await _tap(tester, 'reuse-cancel');

    final list = store.savedLists.single;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SavedListsView(
            store: store,
            onUseList: (SavedShoppingList _) {},
            onCreateList: () {},
            onDeleteList: (SavedShoppingList _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(list.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
