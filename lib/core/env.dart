/// Runtime configuration for Supabase.
///
/// The values below are the PUBLIC project URL and the `anon` (publishable)
/// key. These are safe to ship in a client app — a Flutter Web bundle is fully
/// public, and access is protected by Row Level Security, not by hiding the key.
///
/// The SECRET (`service_role`) key must NEVER appear here — it bypasses RLS and
/// belongs only in server-side Edge Functions.
///
/// A `--dart-define` (e.g. via env.json) overrides the baked-in default, so a
/// different environment can be targeted without editing this file:
///   flutter run --dart-define-from-file=env.json
class Env {
  const Env._();

  static const String _defaultUrl = 'https://pyobqtshoihrncdlqkjj.supabase.co';
  static const String _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB5b2JxdHNob2locm5jZGxxa2pqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2MDQzODIsImV4cCI6MjEwMDE4MDM4Mn0.7_iY9wgId3qlOVA9XE8N9-KOKdXH07jgk1OBTsfKptY';

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultUrl);

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: _defaultAnonKey);

  /// True when both values are present (always true with the baked defaults).
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Web Push VAPID public key (safe to ship). The private key stays a Supabase
  /// Edge Function secret and is never in the app.
  static const String vapidPublicKey = String.fromEnvironment(
    'VAPID_PUBLIC_KEY',
    defaultValue:
        'BDTowFRfRCDCzpX-ItRhnbBRq4Ij7BGr5mmW4BT0m-46rcaHIq48k0PMYwUjWueZXtC1kxCZdSJ_4XmKDJyk3X4',
  );

  static bool get hasPush => vapidPublicKey.isNotEmpty;
}
