import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/account_gateway.dart';
import '../core/money.dart';
import '../cloud/cloud_workspace.dart';
import '../data/backup_codec.dart';
import '../data/backup_files.dart';
import '../sharing/shared_copy.dart';
import '../sharing/shared_list_controller.dart';
import '../sharing/shared_repository.dart';
import '../sharing/shared_workspace.dart';
import '../state/cart_store.dart';
import '../widgets/product_avatar.dart';

class HouseholdCopiesScreen extends StatefulWidget {
  const HouseholdCopiesScreen({
    super.key,
    required this.workspace,
    required this.listId,
    this.privateStore,
    this.files,
    this.codec = const BackupCodec(),
  });
  final SharedWorkspace workspace;
  final String listId;
  final CartStore? privateStore;
  final BackupFiles? files;
  final BackupCodec codec;
  @override
  State<HouseholdCopiesScreen> createState() => _HouseholdCopiesScreenState();
}

class _HouseholdCopiesScreenState extends State<HouseholdCopiesScreen> {
  SharedCopyKind _kind = SharedCopyKind.device;
  bool _busy = false;
  String? _message;
  final _privateCopies = <String, String>{};
  late final _files = widget.files ?? NativeBackupFiles();
  SharedListController get controller =>
      widget.workspace.openList(widget.listId);
  @override
  void initState() {
    super.initState();
    unawaited(
      controller.initialize().catchError((Object _) {
        if (_active) {
          setState(
            () => _message = 'Couldn’t open this saved device copy. Its stored data was kept.',
          );
        }
      }),
    );
  }

