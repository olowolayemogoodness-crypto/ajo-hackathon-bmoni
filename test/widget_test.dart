import 'package:ajo/app.dart';
import 'package:ajo/core/theme/app_colors.dart';
import 'package:ajo/core/theme/app_theme.dart';
import 'package:ajo/core/widgets/status_chip.dart';
import 'package:ajo/features/circles/presentation/create_circle_screen.dart';
import 'package:ajo/features/circles/presentation/join_circle_screen.dart';
import 'package:ajo/features/friends/presentation/friends_screen.dart';
import 'package:ajo/features/home/presentation/home_screen.dart';
import 'package:ajo/features/my_turn/presentation/my_turn_screen.dart';
import 'package:ajo/features/pay/presentation/pay_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the branded splash on a phone-sized viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AjoApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Image), findsOneWidget);
    expect(
      find.text('Save together. Know where everyone stands.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses paired fonts, tabular money, and labelled status icons', (
    WidgetTester tester,
  ) async {
    final theme = AppTheme.light;
    final appType = theme.extension<AppType>()!;

    expect(
      theme.textTheme.bodyMedium?.fontFamily,
      startsWith('PlusJakartaSans'),
    );
    expect(theme.textTheme.headlineLarge?.fontFamily, startsWith('Sora'));
    expect(appType.moneyDisplay.fontFeatures, isNotEmpty);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Center(
            child: StatusChip(
              label: 'Paid',
              color: AppColors.primaryDark,
              background: AppColors.mintLight,
              icon: Icons.check_circle_rounded,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Paid'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('key savings flows fit a phone-sized viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final screens = <Widget>[
      HomeScreen(onGoTo: (_) {}),
      const MyTurnScreen(),
      const FriendsScreen(),
      const CreateCircleScreen(),
      const JoinCircleScreen(),
      const PayScreen(),
    ];

    for (final screen in screens) {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: '${screen.runtimeType}');
    }
  });
}
