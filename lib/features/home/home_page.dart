import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/page_shell.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 760;
    final t = ref.watch(tProvider);

    return PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(context, t, isMobile),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, T t, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.headerTop, AppColors.headerBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(BusinessInfo.name,
              style: TextStyle(fontSize: isMobile ? 30 : 40, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(t.heroSubtitle, style: const TextStyle(fontSize: 18, color: AppColors.gold)),
          const SizedBox(height: 12),
          Text(t.heroText, style: const TextStyle(height: 1.6, color: Colors.white70)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(label: '📍 ${BusinessInfo.addressLabel}', url: BusinessInfo.mapUrl),
              _InfoChip(label: '📸 ${BusinessInfo.instagramHandle}', url: BusinessInfo.instagramUrl),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/book'),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(t.bookOnline),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.url});
  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
    if (url == null) return chip;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
      child: chip,
    );
  }
}
