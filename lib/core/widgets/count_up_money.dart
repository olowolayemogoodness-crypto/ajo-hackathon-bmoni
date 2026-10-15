import 'package:flutter/material.dart';

import '../utils/money.dart';

class CountUpMoney extends StatelessWidget {
  const CountUpMoney({super.key, required this.kobo, required this.style});

  final int kobo;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: kobo.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final shown = (v / 100).round() * 100;
        return Text(Money.fmt(shown), style: style);
      },
    );
  }
}
