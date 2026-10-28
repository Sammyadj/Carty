import 'dart:async';

import 'package:carty_app/auth/account_gateway.dart';
import 'package:carty_app/cloud/cloud_workspace.dart';
import 'package:carty_app/data/cart_storage.dart';
import 'package:carty_app/state/cart_store.dart';

class FakeCloudRepository implements CloudWorkspaceRepository {
  final rows = <String, CloudWorkspace>{};
  final saves = <String>[];
  bool offline = false;
  Future<CloudWorkspace?> Function(String)? onFetch;
  Future<CloudWorkspace?> Function(String, int, String)? onSave;
  @override
  Future<CloudWorkspace?> fetch(String ownerId) async {
    if (offline) throw StateError('Offline');
    return onFetch == null ? rows[ownerId] : onFetch!(ownerId);
  }

  @override
  Future<CloudWorkspace?> save(
    String ownerId,
    int revision,
    String snapshot,
  ) async {
    if (offline) throw StateError('Offline');
    saves.add(snapshot);
    return onSave == null
        ? saveImmediately(ownerId, revision, snapshot)
        : onSave!(ownerId, revision, snapshot);
  }

  CloudWorkspace? saveImmediately(
    String ownerId,
    int revision,
    String snapshot,
  ) {
    if ((rows[ownerId]?.revision ?? 0) != revision) return null;
    return rows[ownerId] = CloudWorkspace(
      ownerId: ownerId,
      revision: revision + 1,
      snapshot: canonicalSnapshot(snapshot),
    );
  }

  void externalEdit(String ownerId, String snapshot) {
    rows[ownerId] = CloudWorkspace(
      ownerId: ownerId,
      revision: (rows[ownerId]?.revision ?? 0) + 1,
      snapshot: canonicalSnapshot(snapshot),
    );
  }
}

class FakeAccountGateway implements AccountGateway {
  AccountIdentity? identity;
  final events = StreamController<AccountIdentity?>.broadcast(sync: true);
  final names = <String, String>{};
  final requestedEmails = <String>[];
  final deleted = <String>[];
  bool failAuth = false;
  bool failDelete = false;
  @override
  AccountIdentity? get currentUser => identity;
  @override
  Stream<AccountIdentity?> get authChanges => events.stream;
  void setUser(AccountIdentity? user) {
    identity = user;
    events.add(user);
  }

  @override
  Future<void> sendSignInLink(String email) async {
    if (failAuth) {
      throw const AccountProblem('Couldn’t send the code. Try again.');
    }
    requestedEmails.add(email);
  }

  @override
  Future<String> loadDisplayName(String id) async => names[id] ?? '';
  @override
  Future<void> saveDisplayName(String id, String name) async {
    names[id] = name;
  }

  @override
  Future<void> signOut() async => setUser(null);
  @override
  Future<void> deleteAccount() async {
    if (failDelete) throw const AccountProblem('Couldn’t delete the account.');
    deleted.add(identity!.id);
  }

  Future<void> dispose() => events.close();
}

Future<String> exampleSnapshot(String name, {int quantity = 1}) async {
  final store = CartStore(storage: InMemoryCartStorage());
  await store.addItem(name: name, unitPricePence: 125, quantity: quantity);
  await store.setBudget(5000);
  await store.saveList('$name list');
  final result = store.exportSnapshot();
  store.dispose();
  return result;
}
