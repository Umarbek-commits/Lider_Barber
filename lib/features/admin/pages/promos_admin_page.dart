import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/admin_providers.dart';
import '../../../data/providers.dart';
import '../../../models/promo_code.dart';
import '../../../shared/widgets/skeleton.dart';

/// Admin: create / toggle / delete сом-discount promo codes.
class PromosAdminPage extends ConsumerWidget {
  const PromosAdminPage({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminPromoCodesProvider);
    ref.invalidate(activePromosProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promos = ref.watch(adminPromoCodesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Промокоды')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showDialog<bool>(context: context, builder: (_) => const _AddPromoDialog());
          if (ok == true) _refresh(ref);
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Промокод даёт скидку в сомах. Клиент вводит его при записи.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          promos.when(
            loading: () => const SkeletonList(count: 3, cardHeight: 60),
            error: (e, _) => Text('Ошибка: $e'),
            data: (list) => list.isEmpty
                ? const Text('Промокодов пока нет', style: TextStyle(color: Colors.grey))
                : Column(children: list.map((p) => _PromoRow(promo: p, onChanged: () => _refresh(ref))).toList()),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _PromoRow extends ConsumerWidget {
  const _PromoRow({required this.promo, required this.onChanged});
  final PromoCode promo;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: promo.isActive ? AppColors.gold.withValues(alpha: 0.4) : context.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(promo.code,
                    style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                Text('−${promo.discountSom} сом',
                    style: TextStyle(color: context.faint, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: promo.isActive,
            onChanged: (v) async {
              await ref.read(adminRepositoryProvider).setPromoActive(promo.id, v);
              onChanged();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () async {
              await ref.read(adminRepositoryProvider).deletePromo(promo.id);
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _AddPromoDialog extends ConsumerStatefulWidget {
  const _AddPromoDialog();

  @override
  ConsumerState<_AddPromoDialog> createState() => _AddPromoDialogState();
}

class _AddPromoDialogState extends ConsumerState<_AddPromoDialog> {
  final _code = TextEditingController();
  final _discount = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _discount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('Новый промокод'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Код (напр. SUMMER)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _discount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Скидка, сом'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Создать'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final discount = int.tryParse(_discount.text.trim());
    if (_code.text.trim().isEmpty || discount == null || discount <= 0) {
      setState(() => _error = 'Введите код и скидку (число сом)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).addPromo(_code.text, discount);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().toLowerCase().contains('duplicate')
            ? 'Такой код уже есть'
            : 'Ошибка: $e';
      });
    }
  }
}
