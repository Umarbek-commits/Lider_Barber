import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../data/providers.dart';
import '../../../l10n/l10n.dart';

/// Client's bonus balance + penalties.
class MyBonusesPage extends ConsumerWidget {
  const MyBonusesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final data = ref.watch(myBonusesProvider);
    final pct = ref.watch(publicCashbackPctProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(t.myBonuses)),
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: context.surface,
        onRefresh: () async {
          ref.invalidate(myBonusesProvider);
          await ref.read(myBonusesProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            data.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text(t.error(e)),
              data: (v) => Column(
                children: [
                  _BalanceCard(
                    icon: Icons.card_giftcard_rounded,
                    label: t.bonusesLabel,
                    value: '${v.bonus} сом',
                    color: AppColors.gold,
                    hint: pct > 0 ? t.cashbackInfo(pct) : null,
                  ),
                  const SizedBox(height: 12),
                  if (v.penalty > 0)
                    _BalanceCard(
                      icon: Icons.warning_amber_rounded,
                      label: t.penaltiesLabel,
                      value: '${v.penalty} сом',
                      color: Colors.redAccent,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.hint,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: context.faint, fontSize: 13)),
                  Text(value,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
                ],
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 10),
            Text(hint!, style: TextStyle(color: context.muted, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
