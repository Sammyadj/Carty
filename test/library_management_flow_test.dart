import 'dart:convert';

import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/screens/cart_full_screen.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  bool header = false,
}) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      header ? -250 : 250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Key key, {bool header = false}) async {
  final finder = find.byKey(key);
  await reveal(tester, finder, header: header);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> menu(WidgetTester tester, Key key, String label) async {
  await tap(tester, key);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
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

CartStore workspace() {
  final store = CartStore(storage: InMemoryCartStorage());
  addTearDown(store.dispose);
  return store;
}

void main() {
  testWidgets('search, favourite, rename, archive, and restore a saved list', (
    tester,
  ) async {
    phone(tester);
    final store = workspace();
    await store.addItem(name: 'Milk', unitPricePence: 150);
    await store.saveList('Weekly');
    final weekly = store.activeList!.id;
    await store.startNewList();
    await store.addItem(name: 'Soap', unitPricePence: 250);
    await store.saveList('Bathroom');
    final active = store.activeList!.id;
    await tester.pumpWidget(MyApp(store: store));
    await tester.pumpAndSettle();
    await tap(tester, const Key('nav-lists'));
    await menu(
      tester,
      ValueKey('saved-list-actions-$weekly'),
      'Favourite list',
    );
    await tap(tester, const ValueKey('lists-filter-favourites'), header: true);
    await reveal(
      tester,
      find.byKey(const ValueKey('lists-search')),
      header: true,
    );
    await tester.enterText(find.byKey(const ValueKey('lists-search')), 'Milk');
    await tester.pumpAndSettle();
    await menu(tester, ValueKey('saved-list-actions-$weekly'), 'Rename list');
    await tester.enterText(
      find.byKey(const Key('rename-list-input')),
      'Groceries',
    );
    await tap(tester, const Key('rename-list-save'));
    expect(
      store.savedLists.firstWhere((list) => list.id == weekly).name,
      'Groceries',
    );
    await menu(tester, ValueKey('saved-list-actions-$weekly'), 'Archive list');
    expect(
      store.savedLists.firstWhere((list) => list.id == weekly).archived,
      isTrue,
    );
    expect(store.activeList!.id, active);
    await tap(tester, const ValueKey('lists-filter-archived'), header: true);
    await menu(tester, ValueKey('saved-list-actions-$weekly'), 'Restore list');
    expect(
      store.savedLists.firstWhere((list) => list.id == weekly).archived,
      isFalse,
    );
    expect(
      store.savedLists.firstWhere((list) => list.id == weekly).favourite,
      isTrue,
    );
    expect(store.items.single.name, 'Soap');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'archiving the edited list explains detachment and respects cancellation at larger text',
    (tester) async {
      phone(tester, large: true);
      final store = workspace();
      await store.addItem(name: 'Milk', unitPricePence: 150);
      await store.saveList('Weekly');
      final id = store.activeList!.id;
      await tester.pumpWidget(MyApp(store: store));
      await tester.pumpAndSettle();
      await tap(tester, const Key('nav-lists'));
      await menu(tester, ValueKey('saved-list-actions-$id'), 'Archive list');
      expect(
        find.textContaining('automatic updates to this saved list stop'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(store.activeList!.id, id);
      await menu(tester, ValueKey('saved-list-actions-$id'), 'Archive list');
      await tap(tester, const Key('archive-active-confirm'));
      expect(store.activeList, isNull);
      expect(store.items.single.name, 'Milk');
      expect(store.savedLists.single.archived, isTrue);
      await tap(tester, const ValueKey('lists-filter-archived'), header: true);
      await menu(tester, ValueKey('saved-list-actions-$id'), 'Restore list');
      expect(store.savedLists.single.archived, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'trip reuse requires review and protects an unsaved current basket',
    (tester) async {
      phone(tester);
      final store = workspace();
      await store.addItem(name: 'Milk', unitPricePence: 175, quantity: 2);
      await store.setBudget(2000);
      await store.completeShopping('Weekly trip');
      final trip = store.history.single;
      final original = jsonEncode(trip.toJson());
      await store.addItem(name: 'Soap', unitPricePence: 300);
      await tester.pumpWidget(MyApp(store: store));
      await tester.pumpAndSettle();
      await tap(tester, const Key('nav-history'));
      await tap(tester, ValueKey('history-trip-${trip.id}'));
      await tap(tester, const Key('history-plan-trip'));
      expect(
        find.textContaining('original History record stays unchanged'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(store.items.single.name, 'Soap');
      await tap(tester, const Key('history-plan-trip'));
      await tap(tester, const Key('trip-plan-confirm'));
      expect(find.text('Save before starting a new list?'), findsOneWidget);
      await tap(tester, const Key('new-list-cancel'));
      expect(store.items.single.name, 'Soap');
      await tap(tester, const Key('history-plan-trip'));
      await tap(tester, const Key('trip-plan-confirm'));
      await tap(tester, const Key('new-list-discard'));
      expect(find.byType(CartFullScreen), findsOneWidget);
      expect(store.isPlanning, isTrue);
      expect(store.items.single.name, 'Milk');
      expect(store.items.single.quantity, 0);
      expect(store.items.single.plannedQuantity, 2);
      expect(store.estimatedTotalPence, 350);
      expect(jsonEncode(store.history.single.toJson()), original);
      expect(tester.takeException(), isNull);
    },
  );
}
