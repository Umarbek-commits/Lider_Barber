import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/env.dart';
import '../core/supabase_client.dart';
import '../data/providers.dart';
import '../features/admin/admin_shell.dart';
import '../features/auth/login_page.dart';
import '../features/booking/booking_page.dart';
import '../features/home/home_page.dart';
import '../features/services/services_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    // Rebuild redirects whenever auth changes.
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final path = state.uri.path;
      final signedIn = Env.hasSupabase && supabase.auth.currentUser != null;
      final user = ref.read(currentUserProvider).value;

      // Don't leave an already-signed-in user sitting on the login screen
      // (covers the OAuth redirect returning to the app).
      if (path == '/login' && signedIn) {
        return user?.isAdmin == true ? '/admin' : '/';
      }

      if (!path.startsWith('/admin')) return null;

      // Admin area requires a configured backend + admin role.
      if (!signedIn) return '/login';
      // While the profile is still loading, let the page render its own spinner.
      if (user != null && !user.isAdmin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/services', builder: (_, _) => const ServicesPage()),
      GoRoute(path: '/book', builder: (_, _) => const BookingPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminShell()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Страница не найдена: ${state.uri}')),
    ),
  );
});

/// Bridges Riverpod auth changes to go_router's redirect re-evaluation.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentUserProvider, (_, _) => notifyListeners());
  }
}
