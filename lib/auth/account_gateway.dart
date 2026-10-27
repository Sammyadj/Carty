class AccountIdentity {
  const AccountIdentity({required this.id, required this.email});
  final String id;
  final String email;
}

class AccountProblem implements Exception {
  const AccountProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class AccountGateway {
  AccountIdentity? get currentUser;
  Stream<AccountIdentity?> get authChanges;
  Future<void> sendSignInLink(String email);
  Future<String> loadDisplayName(String ownerId);
  Future<void> saveDisplayName(String ownerId, String name);
  Future<void> signOut();
  Future<void> deleteAccount();
}
