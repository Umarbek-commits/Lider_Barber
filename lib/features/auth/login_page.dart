import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
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
    context.go(user?.isAdmin == true ? '/admin' : '/');
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(backendConfiguredProvider);
    final auth = ref.read(authControllerProvider);

    return PageShell(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(_barberMode ? 'Вход для барбера' : 'Вход',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                _barberMode ? 'По email и паролю.' : 'Войдите через Google-аккаунт.',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              if (!configured)
                const _Notice(
                  'Демо-режим: Supabase не подключён. Задайте SUPABASE_URL и '
                  'SUPABASE_ANON_KEY через env.json.',
                ),
              if (_barberMode) ..._barberFields() else _googleButton(auth),
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
                      : const Text('Войти'),
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
                child: Text(_barberMode ? 'Я клиент — вход через Google' : 'Вход для барбера'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _googleButton(AuthController auth) {
    final configured = ref.read(backendConfiguredProvider);
    return OutlinedButton.icon(
      onPressed: _busy || !configured ? null : () => _run(auth.signInWithGoogle),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: Colors.white24),
      ),
      icon: _busy
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('G', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      label: const Text('Войти через Google'),
    );
  }

  List<Widget> _barberFields() => [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder()),
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
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      );
}
