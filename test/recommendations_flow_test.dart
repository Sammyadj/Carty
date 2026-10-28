import 'package:carty_app/auth/account_gateway.dart';
import 'package:carty_app/auth/app_session.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

Future<void> reveal(WidgetTester tester, String key) async {
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
}

Future<void> tap(WidgetTester tester, String key) async {
  await reveal(tester, key);
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  await reveal(tester, key);
  await tester.enterText(find.byKey(ValueKey(key)), value);
  await tester.pumpAndSettle();
}

String text(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(ValueKey(key))).controller!.text;

Future<CartStore> regularShop() async {
  final store = CartStore(storage: InMemoryCartStorage());
  addTearDown(store.dispose);
  for (var shop = 0; shop < 2; shop++) {
    await store.addItem(name: 'Milk', unitPricePence: 165);
    await store.addItem(name: 'Bread', unitPricePence: 210);
    await store.completeShopping('Weekly $shop');
  }
  await store.addItem(name: 'Milk', unitPricePence: 165);
  await store.setBudget(2000);
  return store;
}

Future<String> historySnapshot(String name) async {
  final store = CartStore(storage: InMemoryCartStorage());
  try {
    for (var i = 0; i < 2; i++) {
      await store.addItem(name: name, unitPricePence: 250);
      await store.completeShopping('Trip $i');
    }
    return store.exportSnapshot();
  } finally {
    store.dispose();
  }
}

void main() {
  testWidgets('a starter recommendation requires an explicit price and save', (
    tester,
  ) async {
    final store = CartStore(storage: InMemoryCartStorage());
    addTearDown(store.dispose);
    await tester.pumpWidget(MyApp(store: store));
    await tester.pumpAndSettle();
    await tap(tester, 'recommendation-review-milk');
    expect(text(tester, 'item-name-input'), 'Milk');
    expect(text(tester, 'item-price-input'), isEmpty);
    expect(store.items, isEmpty);
    await tap(tester, 'item-save');
    expect(store.items, isEmpty);
    await enter(tester, 'item-price-input', '1.70');
    await tap(tester, 'item-save');
    expect(store.items.single.name, 'Milk');
    await reveal(tester, 'recommendations-section');
    expect(find.byKey(const Key('recommendation-review-milk')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a personal recommendation explains its evidence and is reviewed before saving',
    (tester) async {
      final store = await regularShop();
      await tester.pumpWidget(MyApp(store: store));
      await tester.pumpAndSettle();
      await reveal(tester, 'recommendation-review-bread');
      expect(find.text('Picked with Milk in 2 past shops'), findsOneWidget);
      final original = store.exportSnapshot();
      await tap(tester, 'recommendation-review-bread');
      expect(text(tester, 'item-name-input'), 'Bread');
      expect(text(tester, 'item-price-input'), '2.10');
      expect(text(tester, 'item-quantity-input'), '1');
      expect(find.byKey(const Key('suggested-price-note')), findsOneWidget);
      expect(store.exportSnapshot(), original);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(store.exportSnapshot(), original);
      await tap(tester, 'recommendation-review-bread');
      await enter(tester, 'item-price-input', '3.00');
      await enter(tester, 'item-quantity-input', '2');
      await tap(tester, 'item-save');
      expect(store.totalPence, 765);
      expect(store.history.first.items.last.unitPricePence, 210);
      await reveal(tester, 'recommendations-section');
      expect(
        find.byKey(const Key('recommendation-review-bread')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renaming a recommended product drops only its untouched saved estimate',
    (tester) async {
      final store = await regularShop();
      await tester.pumpWidget(MyApp(store: store));
      await tester.pumpAndSettle();
      await tap(tester, 'recommendation-review-bread');
      await enter(tester, 'item-name-input', 'My apples');
      expect(text(tester, 'item-price-input'), isEmpty);
      await enter(tester, 'item-price-input', '4.00');
      await enter(tester, 'item-name-input', 'My bananas');
      expect(text(tester, 'item-price-input'), '4.00');
      expect(store.items, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recommendations and review forms fit large text and a phone keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await regularShop();
      await tester.pumpWidget(MyApp(store: store));
      await tester.pumpAndSettle();
      await tap(tester, 'recommendation-review-bread');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(text(tester, 'item-price-input'), '2.10');
      await enter(tester, 'item-price-input', '2.25');
      await tap(tester, 'item-save');
      expect(store.totalPence, 390);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account changes remove private recommendation cards and review drafts',
    (tester) async {
      const alice = AccountIdentity(
        id: 'alice',
        email: 'alice@example.invalid',
      );
      const bob = AccountIdentity(id: 'bob', email: 'bob@example.invalid');
      final auth = FakeAccountGateway()..identity = alice;
      final repo = FakeCloudRepository();
      repo.externalEdit('alice', await historySnapshot('Alice private coffee'));
      repo.externalEdit('bob', await historySnapshot('Bob private oats'));
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
      await tap(tester, 'recommendation-review-alice private coffee');
      expect(text(tester, 'item-name-input'), 'Alice private coffee');
      auth.setUser(bob);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('item-name-input')), findsNothing);
      await reveal(tester, 'recommendation-review-bob private oats');
      expect(find.text('Alice private coffee'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
