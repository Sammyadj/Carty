import 'dart:async';

import 'package:carty_app/auth/account_gateway.dart';
import 'package:carty_app/auth/app_session.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/sharing/shared_list.dart';
import 'package:carty_app/sharing/shared_list_cache.dart';
import 'package:carty_app/sharing/shared_repository.dart';
import 'package:carty_app/state/cart_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

const alice = AccountIdentity(id: 'alice', email: 'alice@example.invalid');
const bob = AccountIdentity(id: 'bob', email: 'bob@example.invalid');

SharedContent basket(int quantity) => SharedContent(
  name: 'Household',
  budgetPence: 5000,
  isPlanning: false,
  items: [
    CartItem(id: 'milk', name: 'Milk', unitPricePence: 150, quantity: quantity),
  ],
);

class _Repository implements SharedRepository {
  _Repository(this.accountId);
  @override
  final String accountId;
  int fetches = 0;
  Future<void> Function()? beforeFetch;
  @override
  Future<SharedListDocument?> fetch(String listId) async {
    fetches++;
    await beforeFetch?.call();
    return SharedListDocument(
      SharedListHeader(
        id: listId,
        ownerId: accountId,
        name: 'Household',
        budgetPence: 5000,
        isPlanning: false,
        revision: 1,
        updatedAt: DateTime.utc(2026),
        role: SharedRole.owner,
      ),
      basket(1).items,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cache implements SharedListCache {
  CachedSharedList? value;
  Future<void> Function()? beforeWrite;
  @override
  Future<CachedSharedList?> read() async => value;
  @override
  Future<void> write(CachedSharedList value) async {
    await beforeWrite?.call();
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _PrivateCache extends InMemoryCartStorage {
  Future<void> Function()? onClear;
  Future<void> Function()? beforeWrite;
  @override
  Future<void> write(String value) async {
    await beforeWrite?.call();
    await super.write(value);
  }

  @override
  Future<void> clear() async {
    await onClear?.call();
    await super.clear();
  }
}

class _DelayedDelete extends FakeAccountGateway {
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<void> deleteAccount() async {
    final target = currentUser!.id;
    entered.complete();
    await release.future;
    deleted.add(target);
  }
}

Future<void> settle(AppSession session) async {
  for (var i = 0; i < 20 && session.isLoading; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(session.isLoading, false);
}

void main() {
  late FakeAccountGateway auth;
  late CartStore guest;
  late Map<String, _Cache> caches;
  late Map<String, _PrivateCache> privateCaches;
  late List<_Repository> repositories;
  setUp(() {
    auth = FakeAccountGateway()..identity = alice;
    guest = CartStore(storage: InMemoryCartStorage());
    caches = {};
    privateCaches = {};
    repositories = [];
    addTearDown(guest.dispose);
  });
  AppSession session() {
    final value = AppSession(
      gateway: auth,
      repository: FakeCloudRepository(),
      guestStore: guest,
      autoSync: false,
      cacheFactory: (account) =>
          privateCaches.putIfAbsent(account, _PrivateCache.new),
      sharingRepositoryFactory: (account) {
        final repository = _Repository(account);
        repositories.add(repository);
        return repository;
      },
      sharedCacheFactory: (account, list) =>
          caches.putIfAbsent('$account/$list', _Cache.new),
    );
    addTearDown(value.dispose);
    addTearDown(auth.dispose);
    return value;
  }

  test('a sign-out waiting for a save cannot sign out a subsequently selected account', () async {
    final app = session();
    await app.initialize();
    await app.cloud!.sync();
    final entered = Completer<void>(), release = Completer<void>();
    privateCaches['alice']!.beforeWrite = () async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    final editing = app.store.addItem(name: 'Milk', unitPricePence: 150);
    await entered.future;
    final signingOut = app.signOut();
    final rejected = expectLater(signingOut, throwsA(isA<AccountProblem>()));
    auth.setUser(bob);
    await settle(app);
    release.complete();
    await editing;
    await rejected;
    expect(auth.currentUser, bob);
    expect(app.user, bob);
    expect(app.sharing!.repository.accountId, 'bob');
  });

  test('sign-in owns one controller per list and sign-out leaves private guest data intact', () async {
    await guest.addItem(name: 'Guest bread', unitPricePence: 100);
    final app = session();
    await app.initialize();
    final workspace = app.sharing!;
    final controller = workspace.openList('weekly');
    expect(workspace.openList('weekly'), same(controller));
    await controller.refresh();
    await workspace.refreshOpenLists();
    expect(repositories.single.fetches, 2);
    await app.signOut();
    expect(app.sharing, isNull);
    expect(controller.canEdit, false);
    expect(() => workspace.openList('other'), throwsA(isA<AccountProblem>()));
    expect(app.store.items.single.name, 'Guest bread');
    expect(caches['alice/weekly']!.value, isNotNull);
  });

  test(
    'switching accounts closes old requests and selects an isolated cache',
    () async {
      final app = session();
      await app.initialize();
      final old = app.sharing!.openList('weekly');
      await old.refresh();
      final entered = Completer<void>(), release = Completer<void>();
      repositories.single.beforeFetch = () async {
        entered.complete();
        await release.future;
      };
      final refreshing = old.refresh();
      await entered.future;
      auth.setUser(bob);
      await settle(app);
      final current = app.sharing!.openList('weekly');
      await current.refresh();
      release.complete();
      await refreshing;
      expect(old.canEdit, false);
      expect(current.canEdit, true);
      expect(app.sharing!.repository.accountId, 'bob');
      expect(caches.keys, containsAll(['alice/weekly', 'bob/weekly']));
      expect(caches['bob/weekly']!.value!.header.ownerId, 'bob');
    },
  );

  test('rapid return to the same account waits for the previous login’s device write', () async {
    final app = session();
    await app.initialize();
    final old = app.sharing!.openList('weekly');
    await old.refresh();
    final entered = Completer<void>(), release = Completer<void>();
    caches['alice/weekly']!.beforeWrite = () async {
      entered.complete();
      await release.future;
    };
    final edit = old.edit(basket(2), expectedGeneration: old.generation);
    final rejected = expectLater(edit, throwsA(isA<AccountProblem>()));
    await entered.future;
    auth.setUser(bob);
    auth.setUser(alice);
    await Future<void>.delayed(Duration.zero);
    expect(app.sharing, isNull);
    expect(app.isLoading, true);
    release.complete();
    await rejected;
    await settle(app);
    final current = app.sharing!.openList('weekly');
    await current.initialize();
    expect(current, isNot(same(old)));
    expect(current.content!.items.single.quantity, 2);
    expect(old.canEdit, false);
    expect(current.canEdit, true);
  });

  test('remote account deletion waits for shared writes before clearing device caches', () async {
    final app = session();
    await app.initialize();
    final controller = app.sharing!.openList('weekly');
    await controller.refresh();
    final entered = Completer<void>(), release = Completer<void>();
    final cache = caches['alice/weekly']!;
    cache.beforeWrite = () async {
      entered.complete();
      await release.future;
    };
    final editing = controller.edit(
      basket(2),
      expectedGeneration: controller.generation,
    );
    final rejected = expectLater(editing, throwsA(isA<AccountProblem>()));
    await entered.future;
    var cleared = false;
    privateCaches['alice']!.onClear = () async {
      cleared = true;
      await cache.clear();
    };
    final deleting = app.deleteAccount();
    await Future<void>.delayed(Duration.zero);
    expect(auth.deleted, ['alice']);
    expect(controller.canEdit, false);
    expect(cleared, false);
    release.complete();
    await rejected;
    await deleting;
    expect(cleared, true);
    expect(await cache.read(), isNull);
    expect(app.sharing, isNull);
    expect(app.user, isNull);
  });

  test(
    'failed remote deletion leaves household editing and cached work available',
    () async {
      final app = session();
      await app.initialize();
      final workspace = app.sharing!;
      final controller = workspace.openList('weekly');
      await controller.refresh();
      auth.failDelete = true;
      await expectLater(app.deleteAccount(), throwsA(isA<AccountProblem>()));
      expect(app.sharing, same(workspace));
      expect(controller.canEdit, true);
      expect(caches['alice/weekly']!.value, isNotNull);
    },
  );

  test('a late deletion result cannot sign out a different account', () async {
    final delayed = _DelayedDelete()..identity = alice;
    auth = delayed;
    final app = session();
    await app.initialize();
    final deleting = app.deleteAccount();
    await delayed.entered.future;
    auth.setUser(bob);
    await settle(app);
    final workspace = app.sharing!;
    delayed.release.complete();
    await deleting;
    expect(delayed.deleted, ['alice']);
    expect(app.user, bob);
    expect(auth.currentUser, bob);
    expect(app.sharing, same(workspace));
    expect(workspace.isActive, true);
  });
}
