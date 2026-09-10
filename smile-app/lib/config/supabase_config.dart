/// Supabase project connection details.
///
/// The publishable key (not a secret) is safe to ship in the client -- every
/// real access decision is enforced server-side via Postgres RLS policies
/// (see supabase/migrations/0009_rls_helpers_and_policies.sql), not by
/// keeping this key hidden.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://REPLACE_ME.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_REPLACE_ME',
  );
}
