import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/admin_providers.dart';
import '../../../data/providers.dart';
import '../../../models/service.dart';
import '../../../shared/widgets/skeleton.dart';

/// Admin: add / edit / activate / delete services and prices.
class ServicesAdminPage extends ConsumerWidget {
  const ServicesAdminPage({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminServicesProvider);
    ref.invalidate(servicesProvider); // client-facing list
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(adminServicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Услуги')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showDialog<bool>(
              context: context, builder: (_) => const _ServiceDialog());
          if (ok == true) _refresh(ref);
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Цены и услуги, которые видят клиенты. Выключенные скрыты.',
              style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          services.when(
            loading: () => const SkeletonList(count: 4, cardHeight: 64),
            error: (e, _) => Text('Ошибка: $e'),
            data: (list) => list.isEmpty
                ? const Text('Услуг пока нет', style: TextStyle(color: Colors.white60))
                : Column(
                    children: list
                        .map((s) => _ServiceRow(
                              service: s,
                              onEdit: () async {
                                final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => _ServiceDialog(service: s));
                                if (ok == true) _refresh(ref);
                              },
                              onToggle: (v) async {
                                await ref.read(adminRepositoryProvider).setServiceActive(s.id, v);
                                _refresh(ref);
                              },
                              onDelete: () async {
                                try {
                                  await ref.read(adminRepositoryProvider).deleteService(s.id);
                                  _refresh(ref);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                        content: Text(
                                            'Услугу нельзя удалить — по ней есть записи. Выключите её.')));
                                  }
                                }
                              },
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final Service service;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: service.isActive ? Colors.white12 : Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Opacity(
              opacity: service.isActive ? 1 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${service.priceSom} сом • ${service.durationMin} мин',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ),
          Switch(value: service.isActive, onChanged: onToggle),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: Colors.white70)),
          IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
        ],
      ),
    );
  }
}

class _ServiceDialog extends ConsumerStatefulWidget {
  const _ServiceDialog({this.service});
  final Service? service;

  @override
  ConsumerState<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends ConsumerState<_ServiceDialog> {
  late final _name = TextEditingController(text: widget.service?.name ?? '');
  late final _price =
      TextEditingController(text: widget.service?.priceSom.toString() ?? '');
  late final _duration =
      TextEditingController(text: widget.service?.durationMin.toString() ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.service != null;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(editing ? 'Изменить услугу' : 'Новая услуга'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Название')),
            const SizedBox(height: 10),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Цена, сом'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Длительность, мин'),
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
              : const Text('Сохранить'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final price = int.tryParse(_price.text.trim());
    final duration = int.tryParse(_duration.text.trim());
    if (_name.text.trim().isEmpty || price == null || duration == null || duration <= 0) {
      setState(() => _error = 'Заполните название, цену и длительность (число минут)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).saveService(
            id: widget.service?.id,
            name: _name.text.trim(),
            priceSom: price,
            durationMin: duration,
            isActive: widget.service?.isActive ?? true,
            sortOrder: widget.service?.sortOrder,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Ошибка: $e';
      });
    }
  }
}
