/// Supabase project connection details for Smile-Frame's own Edge Function
/// calls (claim-frame-pairing, refresh-frame-token, get-media-batch,
/// submit-heartbeat -- all unauthenticated at the gateway level; the
/// pairing code or frame_id+refresh_secret pair IS the authorization,
/// checked inside each function against the database).
class BackendConfig {
  /// No server call may hang (2026-10-09): a request cut off by a network
  /// drop (airplane mode, WLAN switch) otherwise waited minutes for TCP,
  /// and with one sync at a time every later sync waited behind it -- the
  /// Frame stayed "offline" long after the WLAN was back.
  static const requestTimeout = Duration(seconds: 30);

  /// For downloads: the longest pause between two chunks, not the whole
  /// transfer (an hour-long video may take longer than that in total).
  static const downloadStallTimeout = Duration(seconds: 60);

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://REPLACE_ME.supabase.co',
  );

  static String functionUrl(String functionName) => '$supabaseUrl/functions/v1/$functionName';
}
