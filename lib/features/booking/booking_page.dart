import 'package:flutter/material.dart';

import '../../shared/widgets/page_shell.dart';
import 'booking_wizard.dart';

/// Standalone booking page (route /book).
class BookingPage extends StatelessWidget {
  const BookingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Онлайн-запись',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text('Выберите услугу, дату и удобное время.',
              style: TextStyle(color: Colors.white70)),
          SizedBox(height: 24),
          BookingWizard(),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}
