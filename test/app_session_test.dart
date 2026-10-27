import 'dart:async';

import 'package:carty_app/auth/account_gateway.dart';
import 'package:carty_app/auth/app_session.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

const alice = AccountIdentity(id: 'alice', email: 'alice@example.invalid');
const bob = AccountIdentity(id: 'bob', email: 'bob@example.invalid');

CartStore emptyGuest() {
  final guest = CartStore(storage: InMemoryCartStorage());
  addTearDown(guest.dispose);
  return guest;
}

Future<void> settleSession(AppSession session) async {
  await Future<void>.delayed(Duration.zero);
  await session.cloud?.sync();
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'accounts and guest data use separate caches without automatic import',
    () async {
      final auth = FakeAccountGateway()..identity = alice;
      final repo = FakeCloudRepository();
      repo.externalEdit('alice', await exampleSnapshot('Alice milk'));
      repo.externalEdit('bob', await exampleSnapshot('Bob bread'));
      final guest = CartStore(storage: InMemoryCartStorage());
      await guest.addItem(name: 'Guest soap', unitPricePence: 200);
      final caches = <String, InMemoryCartStorage>{};
      final session = AppSession(
        gateway: auth,
        repository: repo,
        guestStore: guest,
        autoSync: false,
        cacheFactory: (id) => caches.putIfAbsent(id, InMemoryCartStorage.new),
      );
      addTearDown(session.dispose);
      addTearDown(guest.dispose);
      addTearDown(auth.dispose);
      await session.initialize();
      await settleSession(session);
      expect(session.store.items.single.name, 'Alice milk');
      expect(session.guest.items.single.name, 'Guest soap');
      expect(repo.saves, isEmpty);
      await session.store.incrementQuantity(session.store.items.single.id);
      await session.signOut();
      expect(session.user, isNull);
      expect(session.store, same(guest));
      auth.setUser(bob);
      await settleSession(session);
      expect(session.store.items.single.name, 'Bob bread');
      auth.setUser(alice);
      await settleSession(session);
      expect(session.store.items.single.name, 'Alice milk');
      expect(session.store.items.single.quantity, 2);
      expect(caches.keys, containsAll(['alice', 'bob']));
    },
  );

  test('a stale auth event cannot switch back to a previous account', () async {
    final auth = FakeAccountGateway()..identity = alice;
    final repo = FakeCloudRepository();
    final session = AppSession(
      gateway: auth,
      repository: repo,
      guestStore: emptyGuest(),
      autoSync: false,
      cacheFactory: (_) => InMemoryCartStorage(),
    );
    addTearDown(session.dispose);
    addTearDown(auth.dispose);
    await session.initialize();
    auth.setUser(bob);
    await settleSession(session);
    auth.events.add(alice);
    await settleSession(session);
    expect(session.user!.id, 'bob');
  });

  test(
    'a late profile response cannot expose the previous account name',
    () async {
      final auth = _DelayedProfile()..identity = alice;
      final repo = FakeCloudRepository();
      final session = AppSession(
        gateway: auth,
        repository: repo,
        guestStore: emptyGuest(),
        autoSync: false,
        cacheFactory: (_) => InMemoryCartStorage(),
      );
      addTearDown(session.dispose);
      addTearDown(auth.dispose);
      final initializing = session.initialize();
      await auth.entered.future;
      auth.setUser(bob);
      await settleSession(session);
      auth.release.complete('Private Alice name');
      await initializing;
      expect(session.user!.id, 'bob');
      expect(session.displayName, 'Bob name');
    },
  );

  test(
    'deletion erases only the active account cache and keeps guest data',
    () async {
      final auth = FakeAccountGateway()..identity = alice;
      final repo = FakeCloudRepository();
      final guest = CartStore(storage: InMemoryCartStorage());
      await guest.addItem(name: 'Guest soap', unitPricePence: 200);
      final caches = <String, InMemoryCartStorage>{};
      final session = AppSession(
        gateway: auth,
        repository: repo,
        guestStore: guest,
        autoSync: false,
        cacheFactory: (id) => caches.putIfAbsent(id, InMemoryCartStorage.new),
      );
      addTearDown(session.dispose);
      addTearDown(guest.dispose);
      addTearDown(auth.dispose);
      await session.initialize();
      await session.store.addItem(name: 'Alice milk', unitPricePence: 125);
      auth.setUser(bob);
      await settleSession(session);
      await session.store.addItem(name: 'Bob bread', unitPricePence: 200);
      final bobCache = caches['bob']!.value;
      auth.setUser(alice);
      await settleSession(session);
      await session.deleteAccount();
      expect(auth.deleted, ['alice']);
      expect(caches['alice']!.value, isNull);
      expect(caches['bob']!.value, bobCache);
      expect(session.user, isNull);
      expect(session.store.items.single.name, 'Guest soap');
    },
  );

  test(
    'a failed account deletion preserves the session and local account data',
    () async {
      final auth = FakeAccountGateway()..identity = alice;
      final repo = FakeCloudRepository();
      final cache = InMemoryCartStorage();
      final session = AppSession(
        gateway: auth,
        repository: repo,
        guestStore: emptyGuest(),
        autoSync: false,
        cacheFactory: (_) => cache,
      );
      addTearDown(session.dispose);
      addTearDown(auth.dispose);
      await session.initialize();
      await session.store.addItem(name: 'Milk', unitPricePence: 125);
      final original = cache.value;
      auth.failDelete = true;
      await expectLater(
        session.deleteAccount(),
        throwsA(isA<AccountProblem>()),
      );
      expect(session.user!.id, 'alice');
      expect(cache.value, original);
      expect(session.store.items.single.name, 'Milk');
    },
  );

  test(
    'guest data reaches the account only after an explicit import',
    () async {
      final auth = FakeAccountGateway()..identity = alice;
      final repo = FakeCloudRepository();
      final guest = CartStore(storage: InMemoryCartStorage());
      await guest.addItem(name: 'Guest milk', unitPricePence: 125);
      final original = guest.exportSnapshot();
      final session = AppSession(
        gateway: auth,
        repository: repo,
        guestStore: guest,
        autoSync: false,
        cacheFactory: (_) => InMemoryCartStorage(),
      );
      addTearDown(session.dispose);
      addTearDown(guest.dispose);
      addTearDown(auth.dispose);
      await session.initialize();
      await settleSession(session);
      expect(repo.saves, isEmpty);
      expect(session.store.hasData, isFalse);
      await session.importGuestLists();
      await session.cloud!.sync();
      expect(session.store.savedLists.single.items.single.name, 'Guest milk');
      expect(repo.rows['alice']!.snapshot, contains('Guest milk'));
      expect(guest.exportSnapshot(), original);
    },
  );
}

class _DelayedProfile extends FakeAccountGateway {
  final entered = Completer<void>();
  final release = Completer<String>();
  @override
  Future<String> loadDisplayName(String id) async {
    if (id == 'alice') {
      entered.complete();
      return release.future;
    }
    return 'Bob name';
  }
}
