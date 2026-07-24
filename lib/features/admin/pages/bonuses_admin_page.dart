import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/admin_providers.dart';
import '../../../data/providers.dart';

/// Admin: set the cashback percent credited on completed visits.
class BonusesAdminPage extends ConsumerWidget {
  const BonusesAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pct = ref.watch(cashbackPctProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Бонусы')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Кэшбэк — процент от суммы визита, который начисляется '
              'клиенту бонусами (сомами). Бонусы видны клиенту в кабинете.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          pct.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Ошибка: $e'),
            data: (value) => _Editor(initial: value),
          ),
        ],
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.initial});
  final int initial;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late int _pct = widget.initial;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Кэшбэк', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _pct > 0 ? () => setState(() => _pct--) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Center(
                  child: Text('$_pct%',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.gold)),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _pct < 50 ? () => setState(() => _pct++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy || _pct == widget.initial
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await ref.read(adminRepositoryProvider).setCashbackPct(_pct);
                      ref.invalidate(cashbackPctProvider);
                      ref.invalidate(publicCashbackPctProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Сохранено')));
                        setState(() => _busy = false);
                      }
                    },
              child: const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}
