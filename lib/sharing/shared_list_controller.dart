import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../auth/account_gateway.dart';
import '../cloud/cloud_workspace.dart';
import 'shared_list.dart';
import 'shared_list_cache.dart';
import 'shared_repository.dart';

enum SharedSyncStatus {
  loading,
  ready,
  pending,
  syncing,
  offline,
  conflict,
  accessLost,
  storageError,
}

class SharedConflict {
  const SharedConflict(this.remote, this.local, this.generation);
  final SharedListDocument remote;
  final SharedContent local;
  final int generation;
}

/// Device commits are serial; network requests never hold the device-write
/// queue. Edits made during an upload remain pending against its accepted base.
class SharedListController extends ChangeNotifier {
  SharedListController({
    required this.listId,
    required this.repository,
    required this.cache,
    required this.isCurrentSession,
    this.autoSync = true,
  });
  final String listId;
  final SharedRepository repository;
  final SharedListCache cache;
  final bool Function() isCurrentSession;
  final bool autoSync;
  CachedSharedList? _state;
  SharedConflict? _conflict;
  SharedSyncStatus _status = SharedSyncStatus.loading;
  Future<void>? _initializing, _syncing;
  Future<void> _writes = Future.value();
  Timer? _timer;
  bool _disposed = false, _denied = false, _paused = false;
  SharedRole? _observedRole;
  int _generation = 0;
  CachedSharedList? get state => _state;
  SharedContent? get content => _state?.local;
  SharedConflict? get conflict => _conflict;
  SharedSyncStatus get status => _status;
  int get generation => _generation;
  bool get accessUnavailable => _denied;
  bool get _active => !_disposed && isCurrentSession();
  bool get canEdit =>
      _active &&
      !_paused &&
      !_denied &&
      _state != null &&
      (_observedRole ?? _state!.header.role).canEdit;

  void _requireActive() {
    if (!_active) {
      throw const AccountProblem('This account’s household list is closed.');
    }
  }

  void _statusChanged(SharedSyncStatus value) {
    if (!_active) return;
    _status = value;
    notifyListeners();
  }

