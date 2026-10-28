/// Client-safe project settings. Database access is enforced by RLS and RPCs.
abstract final class SupabaseConfig {
  static const authCallback = 'com.samueladjei.carty://auth/callback';
  static bool isAuthCallback(Uri uri) =>
      uri.scheme == 'com.samueladjei.carty' &&
      uri.host == 'auth' &&
      uri.path == '/callback';
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://igytgwdxljbnxfjtufui.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_JMfAE1mc9tZGKHJlgGCvMQ_Sj5t2r2M',
  );
  static const disabled = bool.fromEnvironment('CARTY_CLOUD_DISABLED');
}
