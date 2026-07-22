import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/admin_providers.dart';
import '../../../models/client.dart';
import '../../../shared/widgets/skeleton.dart';

class ClientsTab extends ConsumerStatefulWidget {
  const ClientsTab({super.key});

  @override
  ConsumerState<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends ConsumerState<ClientsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(adminClientsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Клиенты', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Поиск по имени или телефону',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: clients.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(20), child: SkeletonList(count: 6, cardHeight: 64)),
            error: (e, _) => Center(child: Text('Ошибка: $e')),
            data: (list) {
              final filtered = _query.isEmpty
                  ? list
                  : list
                      .where((c) =>
                          c.name.toLowerCase().contains(_query) || c.phone.contains(_query))
                      .toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('Ничего не найдено', style: TextStyle(color: Colors.white60)));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ClientRow(
                  client: filtered[i],
                  onTap: () => _openCard(filtered[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openCard(Client c) async {
    await showDialog(context: context, builder: (_) => _ClientCard(client: c));
    ref.invalidate(adminClientsProvider);
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.client, required this.onTap});
  final Client client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: client.isBlacklisted ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(client.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (client.isBlacklisted) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.block, size: 16, color: Colors.redAccent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(client.phone, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${client.visitsCount} визитов', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                if (client.lastVisit != null)
                  Text(DateFormat('d.MM.yy').format(client.lastVisit!),
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientCard extends ConsumerWidget {
  const _ClientCard({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(clientBookingsProvider(client.id));
    final staffNames = ref.watch(staffNamesProvider).value ?? const <String, String>{};
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(client.name),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(client.phone, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _mini('Визитов', '${client.visitsCount}'),
                  const SizedBox(width: 20),
                  _mini('Потрачено', '${client.totalSpent} сом'),
                ],
              ),
              const Divider(height: 28),
              if (client.isBlacklisted)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('В чёрном списке: ${client.blacklistReason ?? '—'}',
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              const SizedBox(height: 12),
              const Text('История', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              history.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Ошибка: $e'),
                data: (list) => list.isEmpty
                    ? const Text('Записей нет', style: TextStyle(color: Colors.white60))
                    : Column(
                        children: list.map((b) {
                          final master =
                              b.acceptedBy == null ? null : staffNames[b.acceptedBy];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${DateFormat('d.MM.yy').format(b.bookingDate)} ${b.startTime} • ${b.serviceName ?? ''}',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      if (master != null)
                                        Text('Мастер: $master',
                                            style: const TextStyle(
                                                color: AppColors.gold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text(b.status.label,
                                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (client.isBlacklisted)
          TextButton(
            onPressed: () async {
              await ref.read(adminRepositoryProvider).setBlacklist(client.id, false, null);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Убрать из ЧС'),
          )
        else
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => _blacklist(context, ref),
            child: const Text('В чёрный список'),
          ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
      ],
    );
  }

  Future<void> _blacklist(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Причина'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'не пришёл / постоянно отменяет'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, reasonCtrl.text.trim()),
              child: const Text('В ЧС')),
        ],
      ),
    );
    if (reason == null) return;
    await ref.read(adminRepositoryProvider).setBlacklist(client.id, true, reason.isEmpty ? null : reason);
    if (context.mounted) Navigator.pop(context);
  }

  Widget _mini(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.gold)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      );
}
