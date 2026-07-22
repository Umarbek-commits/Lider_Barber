import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/env.dart';
import '../core/supabase_client.dart';
import '../data/providers.dart';
import '../features/account/account_page.dart';
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
      final signedIn = Env.hasSupabase && maybeCurrentUser != null;
      final user = ref.read(currentUserProvider).value;

      // Route a signed-in user off the login screen — but only once the role is
      // known, otherwise the redirect races the profile load and staff land in
      // the client cabinet. While the profile loads, stay put; the router
      // re-evaluates when currentUserProvider resolves.
      if (path == '/login' && signedIn && user != null) {
        return user.isStaff ? '/admin' : '/account';
      }

      // Client cabinet: require sign-in; staff belong in the panel.
      if (path == '/account') {
        if (!signedIn) return '/login';
        if (user?.isStaff == true) return '/admin';
      }

      if (!path.startsWith('/admin')) return null;

      // Panel requires a configured backend + staff role (admin or barber).
      if (!signedIn) return '/login';
      // While the profile is still loading, let the page render its own spinner.
      if (user != null && !user.isStaff) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/services', builder: (_, _) => const ServicesPage()),
      GoRoute(
        path: '/book',
        builder: (_, state) =>
            BookingPage(serviceId: state.uri.queryParameters['service']),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/account', builder: (_, _) => const AccountPage()),
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
