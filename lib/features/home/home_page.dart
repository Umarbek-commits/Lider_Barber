import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../../models/service.dart';
import '../booking/booking_wizard.dart';
import '../../shared/widgets/page_shell.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 760;
    final services = ref.watch(servicesProvider);
    final t = ref.watch(tProvider);

    return PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hero(context, t, isMobile),
          const SizedBox(height: 40),
          _SectionTitle(t.servicesTitle),
          const SizedBox(height: 16),
          services.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(t.error(e)),
            data: (list) => _servicesGrid(list, t, isMobile),
          ),
          const SizedBox(height: 40),
          _SectionTitle(t.onlineBooking),
          const SizedBox(height: 16),
          const BookingWizard(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, T t, bool isMobile) {
    final hero = Container(
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
    return hero;
  }

  Widget _servicesGrid(List<Service> list, T t, bool isMobile) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: list.map((s) {
        return Container(
          width: isMobile ? double.infinity : 260,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(s.priceLabel,
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(t.durationLabel(s.durationMin),
                  style: const TextStyle(color: Colors.white60)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700));
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
