import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Full import (no `show`): signInWithOAuth is an extension method that must be
// in scope, which a member-limited `show` would hide.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/supabase_client.dart';

final authControllerProvider = Provider<AuthController>((_) => AuthController());

/// Thin wrapper around Supabase phone OTP auth.
///
/// Requires an SMS provider to be configured in the Supabase dashboard
/// (Auth → Providers → Phone). Until then these calls will fail with a
/// descriptive error surfaced to the UI.
class AuthController {
  bool get isConfigured => Env.hasSupabase;

  /// Send a one-time code to [phone] (E.164, e.g. +996555123456).
  Future<void> sendOtp(String phone) async {
    _ensure();
    await supabase.auth.signInWithOtp(phone: phone);
  }

  /// Verify the [token] the user received for [phone].
  Future<void> verifyOtp({required String phone, required String token}) async {
    _ensure();
    await supabase.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  /// Client login via Google. On web this redirects the whole page to Google
  /// and back to the app origin, so the session is restored on return (no
  /// in-app navigation happens here). Requires the Google provider to be
  /// enabled in Supabase → Auth → Providers.
  Future<void> signInWithGoogle() async {
    _ensure();
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : null,
    );
  }

  /// Barber login by email + password. Works out of the box (no SMS provider):
  /// create the admin user in Supabase → Auth → Users, then promote its role
  /// to 'admin' via SQL. Client-facing SMS OTP can be enabled later.
  Future<void> signInWithEmail({required String email, required String password}) async {
    _ensure();
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    await supabase.auth.signOut();
  }

  void _ensure() {
    if (!isConfigured) {
      throw StateError('Supabase не настроен: задайте SUPABASE_URL и SUPABASE_ANON_KEY.');
    }
  }
}
