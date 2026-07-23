import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import 'push_controller.dart';
import 'push_types.dart';

/// Bell icon that enables browser push notifications for the signed-in user.
class PushBell extends ConsumerStatefulWidget {
  const PushBell({super.key});

  @override
  ConsumerState<PushBell> createState() => _PushBellState();
}

class _PushBellState extends ConsumerState<PushBell> {
  bool _busy = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    final status = await ref.read(pushControllerProvider).enable();
    if (!mounted) return;
    setState(() => _busy = false);
    final msg = switch (status) {
      PushStatus.granted => 'Уведомления включены',
      PushStatus.denied => 'Разрешите уведомления в браузере',
      PushStatus.unsupported => 'Браузер не поддерживает уведомления',
      PushStatus.error => 'Не удалось включить уведомления',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.read(pushControllerProvider).available) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Уведомления',
      onPressed: _busy ? null : _enable,
      icon: _busy
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.notifications_active_outlined, color: AppColors.gold, size: 22),
    );
  }
}
