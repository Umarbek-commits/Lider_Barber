import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await initSupabase(); // no-op when keys aren't provided
  runApp(const ProviderScope(child: LiderBarberApp()));
}

class LiderBarberApp extends ConsumerWidget {
  const LiderBarberApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Lider Barber',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
