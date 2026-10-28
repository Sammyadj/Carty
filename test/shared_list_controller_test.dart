import 'dart:async';
import 'dart:io';

import 'package:carty_app/auth/account_gateway.dart';
import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/sharing/shared_list.dart';
import 'package:carty_app/sharing/shared_list_cache.dart';
import 'package:carty_app/sharing/shared_list_controller.dart';
import 'package:carty_app/sharing/shared_repository.dart';
import 'package:flutter_test/flutter_test.dart';

SharedContent basket(int quantity, {String name = 'Weekly shop'}) =>
    SharedContent(
      name: name,
      budgetPence: 5000,
      isPlanning: false,
      items: [
        CartItem(
          id: 'milk',
          name: 'Milk',
          unitPricePence: 175,
          quantity: quantity,
          plannedQuantity: 4,
          estimatedUnitPricePence: 150,
          priceConfirmed: true,
        ),
      ],
    );

class _Server {
  SharedContent content = basket(1);
  int revision = 1, saves = 0;
  bool offline = false, removed = false, denySave = false;
  final roles = {'alice': SharedRole.owner, 'bob': SharedRole.editor};
  Future<void> Function()? beforeSave, beforeFetch;
  void change(int quantity) {
    content = basket(quantity);
    revision++;
  }

  SharedListDocument? document(String user) => removed || roles[user] == null
      ? null
      : SharedListDocument(
          SharedListHeader(
            id: 'weekly',
            ownerId: 'alice',
            name: content.name,
            budgetPence: content.budgetPence,
            isPlanning: content.isPlanning,
            revision: revision,
            updatedAt: DateTime.utc(2026, 10, 28, revision),
            role: roles[user]!,
          ),
          content.items,
        );
}

class _Repository implements SharedRepository {
  _Repository(this.server, this.accountId);
  final _Server server;
  @override
  final String accountId;
  @override
  Future<SharedListDocument?> fetch(String id) async {
    await server.beforeFetch?.call();
    if (server.offline) throw const SocketException('offline');
    return server.document(accountId);
  }

