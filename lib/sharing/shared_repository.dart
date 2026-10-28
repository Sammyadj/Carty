import 'shared_list.dart';

abstract interface class SharedRepository {
  String get accountId;
  Future<List<SharedListHeader>> lists();

  /// Null means the list was deleted or this account no longer has access.
  Future<SharedListDocument?> fetch(String listId);
  Future<SharedSaveReceipt> create(SharedContent content);

  /// Null means a concurrent edit; callers must review before resubmitting.
  Future<SharedSaveReceipt?> save(
    String listId,
    int revision,
    SharedContent content,
  );
  Future<List<SharedInvitation>> invitations({String? listId});
  Future<List<SharedMember>> members(String listId);
  Future<InvitationReceipt> invite(
    String listId,
    String email,
    SharedRole role,
  );
  Future<String> accept(String invitationId);
  Future<void> decline(String invitationId);
  Future<void> revoke(String invitationId);
  Future<void> changeMember(String listId, String userId, SharedRole? role);
  Future<void> leave(String listId);
  Future<bool> delete(String listId, int revision);
}

class SharedAccessProblem implements Exception {
  const SharedAccessProblem();
  @override
  String toString() =>
      'Your access has changed. Refresh this household list before continuing.';
}
