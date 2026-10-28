import 'dart:io';

import 'package:carty_app/models/cart_item.dart';
import 'package:carty_app/sharing/shared_list.dart';
import 'package:carty_app/sharing/shared_list_cache.dart';
import 'package:carty_app/sharing/shared_repository.dart';
import 'package:carty_app/sharing/shared_workspace.dart';

class HouseholdTestData {
  SharedContent content = SharedContent(
    name: 'Weekly household shop',
    budgetPence: 5000,
    isPlanning: false,
    items: [
      const CartItem(
        id: 'milk',
        name: 'Milk',
        unitPricePence: 175,
        quantity: 1,
        plannedQuantity: 3,
        estimatedUnitPricePence: 150,
      ),
    ],
  );
  int revision = 1, saves = 0;
  bool offline = false, exists = true;
  bool conflictOnDelete = false;
  String ownerId = 'alice';
  Future<void> Function(String)? beforeRevoke;
  final roles = <String, SharedRole>{
    'alice': SharedRole.owner,
    'bob': SharedRole.editor,
    'viewer': SharedRole.viewer,
  };
  final caches = <String, HouseholdTestCache>{};
  final invitations = <Map<String, dynamic>>[];
  SharedContent? created;
  SharedWorkspace workspace(String account) => SharedWorkspace(
    repository: HouseholdTestRepository(this, account),
    isCurrentSession: () => true,
    autoSync: false,
    cacheFactory: (user, list) =>
        caches.putIfAbsent('$user/$list', HouseholdTestCache.new),
    cacheIndex: (user) async => caches.keys
        .where((key) => key.startsWith('$user/'))
        .map((key) => key.substring(user.length + 1))
        .toList(),
  );
  SharedListHeader header(String account) => SharedListHeader(
    id: 'weekly',
    ownerId: ownerId,
    name: content.name,
    budgetPence: content.budgetPence,
    isPlanning: content.isPlanning,
    revision: revision,
    updatedAt: DateTime.utc(2026, 10, 28, 10),
    role: roles[account]!,
  );
  void check() {
    if (offline) throw const SocketException('offline');
  }
}

class HouseholdTestCache implements SharedListCache {
  CachedSharedList? value;
  bool failWrites = false;
  @override
  Future<CachedSharedList?> read() async => value;
  @override
  Future<void> write(CachedSharedList value) async {
    if (failWrites) throw const FileSystemException('Device save failed');
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class HouseholdTestRepository implements SharedRepository {
  HouseholdTestRepository(this.data, this.accountId);
  final HouseholdTestData data;
  @override
  final String accountId;
  void owner() {
    data.check();
    if (!data.exists || data.roles[accountId] != SharedRole.owner) {
      throw const SharedAccessProblem();
    }
  }

  @override
  Future<List<SharedListHeader>> lists() async {
    data.check();
    return data.exists && data.roles.containsKey(accountId)
        ? [data.header(accountId)]
        : [];
  }

  @override
  Future<SharedListDocument?> fetch(String id) async {
    data.check();
    return !data.exists || !data.roles.containsKey(accountId)
        ? null
        : SharedListDocument(data.header(accountId), data.content.items);
  }

  @override
  Future<SharedSaveReceipt> create(SharedContent content) async {
    data.check();
    data.created = content;
    data.content = content;
    data.ownerId = accountId;
    data.roles
      ..clear()
      ..[accountId] = SharedRole.owner;
    data.exists = true;
    data.revision = 1;
    return SharedSaveReceipt('weekly', 1, content);
  }

  @override
  Future<SharedSaveReceipt?> save(
    String id,
    int revision,
    SharedContent content,
  ) async {
    data.check();
    if (data.roles[accountId]?.canEdit != true) {
      throw const SharedAccessProblem();
    }
    if (revision != data.revision) return null;
    data.saves++;
    data.content = content;
    data.revision++;
    return SharedSaveReceipt(id, data.revision, content);
  }

  @override
  Future<List<SharedInvitation>> invitations({String? listId}) async {
    data.check();
    return data.invitations
        .where(
          (row) => listId == null
              ? row['recipient_email'] == '$accountId@example.invalid' &&
                    row['accepted_at'] == null &&
                    row['revoked_at'] == null
              : row['list_id'] == listId,
        )
        .map(SharedInvitation.fromRow)
        .toList();
  }

  @override
  Future<InvitationReceipt> invite(
    String id,
    String email,
    SharedRole role,
  ) async {
    owner();
    final invitationId = 'invite-${data.invitations.length}';
    data.invitations.add({
      'id': invitationId,
      'list_id': id,
      'list_name': data.content.name,
      'inviter_name': 'Alice',
      'recipient_email': email,
      'role': role.name,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(days: 7))
          .toIso8601String(),
      'accepted_by': null,
      'accepted_at': null,
      'revoked_at': null,
      'delivery_status': 'in_app',
    });
    return InvitationReceipt(invitationId, InvitationDelivery.inApp);
  }

  @override
  Future<String> accept(String id) async {
    data.check();
    final row = data.invitations.singleWhere((row) => row['id'] == id);
    if (row['recipient_email'] != '$accountId@example.invalid') {
      throw const SharedAccessProblem();
    }
    row['accepted_at'] = DateTime.now().toUtc().toIso8601String();
    row['accepted_by'] = accountId;
    data.roles[accountId] = SharedRole.member(row['role']);
    return row['list_id'] as String;
  }

  @override
  Future<void> decline(String id) async {
    data.check();
    data.invitations.singleWhere((row) => row['id'] == id)['revoked_at'] =
        DateTime.now().toUtc().toIso8601String();
  }

  @override
  Future<List<SharedMember>> members(String listId) async {
    owner();
    return [
      for (final entry in data.roles.entries)
        if (entry.value != SharedRole.owner)
          SharedMember.fromRow({
            'list_id': listId,
            'user_id': entry.key,
            'role': entry.value.name,
          }),
    ];
  }

  @override
  Future<void> changeMember(
    String listId,
    String userId,
    SharedRole? role,
  ) async {
    owner();
    if (userId == data.ownerId || role == SharedRole.owner) {
      throw const SharedAccessProblem();
    }
    if (role == null) {
      data.roles.remove(userId);
    } else if (data.roles.containsKey(userId)) {
      data.roles[userId] = role;
    }
    for (final row in data.invitations) {
      if (row['recipient_email'] == '$userId@example.invalid' &&
          row['accepted_at'] == null &&
          row['revoked_at'] == null) {
        row['revoked_at'] = DateTime.now().toUtc().toIso8601String();
      }
    }
  }

  @override
  Future<void> revoke(String invitationId) async {
    owner();
    await data.beforeRevoke?.call(invitationId);
    final row = data.invitations.singleWhere(
      (row) => row['id'] == invitationId,
    );
    if (row['accepted_at'] == null) {
      row['revoked_at'] = DateTime.now().toUtc().toIso8601String();
    }
  }

  @override
  Future<void> leave(String listId) async {
    data.check();
    if (data.roles[accountId] == null ||
        data.roles[accountId] == SharedRole.owner) {
      throw const SharedAccessProblem();
    }
    data.roles.remove(accountId);
  }

  @override
  Future<bool> delete(String listId, int revision) async {
    owner();
    if (data.conflictOnDelete) {
      data.revision++;
      return false;
    }
    if (revision != data.revision) return false;
    data.exists = false;
    data.roles.clear();
    data.invitations.clear();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
