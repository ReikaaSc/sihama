class SupabaseConfig {
  const SupabaseConfig._();

  // These are public client settings; database access must still be protected by RLS.
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qewazcbfucnlpmcwktez.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_6cmf4jRuyAY84oLdC9Jxiw_N2-SBHpq',
  );
}
