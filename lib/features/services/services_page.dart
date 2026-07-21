import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../shared/widgets/page_shell.dart';

/// Standalone services page (SEO route /services).
class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    return PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Наши услуги',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Цены и длительность. Онлайн-запись — в один клик.',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          services.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Ошибка загрузки: $e'),
            data: (list) => Column(
              children: list
                  .map((s) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name,
                                      style: const TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text('${s.durationMin} мин',
                                      style: const TextStyle(color: Colors.white60)),
                                ],
                              ),
                            ),
                            Text(s.priceLabel,
                                style: const TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/book'),
            icon: const Icon(Icons.calendar_today_rounded),
            label: const Text('Записаться'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
