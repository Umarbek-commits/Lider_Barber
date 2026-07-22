import 'package:flutter/material.dart';

import '../tabs/masters_section.dart';

class MastersPage extends StatelessWidget {
  const MastersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мастера')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: MastersSection(),
      ),
    );
  }
}
