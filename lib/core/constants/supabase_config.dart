class SupabaseConfig {
  // Real Live Supabase Project Credentials
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kybfnanettmqkmutjced.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_uEvX5HGb6XjUBm5PKlv4OA_hu1NIUei',
  );
}
