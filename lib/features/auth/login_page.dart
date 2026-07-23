import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/page_shell.dart';
import 'auth_controller.dart';

/// Login. Two paths:
///  * Client — Google account (no SMS provider needed).
///  * Barber — email + password (promote its role to admin in SQL).
/// Role-based redirect after login is handled here and by the router.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _barberMode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// After a successful sign-in, route by role: admins → panel, others → home.
  Future<void> _goAfterLogin() async {
    final user = await ref.refresh(currentUserProvider.future);
    if (!mounted) return;
    context.go(user?.isAdmin == true ? '/admin' : '/account');
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(backendConfiguredProvider);
    final auth = ref.read(authControllerProvider);
    final t = ref.watch(tProvider);

    return PageShell(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(_barberMode ? t.barberLogin : t.login,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text(
                _barberMode ? t.barberLoginSubtitle : t.loginGoogleSubtitle,
                style: TextStyle(color: context.muted),
              ),
              const SizedBox(height: 24),
              if (!configured)
                const _Notice(
                  'Демо-режим: Supabase не подключён. Задайте SUPABASE_URL и '
                  'SUPABASE_ANON_KEY через env.json.',
                ),
              if (_barberMode) ..._barberFields(t) else _googleButton(auth, t),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              if (_barberMode) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy || !configured
                      ? null
                      : () => _run(() async {
                            await auth.signInWithEmail(
                              email: _emailCtrl.text.trim(),
                              password: _passwordCtrl.text,
                            );
                            await _goAfterLogin();
                          }),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : Text(t.signIn),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _barberMode = !_barberMode;
                          _error = null;
                        }),
                child: Text(_barberMode ? t.iAmClient : t.barberLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _googleButton(AuthController auth, T t) {
    final configured = ref.read(backendConfiguredProvider);
    return OutlinedButton.icon(
      onPressed: _busy || !configured ? null : () => _run(auth.signInWithGoogle),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: context.border),
      ),
      icon: _busy
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('G', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      label: Text(t.signInGoogle),
    );
  }

  List<Widget> _barberFields(T t) => [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: t.email, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: InputDecoration(labelText: t.password, border: const OutlineInputBorder()),
        ),
      ];
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.border,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: TextStyle(color: context.muted, fontSize: 13)),
      );
}
