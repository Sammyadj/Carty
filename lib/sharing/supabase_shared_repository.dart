import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/account_gateway.dart';
import '../models/cart_item.dart';
import 'shared_list.dart';
import 'shared_repository.dart';

/// Bound to one signed-in account. No async result may escape after an account
/// switch. RLS and the action RPC remain authoritative for every permission.
class SupabaseSharedRepository implements SharedRepository {
  SupabaseSharedRepository(this.client, {required this.accountId});
  final SupabaseClient client;
  @override
  final String accountId;
  static const _pageSize = 500;
  static const _timeout = Duration(seconds: 12);

  void _checkSession() {
    if (client.auth.currentUser?.id != accountId) {
      throw const AccountProblem(
        'Please sign in again before opening household lists.',
      );
    }
  }

  Future<T> _request<T>(Future<T> Function() operation) async {
    _checkSession();
    try {
      final result = await operation().timeout(_timeout);
      _checkSession();
      return result;
    } on PostgrestException catch (error) {
      _checkSession();
      if (error.code == '42501') throw const SharedAccessProblem();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _action(
    String action,
    Map<String, Object?> args,
  ) async {
    final result = await _request(
      () => client.rpc(
        'carty_shared_action',
        params: {'p_action': action, 'p_args': args},
      ),
    );
    if (result is! Map<String, dynamic>) {
      throw const FormatException('Invalid household response');
    }
    return result;
  }

  Future<SharedListHeader?> _header(String id) async {
    final row = await _request(
      () =>
          client.from('carty_shared_lists').select().eq('id', id).maybeSingle(),
    );
    if (row == null) return null;
    if (row['id'] != id) {
      throw const FormatException('Foreign household header');
    }
    SharedRole role;
    if (row['owner_id'] == accountId) {
      role = SharedRole.owner;
    } else {
      final member = await _request(
        () => client
            .from('carty_shared_members')
            .select()
            .eq('list_id', id)
            .eq('user_id', accountId)
            .maybeSingle(),
      );
      if (member == null) return null;
      if (member['list_id'] != id || member['user_id'] != accountId) {
        throw const FormatException('Foreign household membership');
      }
      role = SharedRole.member(member['role']);
    }
    return SharedListHeader.fromRow(row, role);
  }

  @override
  Future<List<SharedListHeader>> lists() async {
    final result = <SharedListHeader>[];
    final seen = <String>{};
    // Stable ID ordering avoids update-time reordering between library pages.
    for (var offset = 0; ; offset += _pageSize) {
      final rows = await _request(
        () => client
            .from('carty_shared_lists')
            .select('id')
            .order('id')
            .range(offset, offset + _pageSize - 1),
      );
      for (final row in rows) {
        final id = sharedText(row['id']);
        if (!seen.add(id)) continue;
        final header = await _header(id);
        if (header != null) result.add(header);
      }
      if (rows.length < _pageSize) break;
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(result);
  }

  @override
  Future<SharedListDocument?> fetch(String listId) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final before = await _header(listId);
      if (before == null) return null;
      final raw = <Map<String, dynamic>>[];
      int? expectedCount;
      var inconsistentCount = false;
      // One extra row detects a corrupt server response beyond the 1,000 limit.
      for (var offset = 0; offset <= 1000; offset += _pageSize) {
        final page = await _request(
          () => client
              .from('carty_shared_items')
              .select()
              .eq('list_id', listId)
              .order('position')
              .range(offset, offset + _pageSize - 1)
              .count(CountOption.exact),
        );
        expectedCount ??= page.count;
        if (page.count != expectedCount) inconsistentCount = true;
        final rows = page.data;
        raw.addAll(rows);
        if (rows.length < _pageSize) break;
      }
      // Membership changes do not advance the content revision. Recheck both.
      final after = await _header(listId);
      if (after == null) return null;
      if (!before.sameVersion(after)) continue;
      if (raw.length > 1000 ||
          raw.length != expectedCount ||
          inconsistentCount) {
        throw const FormatException('Incomplete household products');
      }
      final items = <CartItem>[];
      for (final row in raw) {
        if (row['list_id'] != listId ||
            row['position'] != items.length ||
            row['revision'] is! int ||
            row['revision'] < 1 ||
            row['revision'] > after.revision ||
            row['data'] is! Map<String, dynamic>) {
          throw const FormatException('Incomplete household products');
        }
        final item = CartItem.fromJson(row['data'] as Map<String, dynamic>);
        if (item == null || item.id != row['item_id']) {
          throw const FormatException('Invalid household product');
        }
        items.add(item);
      }
      return SharedListDocument(after, items);
    }
    throw const AccountProblem(
      'This household list changed during download. Please refresh shortly.',
    );
  }

  SharedSaveReceipt _receipt(
    Map<String, dynamic> result,
    SharedContent content, {
    String? expectedId,
    required int expectedRevision,
  }) {
    final id = sharedText(result['listId']);
    if ((expectedId != null && id != expectedId) ||
        result['revision'] != expectedRevision) {
      throw const FormatException('Invalid shared save acknowledgement');
    }
    return SharedSaveReceipt(id, expectedRevision, content);
  }

  @override
  Future<SharedSaveReceipt> create(SharedContent content) async => _receipt(
    await _action('create', content.toArguments()),
    content,
    expectedRevision: 1,
  );

  @override
  Future<SharedSaveReceipt?> save(
    String listId,
    int revision,
    SharedContent content,
  ) async {
    if (revision < 1) throw ArgumentError.value(revision);
    final result = await _action('save', {
      ...content.toArguments(),
      'listId': listId,
      'expectedRevision': revision,
    });
    if (result['conflict'] == true) return null;
    return _receipt(
      result,
      content,
      expectedId: listId,
      expectedRevision: revision + 1,
    );
  }

  @override
  Future<List<SharedInvitation>> invitations({String? listId}) async {
    _checkSession();
    final email = client.auth.currentUser?.email?.trim().toLowerCase();
    if (listId == null && (email == null || email.isEmpty)) return [];
    final result = <SharedInvitation>[];
    for (var offset = 0; ; offset += _pageSize) {
      final rows = await _request(() {
        var query = client.from('carty_shared_invitations').select();
        query = listId == null
            ? query
                  .eq('recipient_email', email!)
                  .isFilter('accepted_at', null)
                  .isFilter('revoked_at', null)
            : query.eq('list_id', listId);
        return query.order('id').range(offset, offset + _pageSize - 1);
      });
      for (final row in rows) {
        final invitation = SharedInvitation.fromRow(row);
        if ((listId != null && invitation.listId != listId) ||
            (listId == null && invitation.email != email)) {
          throw const FormatException('Foreign household invitation');
        }
        result.add(invitation);
      }
      if (rows.length < _pageSize) break;
    }
    return List.unmodifiable(result);
  }

  @override
  Future<List<SharedMember>> members(String listId) async {
    final result = <SharedMember>[];
    for (var offset = 0; ; offset += _pageSize) {
      final rows = await _request(
        () => client
            .from('carty_shared_members')
            .select()
            .eq('list_id', listId)
            .order('user_id')
            .range(offset, offset + _pageSize - 1),
      );
      for (final row in rows) {
        final member = SharedMember.fromRow(row);
        if (member.listId != listId) {
          throw const FormatException('Foreign household member');
        }
        result.add(member);
      }
      if (rows.length < _pageSize) break;
    }
    return List.unmodifiable(result);
  }

  @override
  Future<InvitationReceipt> invite(
    String listId,
    String email,
    SharedRole role,
  ) async {
    _memberRole(role);
    final address = email.trim().toLowerCase();
    if (address.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      throw const AccountProblem('Enter a valid email address.');
    }
    final result = await _action('invite', {
      'listId': listId,
      'email': address,
      'role': role.name,
    });
    return InvitationReceipt(
      sharedText(result['invitationId']),
      parseDelivery(result['deliveryStatus']),
    );
  }

  @override
  Future<String> accept(String invitationId) async {
    final result = await _action('accept', {'invitationId': invitationId});
    _ok(result);
    return sharedText(result['listId']);
  }

  @override
  Future<void> decline(String invitationId) async =>
      _ok(await _action('decline', {'invitationId': invitationId}));
  @override
  Future<void> revoke(String invitationId) async =>
      _ok(await _action('revoke', {'invitationId': invitationId}));
  @override
  Future<void> changeMember(
    String listId,
    String userId,
    SharedRole? role,
  ) async {
    if (role != null) _memberRole(role);
    _ok(
      await _action('member', {
        'listId': listId,
        'userId': userId,
        'role': role?.name,
      }),
    );
  }

  @override
  Future<void> leave(String listId) async =>
      _ok(await _action('leave', {'listId': listId}));
  @override
  Future<bool> delete(String listId, int revision) async {
    if (revision < 1) throw ArgumentError.value(revision);
    final result = await _action('delete', {
      'listId': listId,
      'expectedRevision': revision,
    });
    if (result['conflict'] == true) return false;
    _ok(result);
    return true;
  }

  void _ok(Map<String, dynamic> result) {
    if (result['ok'] != true) {
      throw const FormatException('Household action was not acknowledged');
    }
  }

  void _memberRole(SharedRole role) {
    if (role == SharedRole.owner) {
      throw ArgumentError(
        'Ownership cannot be assigned through an invitation or role change.',
      );
    }
  }
}
