import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/admin_providers.dart';
import '../../../models/app_user.dart';
import '../../../shared/widgets/skeleton.dart';

/// Admin-only: add/list the shop's barbers. Barbers log in with the email +
/// password set here and get panel access (accept/serve bookings).
class MastersSection extends ConsumerWidget {
  const MastersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barbers = ref.watch(adminBarbersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('Барберы входят по email и паролю и принимают записи.',
                  style: TextStyle(color: Colors.white60)),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Добавить'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        barbers.when(
          loading: () => const SkeletonList(count: 2, cardHeight: 56),
          error: (e, _) => Text('Ошибка: $e'),
          data: (list) => list.isEmpty
              ? const Text('Мастеров пока нет.', style: TextStyle(color: Colors.white60))
              : Column(
                  children: list
                      .map((b) => _BarberRow(
                            barber: b,
                            onRemove: () async {
                              await ref.read(adminRepositoryProvider).removeBarber(b.id);
                              ref.invalidate(adminBarbersProvider);
                              ref.invalidate(staffNamesProvider);
                            },
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final added = await showDialog<bool>(context: context, builder: (_) => const _AddBarberDialog());
    if (added == true) {
      ref.invalidate(adminBarbersProvider);
      ref.invalidate(staffNamesProvider);
    }
  }
}

class _BarberRow extends StatelessWidget {
  const _BarberRow({required this.barber, required this.onRemove});
  final AppUser barber;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF262626),
            child: Icon(Icons.content_cut, size: 16, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(barber.name ?? 'Мастер', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(barber.phone, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.person_remove_alt_1, color: Colors.redAccent),
            tooltip: 'Убрать',
          ),
        ],
      ),
    );
  }
}

class _AddBarberDialog extends ConsumerStatefulWidget {
  const _AddBarberDialog();

  @override
  ConsumerState<_AddBarberDialog> createState() => _AddBarberDialogState();
}

class _AddBarberDialogState extends ConsumerState<_AddBarberDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Добавить мастера'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Сначала создайте аккаунт мастера в Supabase → Authentication → '
                'Users → Add user (email + пароль, галочка Auto Confirm). Потом '
                'введите этот email здесь.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Имя мастера')),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (как в Supabase)'),
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
              : const Text('Добавить'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      setState(() => _error = 'Введите имя и email');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await ref
          .read(adminRepositoryProvider)
          .addBarberByEmail(name: _name.text, email: _email.text);
      if (!ok) {
        setState(() {
          _busy = false;
          _error = 'Аккаунт с таким email не найден. Сначала создайте его в Supabase → Users.';
        });
        return;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Ошибка: $e';
      });
    }
  }
}