  @override
  Future<SharedSaveReceipt?> save(
    String id,
    int revision,
    SharedContent content,
  ) async {
    server.saves++;
    await server.beforeSave?.call();
    if (server.offline) throw const SocketException('offline');
    if (server.denySave || server.roles[accountId]?.canEdit != true) {
      throw const SharedAccessProblem();
    }
    if (revision != server.revision) return null;
    server.content = content;
    server.revision++;
    return SharedSaveReceipt(id, server.revision, content);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cache implements SharedListCache {
  _Cache(this.accountId);
  final String accountId;
  String? encoded;
  bool fail = false;
  Future<void> Function()? beforeWrite;
  @override
  Future<CachedSharedList?> read() async => encoded == null
      ? null
      : CachedSharedList.decode(
          encoded!,
          accountId: accountId,
          listId: 'weekly',
        );
  @override
  Future<void> write(CachedSharedList value) async {
    await beforeWrite?.call();
    if (fail) throw FileSystemException('disk full');
    encoded = value.encode(accountId);
  }

  @override
  Future<void> clear() async {
    encoded = null;
  }
}

void main() {
  late _Server server;
  setUp(() => server = _Server());
  SharedListController controller({
    String user = 'alice',
    _Cache? cache,
    bool Function()? current,
  }) {
    final value = SharedListController(
      listId: 'weekly',
      repository: _Repository(server, user),
      cache: cache ?? _Cache(user),
      isCurrentSession: current ?? () => true,
      autoSync: false,
    );
    addTearDown(value.dispose);
    return value;
  }

  Future<void> edit(SharedListController value, int quantity) =>
      value.edit(basket(quantity), expectedGeneration: value.generation);

  test(
    'a failed permission-cache update invalidates an older conflict review',
    () async {
      final cache = _Cache('bob');
      final value = controller(user: 'bob', cache: cache);
      await value.refresh();
      await edit(value, 2);
      server.change(3);
      await value.refresh();
      final oldReview = value.conflict!;
      server.roles['bob'] = SharedRole.viewer;
      cache.fail = true;
      await value.refresh();
      expect(value.status, SharedSyncStatus.storageError);
      expect(value.canEdit, false);
      expect(value.conflict, isNull);
      cache.fail = false;
      await expectLater(
        value.useRemote(oldReview),
        throwsA(isA<AccountProblem>()),
      );
      expect(value.content!.items.single.quantity, 2);
    },
  );

  test('corrupt device data is preserved and never replaced by an automatic download', () async {
    final cache = _Cache('alice')..encoded = 'broken cache';
    var fetched = false;
    server.beforeFetch = () async {
      fetched = true;
    };
    final value = controller(cache: cache);
    await value.refresh();
    expect(value.status, SharedSyncStatus.storageError);
    expect(cache.encoded, 'broken cache');
    expect(fetched, false);
    expect(value.canEdit, false);
  });

  testWidgets(
    'automatic sync runs after a device edit and stops after disposal',
    (tester) async {
      final value = SharedListController(
        listId: 'weekly',
        repository: _Repository(server, 'alice'),
        cache: _Cache('alice'),
        isCurrentSession: () => true,
      );
      addTearDown(value.dispose);
      await value.refresh();
      await edit(value, 2);
      expect(server.saves, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(server.saves, 1);
      expect(value.status, SharedSyncStatus.ready);
      await edit(value, 3);
      value.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(server.saves, 1);
    },
  );

  test(
    'offline edits survive restart and upload after checking the server base',
    () async {
      final cache = _Cache('alice');
      final first = controller(cache: cache);
      await first.refresh();
      server.offline = true;
      await edit(first, 2);
      await first.refresh();
      expect(first.status, SharedSyncStatus.offline);
      first.dispose();
      await first.writesSettled;
      final restarted = controller(cache: cache);
      await restarted.initialize();
      expect(restarted.content!.items.single.quantity, 2);
      expect(restarted.state!.base.items.single.quantity, 1);
      server.offline = false;
      await restarted.refresh();
      expect(server.content.items.single.quantity, 2);
      expect(restarted.status, SharedSyncStatus.ready);
      expect(restarted.state!.hasPendingEdits, false);
      expect(restarted.content!.items.single.plannedQuantity, 4);
    },
  );

  test('two shoppers get a reviewable conflict and remote choice retains local recovery', () async {
    final alice = controller();
    final bob = controller(user: 'bob');
    await alice.refresh();
    await bob.refresh();
    await edit(alice, 2);
    await edit(bob, 3);
    await alice.refresh();
    await bob.refresh();
    expect(bob.status, SharedSyncStatus.conflict);
    expect(server.saves, 1);
    expect(bob.conflict!.remote.content.items.single.quantity, 2);
    expect(bob.conflict!.local.items.single.quantity, 3);
    await bob.useRemote(bob.conflict!);
    expect(bob.content!.items.single.quantity, 2);
    expect(bob.state!.recovery!.items.single.quantity, 3);
    expect(server.content.items.single.quantity, 2);
  });

  test('keep-local uses the reviewed revision and never overwrites a newer unseen edit', () async {
    final bob = controller(user: 'bob');
    await bob.refresh();
    await edit(bob, 3);
    server.change(2);
    await bob.refresh();
    final review = bob.conflict!;
    server.change(4);
    await bob.keepLocal(review);
    expect(server.saves, 0);
    expect(bob.conflict!.remote.content.items.single.quantity, 4);
    await bob.keepLocal(bob.conflict!);
    expect(server.content.items.single.quantity, 3);
    expect(bob.status, SharedSyncStatus.ready);
  });

  test(
    'local form and conflict reviews cannot replace newer local edits',
    () async {
      final value = controller();
      await value.refresh();
      final formGeneration = value.generation;
      await edit(value, 2);
      await expectLater(
        value.edit(basket(8), expectedGeneration: formGeneration),
        throwsA(isA<AccountProblem>()),
      );
      server.change(3);
      await value.refresh();
      final review = value.conflict!;
      await edit(value, 4);
      await expectLater(
        value.useRemote(review),
        throwsA(isA<AccountProblem>()),
      );
      await expectLater(
        value.keepLocal(review),
        throwsA(isA<AccountProblem>()),
      );
      expect(value.content!.items.single.quantity, 4);
    },
  );

  test('a new local edit during upload stays pending against the acknowledged submission', () async {
    final value = controller();
    await value.refresh();
    await edit(value, 2);
    final entered = Completer<void>(), release = Completer<void>();
    server.beforeSave = () async {
      entered.complete();
      await release.future;
    };
    final syncing = value.refresh();
    await entered.future;
    await edit(value, 3);
    release.complete();
    await syncing;
    expect(server.content.items.single.quantity, 2);
    expect(value.content!.items.single.quantity, 3);
    expect(value.state!.base.items.single.quantity, 2);
    expect(value.status, SharedSyncStatus.pending);
    server.beforeSave = null;
    await value.refresh();
    expect(server.content.items.single.quantity, 3);
  });

  test('a viewer cannot edit and a downgraded editor retains pending work for review', () async {
    final cache = _Cache('bob');
    final value = controller(user: 'bob', cache: cache);
    await value.refresh();
    await edit(value, 2);
    server.roles['bob'] = SharedRole.viewer;
    await value.refresh();
    expect(value.canEdit, false);
    expect(value.status, SharedSyncStatus.conflict);
    expect(server.saves, 0);
    await expectLater(edit(value, 3), throwsA(isA<SharedAccessProblem>()));
    await value.keepLocal(value.conflict!);
    expect(server.saves, 0);
    final restarted = controller(user: 'bob', cache: cache);
    await restarted.initialize();
    expect(restarted.canEdit, false);
    expect(restarted.content!.items.single.quantity, 2);
  });

  test('revocation persists read-only access loss and pending edits across restart', () async {
    final cache = _Cache('bob');
    final value = controller(user: 'bob', cache: cache);
    await value.refresh();
    await edit(value, 2);
    server.roles.remove('bob');
    await value.refresh();
    expect(value.status, SharedSyncStatus.accessLost);
    expect(value.canEdit, false);
    expect(value.content!.items.single.quantity, 2);
    final restarted = controller(user: 'bob', cache: cache);
    await restarted.initialize();
    expect(restarted.status, SharedSyncStatus.accessLost);
    expect(restarted.canEdit, false);
    expect(server.saves, 0);
  });

  test(
    'permission denial after fetch does not discard unsynced changes',
    () async {
      final value = controller(user: 'bob');
      await value.refresh();
      await edit(value, 2);
      server.denySave = true;
      await value.refresh();
      expect(value.status, SharedSyncStatus.accessLost);
      expect(value.content!.items.single.quantity, 2);
      expect(value.state!.base.items.single.quantity, 1);
    },
  );

  test('a last-moment CAS failure fetches the competing version without retrying a write', () async {
    final value = controller();
    await value.refresh();
    await edit(value, 2);
    server.beforeSave = () async => server.change(3);
    await value.refresh();
    expect(value.status, SharedSyncStatus.conflict);
    expect(server.saves, 1);
    expect(value.conflict!.remote.content.items.single.quantity, 3);
  });

  test(
    'failed device write cannot publish the new edit or upload it',
    () async {
      final cache = _Cache('alice');
      final value = controller(cache: cache);
      await value.refresh();
      cache.fail = true;
      await expectLater(edit(value, 2), throwsA(isA<FileSystemException>()));
      expect(value.content!.items.single.quantity, 1);
      expect(value.status, SharedSyncStatus.storageError);
      expect(server.saves, 0);
    },
  );

  test('account switch and disposal ignore late fetches and drain writes before erasure', () async {
    var current = true;
    final cache = _Cache('alice');
    final value = controller(cache: cache, current: () => current);
    await value.refresh();
    final entered = Completer<void>(), release = Completer<void>();
    server.beforeFetch = () async {
      entered.complete();
      await release.future;
    };
    final refreshing = value.refresh();
    await entered.future;
    current = false;
    server.change(8);
    release.complete();
    await refreshing;
    expect(value.content!.items.single.quantity, 1);
    expect(value.canEdit, false);
    current = true;
    server.beforeFetch = null;
    final writeEntered = Completer<void>(), writeRelease = Completer<void>();
    cache.beforeWrite = () async {
      writeEntered.complete();
      await writeRelease.future;
    };
    final editing = edit(value, 2);
    final failedEdit = expectLater(editing, throwsA(isA<AccountProblem>()));
    await writeEntered.future;
    value.dispose();
    var settled = false;
    final barrier = value.writesSettled.then((_) => settled = true);
    await Future<void>.delayed(Duration.zero);
    expect(settled, false);
    writeRelease.complete();
    await failedEdit;
    await barrier;
    await cache.clear();
    expect(await cache.read(), isNull);
    expect(value.content!.items.single.quantity, 1);
  });
}
