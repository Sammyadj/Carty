import '../auth/account_gateway.dart';
import 'shared_list_cache.dart';
import 'shared_list_controller.dart';
import 'shared_repository.dart';

typedef SharedCacheFactory = SharedListCache Function(
  String accountId,
  String listId,
);
typedef SharedRepositoryFactory = SharedRepository Function(String accountId);
typedef SharedCacheIndex = Future<List<String>> Function(String accountId);

class SharedCacheCatalog {
  SharedCacheCatalog(
    Iterable<CachedSharedList> copies,
    Iterable<String> unreadable,
  ) : copies = List.unmodifiable(copies),
      unreadableListIds = List.unmodifiable(unreadable);
  final List<CachedSharedList> copies;
  final List<String> unreadableListIds;
}

/// One login lifetime owns its household controllers. Re-entering the same
/// account creates a fresh lifetime after old device writes have drained.
class SharedWorkspace {
  SharedWorkspace({
    required this.repository,
    required this.isCurrentSession,
    SharedCacheFactory? cacheFactory,
    SharedCacheIndex? cacheIndex,
    this.autoSync = true,
  }) : _cacheIndex = cacheIndex ?? SqliteSharedListCache.listIds,
       _cacheFactory =
           cacheFactory ??
           ((account, list) =>
               SqliteSharedListCache(accountId: account, listId: list));
  final SharedRepository repository;
  final bool Function() isCurrentSession;
  final SharedCacheFactory _cacheFactory;
  final SharedCacheIndex _cacheIndex;
  final bool autoSync;
  final _controllers = <String, SharedListController>{};
  bool _closed = false;
  bool get isActive => !_closed && isCurrentSession();

  void _requireActive() {
    if (!isActive) {
      throw const AccountProblem(
        'Sign in again before opening household lists.',
      );
    }
  }

  Future<SharedCacheCatalog> inspectDeviceCopies() async {
    _requireActive();
    final ids = await _cacheIndex(repository.accountId);
    _requireActive();
    final result = <CachedSharedList>[];
    final unreadable = <String>[];
    for (final id in ids.toSet()) {
      try {
        final cached = await _cacheFactory(repository.accountId, id).read();
        if (cached != null) {
          CachedSharedList.decode(
            cached.encode(repository.accountId),
            accountId: repository.accountId,
            listId: id,
          );
          result.add(cached);
        }
      } catch (_) {
        unreadable.add(id);
      }
      _requireActive();
    }
    return SharedCacheCatalog(result, unreadable);
  }

  SharedListController openList(String listId) {
    if (!isActive) {
      throw const AccountProblem(
        'Sign in again before opening this household list.',
      );
    }
    return _controllers.putIfAbsent(
      listId,
      () => SharedListController(
        listId: listId,
        repository: repository,
        cache: _cacheFactory(repository.accountId, listId),
        isCurrentSession: () => isActive,
        autoSync: autoSync,
      ),
    );
  }

  Future<void> refreshOpenLists() async {
    if (!isActive) return;
    await Future.wait(
      _controllers.values.toList().map((controller) => controller.refresh()),
    );
  }

  Future<void> get writesSettled => Future.wait(
    _controllers.values.map((controller) => controller.writesSettled),
  ).then((_) {});

  void dispose() {
    if (_closed) return;
    _closed = true;
    for (final controller in _controllers.values) {
      controller.dispose();
    }
  }
}
