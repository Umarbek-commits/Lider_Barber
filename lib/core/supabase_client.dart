import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Initializes the Supabase client once at startup.
///
/// Safe to call when keys are missing: it simply no-ops so the app can be
/// browsed as a static prototype without a backend.
Future<void> initSupabase() async {
  if (!Env.hasSupabase) return;
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // Accepts the new `sb_publishable_...` key or a legacy anon JWT.
    publishableKey: Env.supabaseAnonKey,
  );
}

/// Convenience accessor. Throws if used before [initSupabase] with valid keys.
SupabaseClient get supabase => Supabase.instance.client;

/// The current auth user, or null when Supabase isn't initialized yet (e.g. in
/// widget tests). Never throws — safe to call from router redirects.
User? get maybeCurrentUser {
  try {
    return Supabase.instance.client.auth.currentUser;
  } catch (_) {
    return null;
  }
}