  Future<T> _queue<T>(Future<T> Function() work) {
    final next = _writes.then((_) {
      _requireActive();
      return work();
    });
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> initialize() => _initializing ??= () async {
    try {
      final value = await cache.read();
      if (!_active) return;
      if (value != null) _validate(value);
      _state = value;
      _denied = value?.accessLost ?? false;
      _statusChanged(
        _denied
            ? SharedSyncStatus.accessLost
            : value?.hasPendingEdits == true
            ? SharedSyncStatus.pending
            : SharedSyncStatus.ready,
      );
    } catch (_) {
      _statusChanged(SharedSyncStatus.storageError);
      rethrow;
    }
  }();

  void _validate(CachedSharedList value) {
    CachedSharedList.decode(
      value.encode(repository.accountId),
      accountId: repository.accountId,
      listId: listId,
    );
  }

  Future<void> _persist(CachedSharedList value) async {
    _requireActive();
    _validate(value);
    try {
      await cache.write(value);
    } catch (_) {
      _statusChanged(SharedSyncStatus.storageError);
      rethrow;
    }
    _requireActive();
    _state = value;
    _generation++;
  }

  /// A form must pass the generation it displayed, preventing stale forms from
  /// replacing an edit or refresh which arrived while that form was open.
  Future<void> edit(
    SharedContent value, {
    required int expectedGeneration,
  }) async {
    await initialize();
    await _queue(() async {
      if (!canEdit) throw const SharedAccessProblem();
      if (expectedGeneration != _generation) {
        throw const AccountProblem(
          'The list changed. Review it before saving this edit.',
        );
      }
      final previous = _state!;
      await _persist(
        CachedSharedList(
          header: previous.header,
          base: previous.base,
          local: value,
          recovery: previous.recovery,
          accessLost: previous.accessLost,
          requiresReview: previous.requiresReview,
        ),
      );
      if (_conflict != null) {
        _conflict = SharedConflict(_conflict!.remote, value, _generation);
      }
      _statusChanged(
        _conflict != null
            ? SharedSyncStatus.conflict
            : _state!.hasPendingEdits
            ? SharedSyncStatus.pending
            : SharedSyncStatus.ready,
      );
    });
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (autoSync &&
        _active &&
        !_paused &&
        _status == SharedSyncStatus.pending) {
      _timer = Timer(
        const Duration(milliseconds: 900),
        () => unawaited(refresh()),
      );
    }
  }

  Future<void> refresh() => _startSync();

  /// Stop new edits/uploads and drain work already in flight before a leave or
  /// delete confirmation. A failed/cancelled action must call resumeSync.
  Future<CachedSharedList?> pauseForAccessChange() async {
    await initialize();
    _requireActive();
    _paused = true;
    _timer?.cancel();
    _statusChanged(_status);
    await _syncing;
    await _writes;
    _requireActive();
    return _state;
  }

  void resumeSync() {
    if (!_active) return;
    _paused = false;
    _statusChanged(_status);
    _schedule();
  }

  /// Server access ended; keep unsynced content as a read-only device copy.
  Future<void> retainWithoutAccess() async {
    await initialize();
    _requireActive();
    await _lostAccess();
  }

  Future<void> keepLocal(SharedConflict reviewed) {
    if (!identical(reviewed, _conflict) || reviewed.generation != _generation) {
      return Future.error(
        const AccountProblem(
          'The conflict review is out of date. Review both copies again.',
        ),
      );
    }
    return _startSync(reviewed: reviewed);
  }

  Future<void> _startSync({SharedConflict? reviewed}) {
    if (!_active || _paused) return Future.value();
    if (_syncing != null) return _syncing!;
    _timer?.cancel();
    return _syncing = _synchronize(reviewed).whenComplete(() {
      _syncing = null;
      _schedule();
    });
  }

  bool _same(SharedContent a, SharedContent b) =>
      canonicalSnapshot(jsonEncode(a.toArguments())) ==
      canonicalSnapshot(jsonEncode(b.toArguments()));

  CachedSharedList _withPermission(
    CachedSharedList value,
    SharedRole role, {
    bool lost = false,
    bool? requiresReview,
  }) => CachedSharedList(
    header: SharedListHeader.fromRow(value.header.toRow(), role),
    base: value.base,
    local: value.local,
    recovery: value.recovery,
    accessLost: lost,
    requiresReview: requiresReview ?? value.requiresReview,
  );

  void _observe(SharedListDocument remote) {
    _validate(CachedSharedList.accepted(remote));
    _observedRole = remote.header.role;
    _denied = false;
    // An older review must not remain usable if persisting a newly observed
    // permission or revision subsequently fails.
    _conflict = null;
  }

  Future<void> _lostAccess() => _queue(() async {
    _denied = true;
    _conflict = null;
    final current = _state;
    if (current != null) {
      await _persist(
        _withPermission(
          current,
          current.header.role,
          lost: true,
          requiresReview: current.requiresReview || current.hasPendingEdits,
        ),
      );
    }
    _statusChanged(SharedSyncStatus.accessLost);
  });

  Future<void> _showConflict(SharedListDocument remote) async {
    _observe(remote);
    await _queue(() async {
      final current = _state;
      if (current == null) return;
      await _persist(
        _withPermission(current, remote.header.role, requiresReview: true),
      );
      _conflict = SharedConflict(remote, _state!.local, _generation);
      _statusChanged(SharedSyncStatus.conflict);
    });
  }

  Future<void> _synchronize(SharedConflict? reviewed) async {
    try {
      await initialize();
      _requireActive();
      if (reviewed != null &&
          (!identical(reviewed, _conflict) ||
              reviewed.generation != _generation)) {
        throw const AccountProblem(
          'The conflict review is out of date. Review both copies again.',
        );
      }
      _statusChanged(SharedSyncStatus.syncing);
      final remote = await repository.fetch(listId);
      _requireActive();
      if (remote == null) {
        await _lostAccess();
        return;
      }
      _observe(remote);
      SharedContent? submission;
      await _queue(() async {
        final current = _state;
        if (reviewed != null &&
            (reviewed.generation != _generation ||
                reviewed.remote.header.revision != remote.header.revision)) {
          if (current != null) {
            await _persist(
              _withPermission(
                current,
                remote.header.role,
                requiresReview: true,
              ),
            );
            _conflict = SharedConflict(remote, _state!.local, _generation);
            _statusChanged(SharedSyncStatus.conflict);
          }
          return;
        }
        if (current == null ||
            !current.hasPendingEdits ||
            _same(current.local, remote.content)) {
          await _persist(
            CachedSharedList(
              header: remote.header,
              base: remote.content,
              local: remote.content,
              recovery: current?.recovery,
            ),
          );
          _conflict = null;
          _statusChanged(SharedSyncStatus.ready);
          return;
        }
        if (!remote.header.role.canEdit ||
            (reviewed == null &&
                (current.requiresReview ||
                    current.accessLost ||
                    current.header.role == SharedRole.viewer ||
                    !_same(current.base, remote.content)))) {
          await _persist(
            _withPermission(current, remote.header.role, requiresReview: true),
          );
          _conflict = SharedConflict(remote, _state!.local, _generation);
          _statusChanged(SharedSyncStatus.conflict);
          return;
        }
        // Persist a newly observed downgrade/upgrade before any later offline edit.
        await _persist(_withPermission(current, remote.header.role));
        submission = _state!.local;
      });
      if (submission == null) return;
      _requireActive();
      final receipt = await repository.save(
        listId,
        remote.header.revision,
        submission!,
      );
      _requireActive();
      if (receipt == null) {
        final latest = await repository.fetch(listId);
        _requireActive();
        if (latest == null) {
          await _lostAccess();
        } else {
          await _showConflict(latest);
        }
        return;
      }
      if (receipt.listId != listId ||
          receipt.revision != remote.header.revision + 1 ||
          !_same(receipt.content, submission!)) {
        throw const FormatException('Invalid household save receipt');
      }
      await _queue(() async {
        final current = _state!;
        final header = SharedListHeader.fromRow({
          ...remote.header.toRow(),
          'revision': receipt.revision,
          'name': receipt.content.name,
          'budget_pence': receipt.content.budgetPence,
          'is_planning': receipt.content.isPlanning,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, remote.header.role);
        await _persist(
          CachedSharedList(
            header: header,
            base: receipt.content,
            local: current.local,
            recovery: current.recovery,
          ),
        );
        _conflict = null;
        _statusChanged(
          _state!.hasPendingEdits
              ? SharedSyncStatus.pending
              : SharedSyncStatus.ready,
        );
      });
    } on SharedAccessProblem {
      if (_active) {
        try {
          await _lostAccess();
        } catch (_) {
          _statusChanged(SharedSyncStatus.storageError);
        }
      }
    } catch (_) {
      if (_status != SharedSyncStatus.storageError) {
        _statusChanged(SharedSyncStatus.offline);
      }
    }
  }

  Future<void> useRemote(SharedConflict reviewed) => _queue(() async {
    if (_paused) {
      throw const AccountProblem(
        'Finish the household access action before reviewing changes.',
      );
    }
    if (!identical(reviewed, _conflict) || reviewed.generation != _generation) {
      throw const AccountProblem(
        'The conflict review is out of date. Review both copies again.',
      );
    }
    await _persist(
      CachedSharedList(
        header: reviewed.remote.header,
        base: reviewed.remote.content,
        local: reviewed.remote.content,
        recovery: _state!.local,
      ),
    );
    _conflict = null;
    _statusChanged(SharedSyncStatus.ready);
  });

  /// Dispose immediately blocks callbacks/queued edits. Account deletion must
  /// additionally await this barrier before erasing the account's SQLite scopes.
  Future<void> get writesSettled => _writes;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