  bool get _active => mounted && widget.workspace.isActive;
  SharedCopyReview? get _review =>
      controller.reviewCopy(_kind) ??
      controller.reviewCopy(SharedCopyKind.device);
  String _fingerprint(SharedCopyReview review) =>
      canonicalSnapshot(jsonEncode(review.content.toArguments()));

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_active) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (_active) {
        setState(
          () => _message = error is AccountProblem
              ? error.message
              : error is SharedAccessProblem
              ? 'Editing access is unavailable. You can still export this copy or save a private list.'
              : 'Couldn’t complete this device-copy action. Your shared list was not changed.',
        );
      }
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final review = _review;
    if (review == null) return;
    final bytes = await widget.codec.encode(
      portableSharedSnapshot(review.content),
    );
    if (!_active) return;
    var name = review.content.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
    if (name.length > 48) name = name.substring(0, 48);
    if (name.isEmpty) name = 'list';
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final saved = await _files.save(bytes, 'Carty-household-$name-$date.json');
    if (_active && saved) {
      setState(
        () => _message = 'Selected copy exported to the location you chose.',
      );
    }
  }

  Future<void> _privateCopy() async {
    final review = _review;
    final store = widget.privateStore;
    if (review == null || store == null) return;
    final fingerprint = _fingerprint(review);
    if (_privateCopies.containsKey(fingerprint)) {
      await store.retrySave();
      if (_active) {
        setState(
          () => _message = store.storageError == null
              ? 'Private copy saved. Open Lists to continue editing it.'
              : 'Saving still needs attention. Keep Carty open and retry.',
        );
      }
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _PrivateCopyDialog(review: review),
    );
    if (name == null || !_active) return;
    await store.load();
    if (!_active) return;
    final copy = await store.addSavedListCopy(
      portableSharedList(review.content, name: name),
    );
    if (!_active) return;
    setState(() {
      _privateCopies[fingerprint] = copy.id;
      _message = store.storageError == null
          ? 'Private copy saved. Your active basket and existing lists were kept.'
          : 'Private copy added, but saving needs attention. Keep Carty open and retry its save.';
    });
  }

  Future<void> _stage() async {
    final review = _review;
    if (review == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Stage this copy for review?'),
        scrollable: true,
        content: Text(
          'Use the displayed ${review.kind.label.toLowerCase()} on this device? Your current device copy will become the previous version. Review the household copy before these changes can sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('shared-copy-stage-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Stage copy'),
          ),
        ],
      ),
    );
    if (approved != true || !_active) return;
    await controller.stageCopy(review);
    if (mounted && widget.workspace.isActive) Navigator.pop(context, false);
  }

  Future<void> _remove() async {
    final state = controller.state;
    if (state == null) return;
    final generation = controller.generation;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove this list’s device copies?'),
        scrollable: true,
        content: Text(
          'Remove the current, accepted and previous copies saved on this device for “${state.local.name}”? '
          '${state.hasPendingEdits ? 'This includes unsynced changes. Export or create a private copy first if you need them. ' : ''}'
          'The shared cloud list and other members’ copies will stay. Reopening an accessible cloud list downloads a new device copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('shared-copy-remove-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove device copies'),
          ),
        ],
      ),
    );
    if (approved != true || !_active) return;
    await controller.removeDeviceCopy(expectedGeneration: generation);
    if (mounted && widget.workspace.isActive) Navigator.pop(context, true);
  }

  Future<void> _removeUnreadable() async {
    final generation = controller.generation;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove unreadable device data?'),
        scrollable: true,
        content: const Text(
          'Carty cannot read or export this device copy. Removing it permanently discards its unreadable local data, including any unsynced changes. The cloud list and other copies stay. An accessible cloud list can be downloaded again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('shared-copy-unreadable-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove unreadable copy'),
          ),
        ],
      ),
    );
    if (approved != true || !_active) return;
    await controller.removeUnreadableCopy(expectedGeneration: generation);
    if (mounted && widget.workspace.isActive) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.workspace.isActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Device copies')),
        body: const Center(
          child: Text('This account’s device copies are closed.'),
        ),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final review = _review;
        final content = review?.content;
        final device = controller.reviewCopy(SharedCopyKind.device);
        final sameAsDevice =
            review != null &&
            device != null &&
            _fingerprint(review) == _fingerprint(device);
        final copied =
            review != null && _privateCopies.containsKey(_fingerprint(review));
        return Scaffold(
          appBar: AppBar(title: const Text('Device copies')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: content == null
                    ? Center(
                        child: controller.status == SharedSyncStatus.loading
                            ? const CircularProgressIndicator()
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _message ?? 'No device copy is saved. Open the household list to download one.',
                                    ),
                                    if (controller.status ==
                                        SharedSyncStatus.storageError) ...[
                                      const SizedBox(height: 20),
                                      OutlinedButton(
                                        key: const Key(
                                          'shared-copy-unreadable-remove',
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => _run(_removeUnreadable),
                                        child: const Text(
                                          'Remove unreadable device copy',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: content.items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Choose a saved version to review. Export or save a private list without changing the household list.',
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final kind in SharedCopyKind.values)
                                      if (controller.reviewCopy(kind) != null)
                                        ChoiceChip(
                                          key: Key('shared-copy-${kind.name}'),
                                          label: Text(switch (kind) {
                                            SharedCopyKind.device => 'Device',
                                            SharedCopyKind.accepted =>
                                              'Accepted',
                                            SharedCopyKind.previous =>
                                              'Previous',
                                          }),
                                          selected: review!.kind == kind,
                                          onSelected: _busy
                                              ? null
                                              : (_) => setState(() {
                                                  _kind = kind;
                                                  _message = null;
                                                }),
                                        ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  review!.kind.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(
                                  content.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                Text(
                                  '${content.items.length} ${content.items.length == 1 ? 'product' : 'products'} · ${content.isPlanning ? 'Planning' : 'Shopping'}',
                                ),
                                Text(
                                  'Budget: ${content.budgetPence == null ? 'Not set' : Money.format(content.budgetPence!)}',
                                ),
                                Text(
                                  'Estimate: ${Money.format(content.items.fold<int>(0, (sum, item) => sum + item.estimatedTotalPence))} · Picked: ${Money.format(content.items.fold<int>(0, (sum, item) => sum + item.totalPence))}',
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      key: const Key('shared-copy-export'),
                                      onPressed: _busy
                                          ? null
                                          : () => _run(_export),
                                      icon: const Icon(
                                        Icons.file_download_outlined,
                                      ),
                                      label: const Text('Export this copy'),
                                    ),
                                    if (widget.privateStore != null)
                                      OutlinedButton.icon(
                                        key: const Key('shared-copy-private'),
                                        onPressed:
                                            _busy ||
                                                copied &&
                                                    widget
                                                            .privateStore!
                                                            .storageError ==
                                                        null
                                            ? null
                                            : () => _run(_privateCopy),
                                        icon: const Icon(Icons.copy_outlined),
                                        label: Text(
                                          copied
                                              ? widget
                                                            .privateStore!
                                                            .storageError ==
                                                        null
                                                    ? 'Copied to private Lists'
                                                    : 'Retry private save'
                                              : 'Save as private list',
                                        ),
                                      ),
                                    if (!sameAsDevice &&
                                        review.kind != SharedCopyKind.device &&
                                        controller.canEdit)
                                      OutlinedButton(
                                        key: const Key('shared-copy-stage'),
                                        onPressed: _busy
                                            ? null
                                            : () => _run(_stage),
                                        child: const Text(
                                          'Stage for household review',
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Exported JSON files are readable by anyone with access to the file. Only the selected shopping data is included; sign-in and membership details are excluded.',
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  key: const Key('shared-copy-remove'),
                                  onPressed: _busy ? null : () => _run(_remove),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  label: const Text('Remove device copies'),
                                ),
                                if (_message != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(_message!),
                                  ),
                                const SizedBox(height: 16),
                                if (content.items.isEmpty)
                                  const Text('No products in this copy.'),
                              ],
                            );
                          }
                          final item = content.items[index - 1];
                          return Card(
                            child: ListTile(
                              leading: ProductAvatar(name: item.name),
                              title: Text(item.name),
                              subtitle: Text(
                                'Planned ${item.plannedQuantity} · Picked ${item.quantity}\nEstimate ${Money.format(item.estimatedUnitPricePence)} · Shelf ${Money.format(item.unitPricePence)}${item.priceConfirmed ? ' confirmed' : ' unconfirmed'}',
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrivateCopyDialog extends StatefulWidget {
  const _PrivateCopyDialog({required this.review});
  final SharedCopyReview review;
  @override
  State<_PrivateCopyDialog> createState() => _PrivateCopyDialogState();
}

class _PrivateCopyDialogState extends State<_PrivateCopyDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.review.content.name);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save a private copy'),
    scrollable: true,
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Copy the displayed ${widget.review.content.items.length} products, budget and picked progress into a new private saved list. Your active basket stays. The copy can sync to your own account.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('shared-copy-private-name'),
            controller: _name,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Private list name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a list name'
                : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('shared-copy-private-confirm'),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _name.text.trim());
          }
        },
        child: const Text('Create private copy'),
      ),
    ],
  );
}
