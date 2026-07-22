import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../data/admin_providers.dart';
import '../../../data/providers.dart';
import '../../../models/news_item.dart';
import '../../../shared/widgets/skeleton.dart';

/// Admin news management. Active items show to all clients on the home screen.
class NewsPage extends ConsumerWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = ref.watch(adminNewsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Новости')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Объявления видят все клиенты на главной. Выключенные — скрыты.',
              style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          news.when(
            loading: () => const SkeletonList(count: 3, cardHeight: 72),
            error: (e, _) => Text('Ошибка: $e'),
            data: (list) => list.isEmpty
                ? const Text('Объявлений пока нет', style: TextStyle(color: Colors.white60))
                : Column(
                    children: list.map((n) => _NewsRow(item: n)).toList(),
                  ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Новое объявление'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Например: Каждая 3-я стрижка бесплатно!',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Опубликовать'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    await ref.read(adminRepositoryProvider).addNews(text);
    ref.invalidate(adminNewsProvider);
    ref.invalidate(newsProvider);
  }
}

class _NewsRow extends ConsumerWidget {
  const _NewsRow({required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.isActive ? AppColors.gold.withValues(alpha: 0.4) : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.text),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(DateFormat('d.MM.yy').format(item.createdAt),
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const Spacer(),
              Text(item.isActive ? 'Показывается' : 'Скрыто',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Switch(
                value: item.isActive,
                onChanged: (v) async {
                  await ref.read(adminRepositoryProvider).setNewsActive(item.id, v);
                  ref.invalidate(adminNewsProvider);
                  ref.invalidate(newsProvider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async {
                  await ref.read(adminRepositoryProvider).deleteNews(item.id);
                  ref.invalidate(adminNewsProvider);
                  ref.invalidate(newsProvider);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
