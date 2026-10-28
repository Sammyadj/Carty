import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/cart_storage.dart';
import '../state/cart_store.dart';
import 'cloud_workspace.dart';

enum CloudSyncStatus { idle, syncing, synced, pending, conflict, error }

/// Device writes finish before cloud work begins. The payload and its last
/// accepted cloud revision live in one account-scoped local envelope.
class CloudCartStorage extends ChangeNotifier
    implements CartStorage, RecoverableCartStorage {
  CloudCartStorage({
    required this.ownerId,
    required this.local,
    required this.repository,
    required this.isCurrentSession,
    this.autoSync = true,
  });

  final String ownerId;
  final CartStorage local;
  final CloudWorkspaceRepository repository;
  final bool Function() isCurrentSession;
  final bool autoSync;
  void Function(String snapshot)? onRemoteSnapshot;
  CloudSyncStatus status = CloudSyncStatus.idle;
  CloudWorkspace? conflict;
  String? _payload;
  String? _base;
  String? _backup;
  int _revision = 0;
  int _generation = 0;
  bool _disposed = false;
  bool _localFailed = false;
  Future<void>? _load;
  Future<void>? _operation;
  Future<void> _localTail = Future.value();
  Timer? _timer;
  String? get recoverySnapshot => _backup;
  @override
  Future<String?> readPreviousSnapshot() async {
    await _initialize();
    await _localTail;
    if (!_active || local is! RecoverableCartStorage) return null;
    return (local as RecoverableCartStorage).readPreviousSnapshot();
  }

  bool get _active => !_disposed && isCurrentSession();

  Future<void> _initialize() => _load ??= () async {
    final raw = await local.read();
    if (raw == null) return;
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic> ||
        json['version'] != 1 ||
        json['ownerId'] != ownerId ||
        json['revision'] is! int ||
        json['revision'] < 0) {
      throw const FormatException('Invalid account cache');
    }
    for (final key in ['payload', 'base', 'backup']) {
      final value = json[key];
      if (value != null &&
          (value is! String || !CartStore.isValidSnapshot(value))) {
        throw const FormatException('Invalid account snapshot');
      }
    }
    _payload = json['payload'] as String?;
    _base = json['base'] as String?;
    _backup = json['backup'] as String?;
    _revision = json['revision'] as int;
    if (_revision > 0 && _base == null) {
      throw const FormatException('Missing sync base');
    }
    status = _payload != _base ? CloudSyncStatus.pending : CloudSyncStatus.idle;
  }();

  @override
  Future<String?> read() async {
    await _initialize();
    return _payload;
  }

  Future<void> _persist() {
    final envelope = jsonEncode({
      'version': 1,
      'ownerId': ownerId,
      'payload': _payload,
      'base': _base,
      'revision': _revision,
      'backup': _backup,
    });
    final write = _localTail.then((_) => local.write(envelope));
    _localTail = write.catchError((Object _) {});
    return write;
  }

  @override
  Future<void> write(String snapshot) async {
    if (!CartStore.isValidSnapshot(snapshot)) {
      throw const FormatException('Invalid cart snapshot');
    }
    try {
      await _initialize();
    } catch (_) {
      // CartStore blocks ordinary writes after a corrupt read. Reaching write
      // here means the shopper explicitly confirmed Reset saved data.
      _load = Future.value();
      _base = null;
      _revision = 0;
      _backup = null;
    }
    if (_disposed) throw StateError('Account storage is closed');
    _payload = canonicalSnapshot(snapshot);
    _generation++;
    try {
      await _persist();
      _localFailed = false;
    } catch (_) {
      _localFailed = true;
      _setStatus(CloudSyncStatus.error);
      rethrow;
    }
    _setStatus(
      conflict == null ? CloudSyncStatus.pending : CloudSyncStatus.conflict,
    );
    _schedule();
  }

  void _schedule([Duration delay = const Duration(milliseconds: 900)]) {
    _timer?.cancel();
    if (autoSync && _active) _timer = Timer(delay, () => unawaited(sync()));
  }

  Future<void> sync() {
    if (!_active) return Future.value();
    return _operation ??= _synchronize().whenComplete(() {
      _operation = null;
    });
  }

  void _validate(CloudWorkspace workspace) {
    if (workspace.ownerId != ownerId ||
        workspace.revision < 1 ||
        !CartStore.isValidSnapshot(workspace.snapshot)) {
      throw const FormatException('Invalid cloud workspace');
    }
  }

  Future<void> _accept(CloudWorkspace remote, int generation) async {
    _validate(remote);
    if (!_active) return;
    final payload = canonicalSnapshot(remote.snapshot);
    _base = payload;
    _revision = remote.revision;
    conflict = null;
    if (generation == _generation) _payload = payload;
    await _persist();
    if (!_active) return;
    if (generation == _generation) onRemoteSnapshot?.call(payload);
    _setStatus(
      _payload == _base ? CloudSyncStatus.synced : CloudSyncStatus.pending,
    );
    if (_payload != _base) _schedule();
  }

  Future<void> _synchronize() async {
    final generation = _generation;
    try {
      await _initialize();
      await _localTail;
      if (!_active || _localFailed) return;
      if (status == CloudSyncStatus.conflict) return;
      _setStatus(CloudSyncStatus.syncing);
      final remote = await repository.fetch(ownerId);
      if (!_active) return;
      if (_generation != generation) {
        _setStatus(CloudSyncStatus.pending);
        _schedule();
        return;
      }
      if (remote != null) {
        _validate(remote);
        final snapshot = canonicalSnapshot(remote.snapshot);
        if (_payload == null || _payload == _base || _payload == snapshot) {
          await _accept(remote, generation);
          return;
        }
        if (remote.revision != _revision) {
          conflict = remote;
          _setStatus(CloudSyncStatus.conflict);
          return;
        }
      } else if (_revision > 0) {
        conflict = null;
        _setStatus(CloudSyncStatus.conflict);
        return;
      }
      if (_payload == null) {
        _setStatus(CloudSyncStatus.synced);
        return;
      }
      final sent = _payload!;
      final saved = await repository.save(ownerId, _revision, sent);
      if (!_active) return;
      if (saved == null) {
        conflict = await repository.fetch(ownerId);
        if (conflict != null) _validate(conflict!);
        _setStatus(CloudSyncStatus.conflict);
        return;
      }
      // The returned revision belongs to the sent payload. A newer local edit
      // remains pending rather than being replaced by this response.
      await _accept(saved, generation);
    } catch (_) {
      if (_active) {
        _setStatus(CloudSyncStatus.error);
        _schedule(const Duration(seconds: 30));
      }
    }
  }

  Future<bool> resolveConflict({required bool useCloud}) async {
    if (!_active || status != CloudSyncStatus.conflict) return false;
    try {
      final expected = conflict?.revision ?? 0;
      final generation = _generation;
      final remote = await repository.fetch(ownerId);
      if (!_active) return false;
      if (remote != null) _validate(remote);
      if ((remote?.revision ?? 0) != expected || generation != _generation) {
        conflict = remote;
        _setStatus(CloudSyncStatus.conflict);
        return false;
      }
      if (useCloud) {
        if (remote == null) return false;
        _backup = _payload;
        await _accept(remote, generation);
      } else {
        if (_payload == null) return false;
        _backup = remote?.snapshot;
        // Persist a recovery copy before replacing the accepted cloud version.
        await _persist();
        if (!_active) return false;
        final saved = await repository.save(ownerId, expected, _payload!);
        if (!_active) return false;
        if (saved == null) {
          conflict = await repository.fetch(ownerId);
          if (conflict != null) _validate(conflict!);
          _setStatus(CloudSyncStatus.conflict);
          return false;
        }
        await _accept(saved, generation);
      }
      return true;
    } catch (_) {
      if (_active) _setStatus(CloudSyncStatus.error);
      return false;
    }
  }

  Future<void> restoreRecoveryCopy() async {
    await _initialize();
    if (_backup == null || !_active) return;
    final recovery = _backup!;
    if (!CartStore.isValidSnapshot(recovery)) {
      throw const FormatException('Invalid recovery copy');
    }
    _backup = _payload;
    _payload = canonicalSnapshot(recovery);
    _generation++;
    await _persist();
    if (!_active) return;
    onRemoteSnapshot?.call(_payload!);
    conflict = null;
    _setStatus(CloudSyncStatus.pending);
    _schedule();
  }

  Future<void> eraseLocalAccount() async {
    _timer?.cancel();
    await _localTail;
    _payload = null;
    _base = null;
    _backup = null;
    _revision = 0;
    if (local is ErasableCartStorage) {
      await (local as ErasableCartStorage).clear();
    } else {
      await _persist();
    }
  }

  void _setStatus(CloudSyncStatus value) {
    if (_disposed) return;
    status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    onRemoteSnapshot = null;
    super.dispose();
  }
}
