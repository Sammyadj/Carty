import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/account_gateway.dart';
import '../sharing/shared_list.dart';
import '../sharing/shared_list_controller.dart';
import '../sharing/shared_repository.dart';
import '../sharing/shared_workspace.dart';

enum _MemberAction { viewer, editor, remove }

class HouseholdMembersScreen extends StatefulWidget {
  const HouseholdMembersScreen({
    super.key,
    required this.workspace,
    required this.listId,
  });
  final SharedWorkspace workspace;
  final String listId;
  @override
  State<HouseholdMembersScreen> createState() => _HouseholdMembersScreenState();
}

class _HouseholdMembersScreenState extends State<HouseholdMembersScreen> {
  SharedListDocument? _document;
  List<SharedMember> _members = [];
  List<SharedInvitation> _invitations = [];
  bool _loading = true, _busy = false;
  String? _error;
  int _loadGeneration = 0;
  SharedWorkspace get workspace => widget.workspace;
  SharedListController get controller => workspace.openList(widget.listId);
  bool get _active => mounted && workspace.isActive;
  bool get _owner => _document?.header.role == SharedRole.owner;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!_active) return;
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final document = await workspace.repository.fetch(widget.listId);
      if (!_active || generation != _loadGeneration) return;
      if (document == null) {
        setState(() {
          _document = null;
          _members = [];
          _invitations = [];
          _error = 'This list is no longer available to your account.';
        });
        return;
      }
      var members = <SharedMember>[];
      var invitations = <SharedInvitation>[];
      if (document.header.role == SharedRole.owner) {
        final result = await Future.wait([
          workspace.repository.members(widget.listId),
          workspace.repository.invitations(listId: widget.listId),
        ]);
        members = result[0] as List<SharedMember>;
        invitations = result[1] as List<SharedInvitation>;
      }
      if (!_active || generation != _loadGeneration) return;
      setState(() {
        _document = document;
        _members = members;
        _invitations = invitations;
      });
    } catch (_) {
      if (_active && generation == _loadGeneration) {
        setState(() {
          _document = null;
          _members = [];
          _invitations = [];
          _error = 'Couldn’t check household access. Reconnect and refresh before making changes.';
        });
      }
    } finally {
      if (_active && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  void _message(String text) {
    if (!_active) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_active) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _message(
        error is AccountProblem
            ? error.message
            : error is SharedAccessProblem
            ? 'Your access changed. Refresh this screen before continuing.'
            : 'Couldn’t change household access. Check your connection and try again.',
      );
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('household-access-confirm'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  String _memberName(String id) {
    for (final invitation in _invitations.reversed) {
      if (invitation.acceptedBy == id) return invitation.email;
    }
    return 'Household member';
  }

  Future<void> _changeMember(SharedMember member, _MemberAction action) async {
    final role = switch (action) {
      _MemberAction.viewer => SharedRole.viewer,
      _MemberAction.editor => SharedRole.editor,
      _MemberAction.remove => null,
    };
    if (role == member.role) return;
    final name = _memberName(member.userId);
    final confirmed = await _confirm(
      role == null ? 'Remove access?' : 'Change permission?',
      role == null
          ? '$name will lose access to this household list. Previously downloaded copies cannot be remotely erased.'
          : '$name will become ${role.label.toLowerCase()}. ${role == SharedRole.viewer ? 'They can read the list but cannot change or check off products.' : 'They can change products, prices, quantities, the budget and list details.'}',
      role == null ? 'Remove access' : 'Change permission',
    );
    if (!confirmed || !_active) return;
    await workspace.repository.changeMember(widget.listId, member.userId, role);
    if (_active) await _load();
  }

  Future<void> _revoke(SharedInvitation invitation) async {
    if (!await _confirm(
          'Revoke invitation?',
          '${invitation.email} will no longer be able to accept this invitation.',
          'Revoke',
        ) ||
        !_active) {
      return;
    }
    await workspace.repository.revoke(invitation.id);
    if (!_active) return;
    await _load();
    if (_invitations.any(
      (item) => item.id == invitation.id && item.acceptedAt != null,
    )) {
      _message(
        'This invitation was already accepted. Use the member controls to remove access.',
      );
    }
  }

  Future<void> _endAccess({required bool delete}) async {
    final currentController = controller;
    try {
      final saved = await currentController.pauseForAccessChange();
      if (!_active) return;
      final latest = await workspace.repository.fetch(widget.listId);
      if (!_active) return;
      if (latest == null) throw const SharedAccessProblem();
      if (delete && latest.header.role != SharedRole.owner ||
          !delete && latest.header.role == SharedRole.owner) {
        throw const SharedAccessProblem();
      }
      final confirmed = await _confirm(
        delete ? 'Delete shared list for everyone?' : 'Leave household list?',
        '${delete ? '“${latest.header.name}” and its cloud products, memberships and invitations will be deleted for everyone.' : 'You will lose access to “${latest.header.name}”. The list will stay available to the household.'}\n\n'
        '${saved?.hasPendingEdits == true ? 'You have unsynced changes. ' : ''}A read-only device copy will be kept for review, including any unsynced work. Other devices may also retain downloaded copies.',
        delete ? 'Delete shared list' : 'Leave list',
      );
      if (!confirmed || !_active) return;
      if (delete) {
        final removed = await workspace.repository.delete(
          widget.listId,
          latest.header.revision,
        );
        if (!_active) return;
        if (!removed) {
          await _load();
          _message(
            'The list changed during your review. Check the latest copy before deleting it.',
          );
          return;
        }
      } else {
        await workspace.repository.leave(widget.listId);
        if (!_active) return;
      }
      var copySaved = true;
      try {
        await currentController.retainWithoutAccess();
      } catch (_) {
        copySaved = false;
      }
      if (!mounted || !workspace.isActive) return;
      if (!copySaved) {
        _message(
          'Household access ended, but the device copy could not be updated. Your existing saved data was kept. Reopen online before editing.',
        );
      }
      Navigator.pop(context, true);
    } finally {
      currentController.resumeSync();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_owner ? 'Manage people' : 'Household access'),
      actions: [
        IconButton(
          tooltip: 'Refresh access',
          onPressed: _busy || _loading || !workspace.isActive ? null : _load,
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
                  child: Text('This account’s household access is closed.'),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_loading) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(_error!),
                      ),
                    if (_document != null) ...[
                      Text(
                        _document!.content.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('Your permission: ${_document!.header.role.label}'),
                      const SizedBox(height: 24),
                      if (_owner) ...[
                        const Text(
                          'Only you can invite people, change permissions or delete this shared list.',
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Members',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const ListTile(
                          leading: Icon(Icons.person_outline_rounded),
                          title: Text('You'),
                          subtitle: Text('Owner'),
                        ),
                        for (final member in _members)
                          Card(
                            child: ListTile(
                              title: Text(_memberName(member.userId)),
                              subtitle: Text(member.role.label),
                              trailing: PopupMenuButton<_MemberAction>(
                                key: Key('household-member-${member.userId}'),
                                enabled: !_busy && !_loading,
                                tooltip:
                                    'Change access for ${_memberName(member.userId)}',
                                onSelected: (action) =>
                                    _run(() => _changeMember(member, action)),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: _MemberAction.viewer,
                                    child: Text('Make viewer'),
                                  ),
                                  PopupMenuItem(
                                    value: _MemberAction.editor,
                                    child: Text('Make editor'),
                                  ),
                                  PopupMenuItem(
                                    value: _MemberAction.remove,
                                    child: Text('Remove access'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          'Pending invitations',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (!_invitations.any(
                          (item) => item.isPending(DateTime.now()),
                        ))
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('No pending invitations.'),
                          ),
                        for (final invitation in _invitations.where(
                          (item) => item.isPending(DateTime.now()),
                        ))
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invitation.email,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    '${invitation.role.label} · available in Carty',
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    key: Key(
                                      'household-revoke-${invitation.id}',
                                    ),
                                    onPressed: _busy || _loading
                                        ? null
                                        : () => _run(() => _revoke(invitation)),
                                    child: const Text('Revoke invitation'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          key: const Key('household-delete'),
                          onPressed: _busy || _loading
                              ? null
                              : () => _run(() => _endAccess(delete: true)),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete shared list'),
                        ),
                      ] else ...[
                        Text(
                          _document!.header.role == SharedRole.viewer
                              ? 'You can read this list. Only editors and the owner can change or check off products.'
                              : 'You can change products, prices, quantities and the budget. Only the owner can manage people.',
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton(
                          key: const Key('household-leave'),
                          onPressed: _busy || _loading
                              ? null
                              : () => _run(() => _endAccess(delete: false)),
                          child: const Text('Leave list'),
                        ),
                      ],
                    ],
                  ],
                ),
        ),
      ),
    ),
  );
}
