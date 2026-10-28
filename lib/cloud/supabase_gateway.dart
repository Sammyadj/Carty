import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/account_gateway.dart';
import '../config/supabase_config.dart';
import 'cloud_workspace.dart';
import 'record_cloud_repository.dart';

class SupabaseGateway implements AccountGateway, CloudWorkspaceRepository {
  SupabaseGateway(this.client);
  final SupabaseClient client;
  late final _records = RecordCloudRepository(
    client,
    requireOwner: _requireOwner,
  );
  static const _timeout = Duration(seconds: 12);

  AccountIdentity? _identity(User? user) => user == null
      ? null
      : AccountIdentity(id: user.id, email: user.email ?? '');
  @override
  AccountIdentity? get currentUser => _identity(client.auth.currentUser);
  @override
  Stream<AccountIdentity?> get authChanges => client.auth.onAuthStateChange.map(
    (state) => _identity(state.session?.user),
  );

  void _requireOwner(String ownerId) {
    if (client.auth.currentUser?.id != ownerId) {
      throw const AccountProblem('Please sign in again before syncing.');
    }
  }

  @override
  Future<void> sendSignInLink(String email) async {
    try {
      await client.auth
          .signInWithOtp(
            email: email,
            shouldCreateUser: true,
            emailRedirectTo: SupabaseConfig.authCallback,
          )
          .timeout(_timeout);
    } on AuthException catch (error) {
      throw AccountProblem(switch (error.code) {
        'email_address_not_authorized' => 'Email sign-in is currently limited to the Carty test team. Continue as a guest or use your team email.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' => 'The email limit has been reached. Please wait before requesting another sign-in link.',
        _ => 'Couldn’t send a sign-in link. Check your email and connection, then try again.',
      });
    }
  }

  @override
  Future<void> signOut() =>
      client.auth.signOut(scope: SignOutScope.local).timeout(_timeout);
  @override
  Future<void> deleteAccount() async {
    await client.rpc('carty_delete_my_account').timeout(_timeout);
  }

  @override
  Future<String> loadDisplayName(String ownerId) async {
    _requireOwner(ownerId);
    final row = await client
        .from('carty_profiles')
        .select('display_name')
        .eq('user_id', ownerId)
        .maybeSingle()
        .timeout(_timeout);
    _requireOwner(ownerId);
    return row?['display_name'] as String? ?? '';
  }

  @override
  Future<void> saveDisplayName(String ownerId, String name) async {
    _requireOwner(ownerId);
    final trimmed = name.trim();
    if (trimmed.length > 60) {
      throw const AccountProblem('Use a name of 60 characters or fewer.');
    }
    await client
        .from('carty_profiles')
        .upsert({
          'user_id': ownerId,
          'display_name': trimmed,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .timeout(_timeout);
    _requireOwner(ownerId);
  }

  @override
  Future<CloudWorkspace?> fetch(String ownerId) => _records.fetch(ownerId);

  @override
  Future<CloudWorkspace?> save(
    String ownerId,
    int expectedRevision,
    String snapshot,
  ) => _records.save(ownerId, expectedRevision, snapshot);
}
