/// Supabase project connection details for Smile-Frame's own Edge Function
/// calls (request-device-pairing, poll-device-pairing, refresh-device-token
/// -- all unauthenticated at the gateway level; the device_id+code or
/// device_id+refresh_secret pair IS the authorization, checked inside each
/// function against the database).
class BackendConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://REPLACE_ME.supabase.co',
  );

  static String functionUrl(String functionName) => '$supabaseUrl/functions/v1/$functionName';
}
