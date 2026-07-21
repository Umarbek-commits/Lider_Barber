import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../models/service.dart';
import '../../shared/widgets/page_shell.dart';
import 'booking_wizard.dart';

/// Standalone booking page (route /book). An optional [serviceId] (from the
/// "repeat" action) preselects that service.
class BookingPage extends ConsumerWidget {
  const BookingPage({super.key, this.serviceId});

  final String? serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Service> services = ref.watch(servicesProvider).value ?? const [];
    Service? initial;
    if (serviceId != null) {
      for (final s in services) {
        if (s.id == serviceId) {
          initial = s;
          break;
        }
      }
    }

    return PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Онлайн-запись',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Выберите услугу, дату и удобное время.',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          BookingWizard(initialService: initial),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
