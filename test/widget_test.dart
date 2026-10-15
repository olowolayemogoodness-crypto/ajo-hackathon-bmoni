import 'package:ajo/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home exposes the private reminder and contribution ledger', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(onGoTo: (_) {})),
      ),
    );

    expect(find.text('Private reminder'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Contribution ledger'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Contribution ledger'), findsOneWidget);
    expect(find.text('Overdue'), findsWidgets);

    // Reveal animations use short delayed timers; drain them before teardown.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
