import 'package:carty_app/auth/account_gateway.dart';
import 'package:carty_app/auth/app_session.dart';
import 'package:carty_app/config/supabase_config.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/main.dart';
import 'package:carty_app/screens/account_screen.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

CartStore emptyGuest() {
  final guest = CartStore(storage: InMemoryCartStorage());
  addTearDown(guest.dispose);
  return guest;
}

Future<void> reveal(WidgetTester tester, String key) async {
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

void main() {
  test('only the registered Carty callback is accepted for authentication', () {
    expect(
      SupabaseConfig.isAuthCallback(
        Uri.parse('${SupabaseConfig.authCallback}?code=example'),
      ),
      isTrue,
    );
    for (final url in [
      'https://example.com/auth/callback?code=example',
      'com.samueladjei.carty://other/callback?code=example',
      'com.samueladjei.carty://auth/other?code=example',
    ]) {
      expect(SupabaseConfig.isAuthCallback(Uri.parse(url)), isFalse);
    }
  });

  testWidgets(
    'sign-in link validates email and a verified session opens private data',
    (tester) async {
      final auth = FakeAccountGateway();
      final repo = FakeCloudRepository();
      repo.externalEdit('alice', await exampleSnapshot('Alice milk'));
      final guest = CartStore(storage: InMemoryCartStorage());
      await guest.addItem(name: 'Guest bread', unitPricePence: 200);
      final session = AppSession(
        gateway: auth,
        repository: repo,
        guestStore: guest,
        autoSync: false,
        cacheFactory: (_) => InMemoryCartStorage(),
      );
      addTearDown(session.dispose);
      addTearDown(auth.dispose);
      addTearDown(guest.dispose);
      await tester.pumpWidget(MyApp(session: session));
      await tester.pumpAndSettle();
      await tap(tester, 'account-open');
      await enter(tester, 'account-email', 'not an email');
      await tap(tester, 'account-send-link');
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(auth.requestedEmails, isEmpty);
      await enter(tester, 'account-email', 'alice@example.invalid');
      await tap(tester, 'account-send-link');
      expect(auth.requestedEmails, ['alice@example.invalid']);
      expect(
        find.textContaining('Open the sign-in link on this device'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('account-resend-link')))
            .onPressed,
        isNull,
      );
      // Represents the SDK receiving a verified PKCE callback from the email link.
      auth.setUser(
        const AccountIdentity(id: 'alice', email: 'alice@example.invalid'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsNothing);
      expect(session.store.items.single.name, 'Alice milk');
      expect(guest.items.single.name, 'Guest bread');
      expect(repo.saves, isEmpty);
      await tap(tester, 'account-open');
      await enter(tester, 'account-display-name', 'Sam');
      await tap(tester, 'account-save-profile');
      expect(auth.names['alice'], 'Sam');
      expect(find.text('Profile saved.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching accounts closes old private routes and form contents',
    (tester) async {
      final auth = FakeAccountGateway()
        ..identity = const AccountIdentity(
          id: 'alice',
          email: 'alice@example.invalid',
        );
      final repo = FakeCloudRepository();
      repo.externalEdit('alice', await exampleSnapshot('Private Alice milk'));
      repo.externalEdit('bob', await exampleSnapshot('Private Bob bread'));
      final session = AppSession(
        gateway: auth,
        repository: repo,
        guestStore: emptyGuest(),
        autoSync: false,
        cacheFactory: (_) => InMemoryCartStorage(),
      );
      addTearDown(session.dispose);
      addTearDown(auth.dispose);
      await tester.pumpWidget(MyApp(session: session));
      await tester.pumpAndSettle();
      final itemId = session.store.items.single.id;
      await tap(tester, 'item-edit-$itemId');
      await enter(tester, 'item-name-input', 'Unsaved private edit');
      auth.setUser(
        const AccountIdentity(id: 'bob', email: 'bob@example.invalid'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('item-name-input')), findsNothing);
      expect(find.text('Unsaved private edit'), findsNothing);
      expect(session.store.items.single.name, 'Private Bob bread');
      expect(find.text('Private Alice milk'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history records a finished shop and stays independent of reusable lists',
    (tester) async {
      final store = CartStore(storage: InMemoryCartStorage());
      addTearDown(store.dispose);
      await store.addItem(name: 'Milk', unitPricePence: 125, quantity: 2);
      await store.addItem(name: 'Bread', unitPricePence: 200, quantity: 0);
      await store.setBudget(2000);
      await store.saveList('Weekly');
      final listId = store.activeList!.id;
      await tester.pumpWidget(MyApp(store: store));
      await tester.pumpAndSettle();
      await tap(tester, 'finish-shop');
      expect(find.textContaining('No payment is taken'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(store.items, hasLength(2));
      expect(store.history, isEmpty);
      await tap(tester, 'finish-shop');
      await tap(tester, 'finish-shop-confirm');
      expect(store.items, isEmpty);
      expect(store.history.single.totalPence, 250);
      await tap(tester, 'nav-history');
      await tap(tester, 'history-trip-${store.history.single.id}');
      expect(find.text('Recorded basket total'), findsOneWidget);
      expect(find.textContaining('Carty did not take payment'), findsOneWidget);
      await tap(tester, 'history-delete-trip');
      await tap(tester, 'history-delete-confirm');
      expect(store.history, isEmpty);
      expect(store.savedLists.single.id, listId);
      expect(tester.takeException(), isNull);
    },
  );

  for (final signedIn in [false, true]) {
    testWidgets(
      'account screen fits a narrow phone with large text, signed in: $signedIn',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final auth = FakeAccountGateway();
        if (signedIn) {
          auth.identity = const AccountIdentity(
            id: 'alice',
            email: 'alice@example.invalid',
          );
        }
        final session = AppSession(
          gateway: auth,
          repository: FakeCloudRepository(),
          guestStore: emptyGuest(),
          autoSync: false,
          cacheFactory: (_) => InMemoryCartStorage(),
        );
        addTearDown(session.dispose);
        addTearDown(auth.dispose);
        await tester.pumpWidget(MyApp(session: session));
        await tester.pumpAndSettle();
        await tap(tester, 'account-open');
        if (signedIn) {
          await enter(tester, 'account-display-name', 'A shopper name');
          await tap(tester, 'account-save-profile');
        } else {
          await enter(tester, 'account-email', 'alice@example.invalid');
          await tap(tester, 'account-send-link');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('conflicting copies can be reviewed, cancelled, and recovered', (
    tester,
  ) async {
    final auth = FakeAccountGateway()
      ..identity = const AccountIdentity(
        id: 'alice',
        email: 'alice@example.invalid',
      );
    final repo = FakeCloudRepository();
    repo.externalEdit('alice', await exampleSnapshot('Original milk'));
    final session = AppSession(
      gateway: auth,
      repository: repo,
      guestStore: emptyGuest(),
      autoSync: false,
      cacheFactory: (_) => InMemoryCartStorage(),
    );
    addTearDown(auth.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MyApp(session: session));
    await tester.pumpAndSettle();
    await session.store.addItem(name: 'Device apples', unitPricePence: 200);
    repo.externalEdit('alice', await exampleSnapshot('Cloud bread'));
    await session.cloud!.sync();
    await tester.pumpAndSettle();
    await tap(tester, 'account-open');
    expect(find.text('On this device'), findsOneWidget);
    expect(find.text('In the cloud'), findsOneWidget);
    await tester.tap(find.text('In the cloud'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cloud bread ·'), findsOneWidget);
    await tap(tester, 'sync-use-cloud');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(
      session.store.items.any((item) => item.name == 'Device apples'),
      isTrue,
    );
    await tap(tester, 'sync-use-cloud');
    await tap(tester, 'account-confirm');
    expect(session.store.items.single.name, 'Cloud bread');
    await tap(tester, 'sync-restore-backup');
    await tap(tester, 'account-confirm');
    expect(
      session.store.items.any((item) => item.name == 'Device apples'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
