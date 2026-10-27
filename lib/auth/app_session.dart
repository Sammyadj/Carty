import 'dart:async';

import 'package:flutter/widgets.dart';

import '../cloud/cloud_cart_storage.dart';
import '../cloud/cloud_workspace.dart';
import '../data/cart_storage.dart';
import '../state/cart_store.dart';
import 'account_gateway.dart';

typedef AccountCacheFactory = CartStorage Function(String ownerId);

class AppSession extends ChangeNotifier {
  AppSession({
    this.gateway,
    this.repository,
    CartStore? guestStore,
    AccountCacheFactory? cacheFactory,
    this.autoSync = true,
  }) : guest = guestStore ?? CartStore(storage: SharedPreferencesCartStorage()),
       _ownsGuest = guestStore == null,
       _cacheFactory =
           cacheFactory ??
           ((id) => SharedPreferencesCartStorage(
             storageKey: 'carty.account.$id.v1',
           ));

  final AccountGateway? gateway;
  final CloudWorkspaceRepository? repository;
  final CartStore guest;
  final bool _ownsGuest;
  final AccountCacheFactory _cacheFactory;
  final bool autoSync;
  final _accounts = <String, _Workspace>{};
  StreamSubscription<AccountIdentity?>? _auth;
  Future<void>? _initialization;
  AccountIdentity? _user;
  bool _loading = true;
  bool _disposed = false;
  int _generation = 0;
  String displayName = '';
  String? profileError;
  AccountIdentity? get user => _user;
  bool get isLoading => _loading;
  bool get cloudAvailable => gateway != null && repository != null;
  CartStore get store => _accounts[_user?.id]?.store ?? guest;
  CloudCartStorage? get cloud => _accounts[_user?.id]?.cloud;

  Future<void> initialize() => _initialization ??= () async {
    await guest.load();
    if (_disposed) return;
    _auth = gateway?.authChanges.listen(
      (user) {
        if (user?.id == gateway?.currentUser?.id) unawaited(_select(user));
      },
      onError: (Object _) {
        profileError = 'Your session needs attention. Please sign in again.';
        _notify();
      },
    );
    await _select(gateway?.currentUser);
  }();

  Future<void> _select(AccountIdentity? identity) async {
    if (_disposed) return;
    if (!_loading && identity?.id == _user?.id) return;
    final generation = ++_generation;
    _loading = true;
    _user = identity;
    displayName = '';
    profileError = null;
    _notify();
    if (identity == null) {
      _loading = false;
      _notify();
      return;
    }
    try {
      var workspace = _accounts[identity.id];
      if (workspace == null) {
        final cloud = CloudCartStorage(
          ownerId: identity.id,
          local: _cacheFactory(identity.id),
          repository: repository!,
          autoSync: autoSync,
          isCurrentSession: () =>
              !_disposed &&
              _user?.id == identity.id &&
              gateway?.currentUser?.id == identity.id,
        );
        final cart = CartStore(storage: cloud);
        cloud.onRemoteSnapshot = cart.restoreFromCloud;
        cloud.addListener(_notify);
        workspace = _Workspace(cart, cloud);
        _accounts[identity.id] = workspace;
      }
      await workspace.store.load();
      if (_disposed || generation != _generation) return;
      _loading = false;
      _notify();
      if (!workspace.store.needsStorageReset) unawaited(workspace.cloud.sync());
      try {
        final name = await gateway!.loadDisplayName(identity.id);
        if (!_disposed && generation == _generation) {
          displayName = name;
          _notify();
        }
      } catch (_) {
        if (!_disposed && generation == _generation) {
          profileError = 'Couldn’t load your profile. Your shopping data remains available.';
          _notify();
        }
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _loading = false;
        profileError = 'Couldn’t open your account data. Please retry.';
        _notify();
      }
    }
  }

  Future<void> saveProfile(String name) async {
    final identity = _user;
    if (identity == null) return;
    await gateway!.saveDisplayName(identity.id, name);
    if (_user?.id == identity.id) {
      displayName = name.trim();
      profileError = null;
      _notify();
    }
  }

  Future<void> signOut() async {
    if (!await store.waitForPendingSave()) {
      throw const AccountProblem(
        'Save your changes on this device before signing out.',
      );
    }
    await gateway?.signOut();
    await _select(null);
  }

  Future<void> deleteAccount() async {
    final id = _user?.id;
    if (id == null) return;
    await gateway!.deleteAccount();
    final workspace = _accounts.remove(id);
    workspace?.cloud.dispose();
    await workspace?.cloud.eraseLocalAccount();
    workspace?.store.dispose();
    try {
      await gateway!.signOut();
    } finally {
      await _select(null);
    }
  }

  Future<void> importGuestLists() async {
    if (_user == null || !guest.hasData) return;
    await store.importGuestLists(guest);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_auth?.cancel());
    for (final workspace in _accounts.values) {
      workspace.cloud.dispose();
      workspace.store.dispose();
    }
    if (_ownsGuest) guest.dispose();
    super.dispose();
  }
}

class _Workspace {
  const _Workspace(this.store, this.cloud);
  final CartStore store;
  final CloudCartStorage cloud;
}

class AccountScope extends InheritedNotifier<AppSession> {
  const AccountScope({
    super.key,
    required AppSession session,
    required super.child,
  }) : super(notifier: session);
  static AppSession? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.notifier;
}
