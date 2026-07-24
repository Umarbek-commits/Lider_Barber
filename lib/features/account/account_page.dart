import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../auth/auth_controller.dart';
import '../push/push_button.dart';
import '../../shared/widgets/page_shell.dart';
import 'pages/my_bonuses_page.dart';
import 'pages/my_bookings_page.dart';
import 'pages/promos_page.dart';

/// Client cabinet — a menu; each item opens its own page.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final user = ref.watch(currentUserProvider).value;

    final items = <_AccItem>[
      _AccItem(Icons.event_note_rounded, t.myBookings, const MyBookingsPage()),
      _AccItem(Icons.card_giftcard_rounded, t.myBonuses, const MyBonusesPage()),
      _AccItem(Icons.local_offer_rounded, t.promos, const PromosPage()),
    ];

    return PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.cabinet,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              ),
              const PushBell(),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(authControllerProvider).signOut();
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(t.signOut),
              ),
            ],
          ),
          if (user != null)
            Text(user.name ?? user.phone, style: TextStyle(color: context.faint)),
          const SizedBox(height: 20),
          ...items.map((it) => _AccRow(item: it)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _AccItem {
  const _AccItem(this.icon, this.title, this.page);
  final IconData icon;
  final String title;
  final Widget page;
}

class _AccRow extends StatelessWidget {
  const _AccRow({required this.item});
  final _AccItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.gold.withValues(alpha: 0.15),
          child: Icon(item.icon, color: AppColors.gold, size: 20),
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Icon(Icons.chevron_right, color: context.fainter),
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.page)),
      ),
    );
  }
}
