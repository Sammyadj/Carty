import 'package:flutter/material.dart';

import '../auth/app_session.dart';
import '../core/money.dart';
import '../data/backup_codec.dart';
import '../data/backup_files.dart';
import '../data/carty_backup.dart';
import '../state/cart_store.dart';
import '../widgets/storage_notice.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({
    super.key,
    required this.store,
    this.files,
    this.codec = const BackupCodec(),
  });
  final CartStore store;
  final BackupFiles? files;
  final BackupCodec codec;
  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _busy = false;
  String? _message;
  CartStore get store => widget.store;
  late final BackupFiles _files = widget.files ?? NativeBackupFiles();

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on FormatException {
      if (mounted) {
        setState(
          () => _message = 'This file could not be opened as a valid Carty backup (maximum 20 MB). Your shopping data has not changed.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'The file operation could not be completed. Your current shopping data remains available.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run(() async {
    final saved = await store.waitForPendingSave();
    if (!mounted) return;
    if (!saved) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Export the visible workspace?'),
          content: const Text(
            'Carty could not finish saving locally. This exports only the products and lists currently visible, which may help recover your edits. It cannot export saved data that could not be opened.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('backup-export-unsaved-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Export visible data'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    final bytes = await widget.codec.encode(store.exportSnapshot());
    if (!mounted) return;
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final exported = await _files.save(bytes, 'Carty-backup-$date.json');
    if (mounted && exported) {
      setState(() => _message = 'Backup saved to the location you chose.');
    }
  });

  Future<void> _import() => _run(() async {
    final picked = await _files.pick();
    if (picked == null || !mounted) return;
    final backup = await widget.codec.decode(picked.bytes);
    if (mounted) await _review(backup, picked.name);
  });

  Future<void> _recover() => _run(() async {
    final snapshot = await store.readPreviousSnapshot();
    if (!mounted) return;
    if (snapshot == null) {
      setState(
        () => _message = 'There is no previous device save to recover yet.',
      );
      return;
    }
    await _review(
      CartyBackup.deviceSnapshot(snapshot),
      'Previous device save',
      deviceRecovery: true,
    );
  });

  Future<void> _review(
    CartyBackup backup,
    String name, {
    bool deviceRecovery = false,
  }) async {
    final current = store.exportSnapshot();
    final account = AccountScope.maybeOf(context)?.user;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Review backup'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '${backup.itemCount} basket products · ${backup.listCount} saved lists\n${backup.tripCount} completed shops · ${backup.preferenceCount} product choices',
              ),
              Text('Mode: ${backup.isPlanning ? 'Plan' : 'Shop'}'),
              Text(
                backup.budgetPence == null
                    ? 'Budget: Not set'
                    : 'Budget: ${Money.format(backup.budgetPence!)}',
              ),
              if (backup.createdAt != null)
                Text(
                  'Created: ${MaterialLocalizations.of(context).formatFullDate(backup.createdAt!.toLocal())}',
                ),
              Text(
                deviceRecovery
                    ? 'Previous device save validated. Review the contents before restoring.'
                    : backup.hasChecksum
                    ? 'Checksum checked. Review the contents before restoring.'
                    : 'Older workspace file without a checksum. Review it carefully.',
              ),
              for (final field in ['items', 'savedLists', 'history'])
                if (backup.names(field).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(switch (field) {
                    'items' => 'Basket preview',
                    'savedLists' => 'Saved lists preview',
                    _ => 'History preview',
                  }, style: Theme.of(context).textTheme.labelLarge),
                  for (final name in backup.names(field)) Text(name),
                ],
              const Divider(height: 28),
              Text(
                'Current workspace: ${store.items.length} basket products, ${store.savedLists.length} saved lists, ${store.history.length} completed shops.',
              ),
              const SizedBox(height: 8),
              Text(
                account == null
                    ? 'This replaces the current guest workspace. A previous device save is kept when available.'
                    : 'This replaces your current signed-in workspace and will sync to your account. A previous device save is kept when available.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign-in sessions and shared-list access are not restored from backup files.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('backup-restore-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace workspace'),
          ),
        ],
      ),
    );
    if (replace != true || !mounted) return;
    final restored = await store.replaceFromBackup(
      backup.snapshot,
      expectedCurrent: current,
    );
    if (!mounted) return;
    setState(
      () => _message = restored
          ? 'Backup restored. Your previous device save remains available when supported.'
          : store.storageError ?? 'Your shopping data changed while you reviewed the backup. Review it again before replacing anything.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Data & backups')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: AnimatedBuilder(
            animation: store,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                StorageNotice(store: store),
                Text(
                  'Keep a copy of your shopping data',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Export your basket, lists, completed shops and product choices. Backups are readable JSON files, so choose a private location.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Restoring replaces the current workspace after review. It does not merge lists or restore sign-in credentials.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('backup-export'),
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export backup'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('backup-import'),
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Import backup'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('backup-recover'),
                  onPressed: _busy ? null : _recover,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Recover previous device save'),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Working with your backup',
                    ),
                  ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(_message!, key: const Key('backup-message')),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
