import 'dart:async';
import 'dart:convert';

import 'package:carty_app/cloud/cloud_cart_storage.dart';
import 'package:carty_app/cloud/cloud_workspace.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cloud_test_support.dart';

CloudCartStorage _storage(
  FakeCloudRepository repo, {
  CartStorage? local,
  bool Function()? current,
}) {
  final storage = CloudCartStorage(
    ownerId: 'alice',
    local: local ?? InMemoryCartStorage(),
    repository: repo,
    isCurrentSession: current ?? () => true,
    autoSync: false,
  );
  addTearDown(storage.dispose);
  return storage;
}

void main() {
  test('device edits remain durable while the cloud is offline', () async {
    final repo = FakeCloudRepository()..offline = true;
    final local = InMemoryCartStorage();
    final storage = _storage(repo, local: local);
    final snapshot = await exampleSnapshot('Milk');
    await storage.write(snapshot);
    expect(storage.status, CloudSyncStatus.pending);
    expect(repo.saves, isEmpty);
    await storage.sync();
    expect(storage.status, CloudSyncStatus.error);
    final reopened = _storage(repo, local: local);
    expect(await reopened.read(), canonicalSnapshot(snapshot));
  });

  test('an empty device restores the private cloud workspace', () async {
    final repo = FakeCloudRepository();
    final remote = await exampleSnapshot('Bread');
    repo.externalEdit('alice', remote);
    final storage = _storage(repo);
    String? applied;
    storage.onRemoteSnapshot = (value) => applied = value;
    await storage.sync();
    expect(applied, canonicalSnapshot(remote));
    expect(await storage.read(), canonicalSnapshot(remote));
    expect(storage.status, CloudSyncStatus.synced);
    expect(repo.saves, isEmpty);
  });

  test(
    'newer edits survive a slow upload and sync against its returned revision',
    () async {
      final repo = FakeCloudRepository();
      final storage = _storage(repo);
      final first = await exampleSnapshot('Milk');
      final second = await exampleSnapshot('Milk and bread');
      final entered = Completer<void>();
      final release = Completer<void>();
      repo.onSave = (id, revision, snapshot) async {
        entered.complete();
        await release.future;
        return repo.saveImmediately(id, revision, snapshot);
      };
      await storage.write(first);
      final sync = storage.sync();
      await entered.future;
      await storage.write(second);
      release.complete();
      await sync;
      expect(await storage.read(), canonicalSnapshot(second));
      expect(storage.status, CloudSyncStatus.pending);
      expect(repo.rows['alice']!.snapshot, canonicalSnapshot(first));
      repo.onSave = null;
      await storage.sync();
      expect(repo.rows['alice']!.revision, 2);
      expect(repo.rows['alice']!.snapshot, canonicalSnapshot(second));
      expect(storage.status, CloudSyncStatus.synced);
    },
  );

  test(
    'a slow fetch cannot replace edits made while it was in flight',
    () async {
      final repo = FakeCloudRepository();
      final storage = _storage(repo);
      final remote = await exampleSnapshot('Remote bread');
      final device = await exampleSnapshot('Local milk');
      final entered = Completer<void>();
      final release = Completer<CloudWorkspace?>();
      repo.onFetch = (_) {
        entered.complete();
        return release.future;
      };
      var applied = false;
      storage.onRemoteSnapshot = (_) => applied = true;
      final sync = storage.sync();
      await entered.future;
      await storage.write(device);
      release.complete(
        CloudWorkspace(ownerId: 'alice', revision: 1, snapshot: remote),
      );
      await sync;
      expect(await storage.read(), canonicalSnapshot(device));
      expect(applied, isFalse);
      expect(repo.saves, isEmpty);
    },
  );

  test(
    'conflicting devices keep a recovery copy when selecting cloud data',
    () async {
      final repo = FakeCloudRepository();
      final storage = _storage(repo);
      final base = await exampleSnapshot('Original');
      final device = await exampleSnapshot('Device edits');
      final remote = await exampleSnapshot('Cloud edits');
      await storage.write(base);
      await storage.sync();
      await storage.write(device);
      repo.externalEdit('alice', remote);
      await storage.sync();
      expect(storage.status, CloudSyncStatus.conflict);
      expect(await storage.read(), canonicalSnapshot(device));
      expect(await storage.resolveConflict(useCloud: true), isTrue);
      expect(await storage.read(), canonicalSnapshot(remote));
      expect(storage.recoverySnapshot, canonicalSnapshot(device));
      await storage.restoreRecoveryCopy();
      expect(await storage.read(), canonicalSnapshot(device));
      await storage.sync();
      expect(repo.rows['alice']!.snapshot, canonicalSnapshot(device));
      expect(storage.recoverySnapshot, canonicalSnapshot(remote));
    },
  );

  test(
    'keeping the device copy backs up the other version before replacement',
    () async {
      final repo = FakeCloudRepository();
      final storage = _storage(repo);
      final base = await exampleSnapshot('Original');
      final device = await exampleSnapshot('Device');
      final remote = await exampleSnapshot('Cloud');
      await storage.write(base);
      await storage.sync();
      await storage.write(device);
      repo.externalEdit('alice', remote);
      await storage.sync();
      expect(await storage.resolveConflict(useCloud: false), isTrue);
      expect(storage.recoverySnapshot, canonicalSnapshot(remote));
      expect(repo.rows['alice']!.snapshot, canonicalSnapshot(device));
      expect(repo.rows['alice']!.revision, 3);
      expect(storage.status, CloudSyncStatus.synced);
    },
  );

  test('a second cloud change requires another conflict decision', () async {
    final repo = FakeCloudRepository();
    final storage = _storage(repo);
    await storage.write(await exampleSnapshot('Original'));
    await storage.sync();
    final device = await exampleSnapshot('Device');
    await storage.write(device);
    repo.externalEdit('alice', await exampleSnapshot('Cloud A'));
    await storage.sync();
    final newest = await exampleSnapshot('Cloud B');
    repo.externalEdit('alice', newest);
    expect(await storage.resolveConflict(useCloud: false), isFalse);
    expect(repo.rows['alice']!.snapshot, canonicalSnapshot(newest));
    expect(await storage.read(), canonicalSnapshot(device));
    expect(storage.status, CloudSyncStatus.conflict);
    expect(storage.conflict!.revision, 3);
  });

  test(
    'foreign and malformed cloud responses never replace local data',
    () async {
      for (final record in [
        CloudWorkspace(
          ownerId: 'bob',
          revision: 1,
          snapshot: await exampleSnapshot('Bob'),
        ),
        const CloudWorkspace(
          ownerId: 'alice',
          revision: 1,
          snapshot: '{broken',
        ),
      ]) {
        final repo = FakeCloudRepository()..onFetch = (_) async => record;
        final local = await exampleSnapshot('Alice');
        final storage = _storage(repo);
        await storage.write(local);
        await storage.sync();
        expect(storage.status, CloudSyncStatus.error);
        expect(await storage.read(), canonicalSnapshot(local));
        expect(repo.saves, isEmpty);
      }
    },
  );

  test(
    'account changes stop an old response from being cached or applied',
    () async {
      final repo = FakeCloudRepository();
      final entered = Completer<void>();
      final release = Completer<CloudWorkspace?>();
      var current = true;
      repo.onFetch = (_) {
        entered.complete();
        return release.future;
      };
      final local = InMemoryCartStorage();
      final storage = _storage(repo, local: local, current: () => current);
      var applied = false;
      storage.onRemoteSnapshot = (_) => applied = true;
      final sync = storage.sync();
      await entered.future;
      current = false;
      release.complete(
        CloudWorkspace(
          ownerId: 'alice',
          revision: 1,
          snapshot: await exampleSnapshot('Private Alice'),
        ),
      );
      await sync;
      expect(local.value, isNull);
      expect(applied, isFalse);
      expect(repo.saves, isEmpty);
    },
  );

  test('failed device writes cannot upload unpersisted data', () async {
    final local = _FailingStorage();
    final repo = FakeCloudRepository();
    final storage = _storage(repo, local: local);
    final snapshot = await exampleSnapshot('Milk');
    await expectLater(storage.write(snapshot), throwsStateError);
    await storage.sync();
    expect(repo.saves, isEmpty);
    local.fail = false;
    await storage.write(snapshot);
    await storage.sync();
    expect(repo.rows['alice']!.snapshot, canonicalSnapshot(snapshot));
  });

  test('JSONB key reordering does not create a false conflict', () async {
    final repo = FakeCloudRepository();
    final storage = _storage(repo);
    final snapshot = await exampleSnapshot('Milk');
    await storage.write(snapshot);
    await storage.sync();
    final data = jsonDecode(snapshot) as Map<String, dynamic>;
    final reversed = jsonEncode(
      Map.fromEntries(data.entries.toList().reversed),
    );
    repo.externalEdit('alice', reversed);
    await storage.sync();
    expect(storage.status, CloudSyncStatus.synced);
    expect(repo.saves, hasLength(1));
  });

  test(
    'corrupt or foreign account caches are preserved until explicit reset',
    () async {
      final repo = FakeCloudRepository();
      final local = InMemoryCartStorage()
        ..value = jsonEncode({'version': 1, 'ownerId': 'bob', 'revision': 0});
      final original = local.value;
      final storage = _storage(repo, local: local);
      await expectLater(storage.read(), throwsFormatException);
      await storage.sync();
      expect(local.value, original);
      expect(repo.saves, isEmpty);
      // CartStore's explicit reset is the only path to write after a corrupt read.
      final snapshot = await exampleSnapshot('Reset milk');
      await storage.write(snapshot);
      expect(await storage.read(), canonicalSnapshot(snapshot));
    },
  );
}

class _FailingStorage extends InMemoryCartStorage {
  bool fail = true;
  @override
  Future<void> write(String value) async {
    if (fail) {
      throw StateError('Disk unavailable');
    }
    await super.write(value);
  }
}
