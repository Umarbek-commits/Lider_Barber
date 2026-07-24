import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/providers.dart';
import '../../../l10n/l10n.dart';

/// Active promo codes the client can use at booking.
class PromosPage extends ConsumerWidget {
  const PromosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final promos = ref.watch(activePromosProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.promos)),
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: context.surface,
        onRefresh: () async {
          ref.invalidate(activePromosProvider);
          await ref.read(activePromosProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            promos.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text(t.error(e)),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(t.noPromos, style: TextStyle(color: context.muted)),
                    )
                  : Column(
                      children: list
                          .map((p) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: context.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_offer_rounded,
                                        color: AppColors.gold, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.code,
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1)),
                                          Text('Скидка ${p.discountSom} сом',
                                              style: TextStyle(color: context.faint, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    Text('−${p.discountSom}',
                                        style: const TextStyle(
                                            color: AppColors.gold,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
