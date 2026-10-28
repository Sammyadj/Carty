import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/account_gateway.dart';
import '../core/money.dart';
import '../design/carty_design.dart';
import '../sharing/shared_list.dart';
import '../sharing/shared_workspace.dart';
import '../state/cart_store.dart';
import 'household_list_details_dialog.dart';
import 'household_list_screen.dart';
import 'household_copies_screen.dart';

class HouseholdLibraryScreen extends StatefulWidget {
  const HouseholdLibraryScreen({
    super.key,
    required this.workspace,
    required this.privateStore,
  });
  final SharedWorkspace workspace;
  final CartStore privateStore;
  @override
  State<HouseholdLibraryScreen> createState() => _HouseholdLibraryScreenState();
}

class _HouseholdLibraryScreenState extends State<HouseholdLibraryScreen> {
  List<SharedListHeader> _lists = [];
  List<SharedInvitation> _invitations = [];
  Set<String> _deviceOnly = {};
  Set<String> _recoveryIds = {};
  List<String> _unreadableIds = [];
  bool _loading = true, _busy = false;
  String? _error;
  int _loadGeneration = 0;
  SharedWorkspace get workspace => widget.workspace;
  bool get _active => mounted && workspace.isActive;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!_active) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final cached = <String, SharedListHeader>{};
    final knownLost = <String>{};
    try {
      final catalog = await workspace.inspectDeviceCopies();
      for (final value in catalog.copies) {
        cached[value.header.id] = value.header;
        if (value.accessLost) knownLost.add(value.header.id);
      }
      if (!_active || generation != _loadGeneration) return;
      setState(() {
        _lists = cached.values.toList();
        _deviceOnly = cached.keys.toSet();
        _recoveryIds = knownLost;
        _unreadableIds = catalog.unreadableListIds;
        if (_unreadableIds.isNotEmpty) _error = 'Some device copies could not be opened. They were kept; other copies remain available.';
      });
    } catch (_) {
      if (!_active || generation != _loadGeneration) return;
      setState(
        () => _error = 'Some saved household data could not be opened. It has been kept for recovery.',
      );
    }
    try {
      final result = await Future.wait([
        workspace.repository.lists(),
        workspace.repository.invitations(),
      ]);
      if (!_active || generation != _loadGeneration) return;
      final online = result[0] as List<SharedListHeader>;
      final invitations = result[1] as List<SharedInvitation>;
      setState(() {
        _lists = {
          ...cached,
          for (final item in online) item.id: item,
        }.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _deviceOnly = cached.keys.toSet()
          ..removeAll(online.map((item) => item.id));
        _recoveryIds = _deviceOnly.toSet();
        _invitations = invitations
            .where((item) => item.isPending(DateTime.now()))
            .toList();
      });
    } catch (_) {
      if (_active && generation == _loadGeneration) {
        setState(
          () => _error = 'Couldn’t refresh household lists. Previously opened lists remain available on this device.',
        );
      }
    } finally {
      if (_active && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_active) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted && workspace.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AccountProblem ? error.message : 'Couldn’t complete this household action. Check your connection and permissions.',
            ),
          ),
        );
      }
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<void> _open(String id) async {
    if (!_active) return;
    if (_recoveryIds.contains(id)) {
      final controller = workspace.openList(id);
      Object? retentionError;
      try {
        await controller.pauseForAccessChange();
        await controller.retainWithoutAccess();
      } catch (error) {
        retentionError = error;
      } finally {
        controller.resumeSync();
      }
      if (!mounted || !workspace.isActive) return;
      if (retentionError != null) {
        if (controller.content == null || controller.canEdit) {
          throw retentionError;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The device copy could not be updated. Its saved products are available read only.',
            ),
          ),
        );
      }
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseholdListScreen(
          workspace: workspace,
          listId: id,
          privateStore: widget.privateStore,
        ),
      ),
    );
    if (_active) await _load();
  }

  Future<void> _unreadableCopy(String id) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseholdCopiesScreen(
          workspace: workspace,
          listId: id,
          privateStore: widget.privateStore,
        ),
      ),
    );
    if (_active) await _load();
  }

  Future<void> _create() async {
    final store = widget.privateStore;
    final sources = <SharedContent>[
      SharedContent(
        name: 'Household shop',
        budgetPence: null,
        isPlanning: true,
        items: [],
      ),
      if (store.items.isNotEmpty && store.items.length <= 1000)
        SharedContent(
          name: 'Current basket',
          budgetPence: store.budgetPence,
          isPlanning: store.isPlanning,
          items: store.items,
        ),
      for (final list in store.savedLists.where(
        (item) => !item.archived && item.items.length <= 1000,
      ))
        SharedContent(
          name: list.name,
          budgetPence: list.budgetPence,
          isPlanning: list.isPlanning,
          items: list.items,
        ),
    ];
    final source = await showModalBottomSheet<SharedContent>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Start a household list',
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            if (store.items.length > 1000 ||
                store.savedLists.any(
                  (item) => !item.archived && item.items.length > 1000,
                ))
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Household lists support up to 1,000 products. Larger private lists can be split before sharing.',
                ),
              ),
            const SizedBox(height: 12),
            for (var i = 0; i < sources.length; i++)
              ListTile(
                key: Key('household-source-$i'),
                leading: Icon(i == 0 ? Icons.add_rounded : Icons.copy_outlined),
                title: Text(i == 0 ? 'Empty list' : sources[i].name),
                subtitle: Text(
                  i == 0
                      ? 'Plan a new shop together'
                      : 'Share a copy · ${sources[i].items.length} products',
                ),
                onTap: () => Navigator.pop(sheet, sources[i]),
              ),
          ],
        ),
      ),
    );
    if (source == null || !mounted || !workspace.isActive) return;
    final content = await showDialog<SharedContent>(
      context: context,
      builder: (_) =>
          HouseholdListDetailsDialog(content: source, creating: true),
    );
    if (content == null || !_active) return;
    final receipt = await workspace.repository.create(content);
    if (_active) await _open(receipt.listId);
  }

  Future<void> _accept(SharedInvitation invitation) async {
    final id = await workspace.repository.accept(invitation.id);
    if (_active) await _open(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Household lists'),
      actions: [
        IconButton(
          tooltip: 'Refresh household lists',
          onPressed: _busy || !workspace.isActive ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: !workspace.isActive
              ? const Center(
                  child: Text('This account’s household lists are closed.'),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: CartyDesign.of(context).heroColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.groups_2_outlined,
                              size: 36,
                              color: CartyDesign.of(context).heroInk,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'One shop, together',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: CartyDesign.of(context).heroInk,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Plan and pick from the same list. Owners choose who can view or edit.',
                              style: TextStyle(
                                color: CartyDesign.of(context).heroInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('household-create'),
                        onPressed: _busy ? null : () => _run(_create),
                        icon: const Icon(Icons.add),
                        label: const Text('Create shared list'),
                      ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: LinearProgressIndicator(),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(_error!),
                        ),
                      if (_invitations.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Invitations for you',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final invitation in _invitations)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invitation.listName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    '${invitation.inviterName} invited you as ${invitation.role.name}.',
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton(
                                        key: Key(
                                          'household-accept-${invitation.id}',
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => _run(
                                                () => _accept(invitation),
                                              ),
                                        child: const Text('Accept'),
                                      ),
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _run(() async {
                                                await workspace.repository
                                                    .decline(invitation.id);
                                                if (_active) await _load();
                                              }),
                                        child: const Text('Decline'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'Your household lists',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (!_loading &&
                          !_lists.any(
                            (list) => !_recoveryIds.contains(list.id),
                          ))
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Create a shared list or accept an invitation sent to your sign-in email.',
                          ),
                        ),
                      for (final list in _lists.where(
                        (list) =>
                            !_recoveryIds.contains(list.id) &&
                            !_unreadableIds.contains(list.id),
                      ))
                        Card(
                          child: ListTile(
                            key: Key('household-list-${list.id}'),
                            leading: const Icon(Icons.shopping_basket_outlined),
                            title: Text(list.name),
                            subtitle: Text(
                              '${list.role.label} · ${list.budgetPence == null ? 'No budget' : Money.format(list.budgetPence!)}${_deviceOnly.contains(list.id) ? '\nSaved device copy · access checked when opened' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _busy
                                ? null
                                : () => _run(() => _open(list.id)),
                          ),
                        ),
                      if (_recoveryIds.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Device recovery copies',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Read-only copies kept after access ended. Open a copy to review the products saved on this device.',
                        ),
                        const SizedBox(height: 12),
                        for (final list in _lists.where(
                          (list) => _recoveryIds.contains(list.id),
                        ))
                          Card(
                            child: ListTile(
                              key: Key('household-recovery-${list.id}'),
                              leading: const Icon(Icons.restore_rounded),
                              title: Text(list.name),
                              subtitle: const Text('Device copy · read only'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: _busy
                                  ? null
                                  : () => _run(() => _open(list.id)),
                            ),
                          ),
                      ],
                      if (_unreadableIds.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Unreadable device copies',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final id in _unreadableIds)
                          Card(
                            child: ListTile(
                              key: Key('household-unreadable-$id'),
                              leading: const Icon(Icons.warning_amber_rounded),
                              title: Text(
                                _lists
                                        .where((list) => list.id == id)
                                        .firstOrNull
                                        ?.name ??
                                    'Unreadable saved copy',
                              ),
                              subtitle: const Text(
                                'Stored data kept · review recovery options',
                              ),
                              onTap: _busy
                                  ? null
                                  : () => _run(() => _unreadableCopy(id)),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}
