import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lider_barber/main.dart';

void main() {
  testWidgets('App launches and shows the brand name', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LiderBarberApp()));
    await tester.pump(); // let the first async providers settle
    expect(find.text('Lider Barber'), findsWidgets);
  });
}
