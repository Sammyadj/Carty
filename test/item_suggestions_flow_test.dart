import 'package:carty_app/auth/account_gateway.dart';
import 'package:carty_app/auth/app_session.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/models/product_details.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

Future<void> tap(WidgetTester tester, String key) async {
  final control = find.byKey(ValueKey(key));
  if (control.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      control,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

String fieldValue(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(ValueKey(key))).controller!.text;

Future<CartStore> openPlanningApp(WidgetTester tester) async {
  final store = CartStore(storage: InMemoryCartStorage());
  addTearDown(store.dispose);
  await store.addItem(name: 'Organic whole milk', unitPricePence: 165);
  await store.saveList('Weekly');
  await store.startNewList();
  await tester.pumpWidget(MyApp(store: store));
  await tester.pumpAndSettle();
  await tap(tester, 'add-item');
  return store;
}

void main() {
  testWidgets(
    'choosing a saved item fills name and last price, then waits for Save',
    (tester) async {
      final store = await openPlanningApp(tester);
      await enter(tester, 'item-name-input', 'mi');
      expect(
        find.textContaining('From saved lists · Saved price £1.65'),
        findsOneWidget,
      );
      await tap(tester, 'item-suggestion-0');
      expect(fieldValue(tester, 'item-name-input'), 'Organic whole milk');
      expect(fieldValue(tester, 'item-price-input'), '1.65');
      expect(fieldValue(tester, 'item-quantity-input'), '1');
      expect(find.byKey(const Key('suggested-price-note')), findsOneWidget);
      expect(store.items, isEmpty);
      await enter(tester, 'item-quantity-input', '3');
      await tap(tester, 'item-save');
      expect(store.totalPence, 495);
      expect(store.items.single.name, 'Organic whole milk');
      expect(store.savedLists.single.items.single.quantity, 1);
    },
  );

  testWidgets('suggestions preserve a price and quantity already entered', (
    tester,
  ) async {
    final store = await openPlanningApp(tester);
    await enter(tester, 'item-price-input', '4.20');
    await enter(tester, 'item-quantity-input', '0');
    await enter(tester, 'item-name-input', 'mil');
    await tap(tester, 'item-suggestion-0');
    expect(fieldValue(tester, 'item-price-input'), '4.20');
    expect(fieldValue(tester, 'item-quantity-input'), '0');
    expect(find.byKey(const Key('suggested-price-note')), findsNothing);
    await tap(tester, 'item-save');
    expect(store.items.single.unitPricePence, 420);
    expect(store.items.single.quantity, 0);
    expect(store.totalPence, 0);
  });

  testWidgets('changing an auto-filled name removes its suggested price', (
    tester,
  ) async {
    final store = await openPlanningApp(tester);
    await enter(tester, 'item-name-input', 'mil');
    await tap(tester, 'item-suggestion-0');
    await enter(tester, 'item-name-input', 'egg');
    expect(fieldValue(tester, 'item-price-input'), isEmpty);
    expect(find.byKey(const Key('suggested-price-note')), findsNothing);
    await tap(tester, 'item-suggestion-0');
    expect(fieldValue(tester, 'item-name-input'), 'Eggs');
    expect(fieldValue(tester, 'item-price-input'), isEmpty);
    await tap(tester, 'item-save');
    expect(
      find.text('Enter a price above £0 with up to 2 decimals'),
      findsOneWidget,
    );
    expect(store.items, isEmpty);
    await enter(tester, 'item-price-input', '2.50');
    await tap(tester, 'item-save');
    expect(store.items.single.name, 'Eggs');
    expect(store.items.single.unitPricePence, 250);
  });

  testWidgets('an edited estimate is preserved when choosing another item', (
    tester,
  ) async {
    await openPlanningApp(tester);
    await enter(tester, 'item-name-input', 'mil');
    await tap(tester, 'item-suggestion-0');
    await enter(tester, 'item-price-input', '2.00');
    await enter(tester, 'item-name-input', 'egg');
    await tap(tester, 'item-suggestion-0');
    expect(fieldValue(tester, 'item-price-input'), '2.00');
    expect(find.byKey(const Key('suggested-price-note')), findsNothing);
  });

  testWidgets('cancelling a suggested item leaves the workspace unchanged', (
    tester,
  ) async {
    final store = await openPlanningApp(tester);
    final original = store.exportSnapshot();
    await enter(tester, 'item-name-input', 'mil');
    await tap(tester, 'item-suggestion-0');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(store.exportSnapshot(), original);
  });

  testWidgets(
    'Next moves to price and hides suggestions; editing has no suggestions',
    (tester) async {
      final store = await openPlanningApp(tester);
      await enter(tester, 'item-name-input', 'mi');
      expect(find.byKey(const Key('item-suggestions')), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('item-suggestions')), findsNothing);
      await enter(tester, 'item-price-input', '1.00');
      await tap(tester, 'item-save');
      final id = store.items.single.id;
      await tap(tester, 'item-edit-$id');
      await enter(tester, 'item-name-input', 'mil');
      expect(find.byKey(const Key('item-suggestions')), findsNothing);
      expect(fieldValue(tester, 'item-price-input'), '1.00');
    },
  );

  testWidgets(
    'full basket suggestions include completed shops without merging a scan',
    (tester) async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addScannedItem(
        product: const ProductDetails(
          barcode: '4006381333931',
          name: 'Store milk',
        ),
        name: 'Store milk',
        unitPricePence: 180,
      );
      await store.completeShopping('Yesterday');
      await store.addItem(name: 'Bread', unitPricePence: 100);
      await tester.pumpWidget(MyApp(store: store));
      await tester.pumpAndSettle();
      await tap(tester, 'cart-open');
      await tap(tester, 'add-item');
      await enter(tester, 'item-name-input', 'milk');
      expect(
        find.textContaining('From shopping history · Saved price £1.80'),
        findsOneWidget,
      );
      await tap(tester, 'item-suggestion-0');
      await tap(tester, 'item-save');
      expect(store.items.last.name, 'Store milk');
      expect(store.items.last.product, isNull);
      expect(
        store.history.single.items.single.product!.barcode,
        '4006381333931',
      );
    },
  );

  testWidgets(
    'suggestions remain usable with large text and an open phone keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openPlanningApp(tester);
      await enter(tester, 'item-name-input', 'mil');
      await tap(tester, 'item-suggestion-0');
      expect(fieldValue(tester, 'item-name-input'), 'Organic whole milk');
      expect(fieldValue(tester, 'item-price-input'), '1.65');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching accounts cannot suggest the previous account’s items',
    (tester) async {
      const alice = AccountIdentity(
        id: 'alice',
        email: 'alice@example.invalid',
      );
      const bob = AccountIdentity(id: 'bob', email: 'bob@example.invalid');
      final auth = FakeAccountGateway()..identity = alice;
      final repo = FakeCloudRepository();
      repo.externalEdit('alice', await exampleSnapshot('Alice private oats'));
      repo.externalEdit('bob', await exampleSnapshot('Bob private coffee'));
      final guest = CartStore(storage: InMemoryCartStorage());
      final session = AppSession(
        gateway: auth,
        repository: repo,
        guestStore: guest,
        autoSync: false,
        cacheFactory: (_) => InMemoryCartStorage(),
      );
      addTearDown(auth.dispose);
      addTearDown(guest.dispose);
      addTearDown(session.dispose);
      await tester.pumpWidget(MyApp(session: session));
      await tester.pumpAndSettle();
      await tap(tester, 'add-item');
      await enter(tester, 'item-name-input', 'ali');
      expect(find.text('Alice private oats'), findsWidgets);
      auth.setUser(bob);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('item-name-input')), findsNothing);
      await tap(tester, 'add-item');
      await enter(tester, 'item-name-input', 'ali');
      expect(find.byKey(const Key('item-suggestions')), findsNothing);
      expect(find.text('Alice private oats'), findsNothing);
      await enter(tester, 'item-name-input', 'bob');
      expect(find.text('Bob private coffee'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
