import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primaryDark = Color(0xFF05503C);
  static const Color primary = Color(0xFF178A55);
  static const Color mint = Color(0xFF52B788);
  static const Color mintLight = Color(0xFFE3F6EC);
  static const Color lime = Color(0xFF6DBE0F);
  static const Color background = Color(0xFFF7F6FD);
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF1B1F2A);
  static const Color muted = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color warning = Color(0xFFE8693F);
  static const Color warningDark = Color(0xFF9A3412);
  static const Color warningLight = Color(0xFFFDE8E1);

  // Fun accents
  static const Color gold = Color(0xFFF5B83D);
  static const Color goldDark = Color(0xFF7A5200);
  static const Color goldLight = Color(0xFFFFF4D6);
  static const Color purple = Color(0xFF7C5CFC);
  static const Color purpleLight = Color(0xFFEEEAFF);
  static const Color sky = Color(0xFF3B9AE1);
  static const Color skyLight = Color(0xFFE2F1FC);
  static const Color danger = Color(0xFFD64545);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF05503C), Color(0xFF178A55), Color(0xFF3FAE72)],
  );

  static const List<Color> avatarPalette = [
    Color(0xFF178A55),
    Color(0xFF7C5CFC),
    Color(0xFFE8693F),
    Color(0xFF3B9AE1),
    Color(0xFFE05A9A),
    Color(0xFFF5B83D),
    Color(0xFF00A6A6),
    Color(0xFF8A5CF5),
    Color(0xFFD64545),
    Color(0xFF4C6EF5),
  ];
}
