import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/page_shell.dart';
import '../../shared/widgets/skeleton.dart';

/// Standalone services page (SEO route /services).
class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final t = ref.watch(tProvider);
    return PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.ourServices, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text(t.servicesSubtitle, style: TextStyle(color: context.muted)),
          const SizedBox(height: 24),
          services.when(
            loading: () => const SkeletonList(count: 4, cardHeight: 72),
            error: (e, _) => Text(t.error(e)),
            data: (list) => Column(
              children: list
                  .map((s) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: context.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.border),
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
                                  SizedBox(height: 4),
                                  Text('${s.durationMin} ${t.minutesShort}',
                                      style: TextStyle(color: context.faint)),
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
          SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/book'),
            icon: const Icon(Icons.calendar_today_rounded),
            label: Text(t.bookAction),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
