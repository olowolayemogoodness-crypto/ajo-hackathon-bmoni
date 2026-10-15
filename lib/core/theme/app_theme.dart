import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// App-wide type roles that are not represented by Material's [TextTheme].
///
/// Money uses tabular figures so values stay aligned as they update. Sora gives
/// key amounts a distinct, confident display face while Plus Jakarta Sans keeps
/// supporting copy highly legible on small screens.
@immutable
class AppType extends ThemeExtension<AppType> {
  const AppType({
    required this.moneyDisplay,
    required this.moneyHeadline,
    required this.moneyTitle,
    required this.moneyBody,
    required this.moneyCaption,
    required this.code,
    required this.codeInput,
  });

  final TextStyle moneyDisplay;
  final TextStyle moneyHeadline;
  final TextStyle moneyTitle;
  final TextStyle moneyBody;
  final TextStyle moneyCaption;
  final TextStyle code;
  final TextStyle codeInput;

  @override
  AppType copyWith({
    TextStyle? moneyDisplay,
    TextStyle? moneyHeadline,
    TextStyle? moneyTitle,
    TextStyle? moneyBody,
    TextStyle? moneyCaption,
    TextStyle? code,
    TextStyle? codeInput,
  }) {
    return AppType(
      moneyDisplay: moneyDisplay ?? this.moneyDisplay,
      moneyHeadline: moneyHeadline ?? this.moneyHeadline,
      moneyTitle: moneyTitle ?? this.moneyTitle,
      moneyBody: moneyBody ?? this.moneyBody,
      moneyCaption: moneyCaption ?? this.moneyCaption,
      code: code ?? this.code,
      codeInput: codeInput ?? this.codeInput,
    );
  }

  @override
  AppType lerp(covariant AppType? other, double t) {
    if (other == null) return this;
    return AppType(
      moneyDisplay: TextStyle.lerp(moneyDisplay, other.moneyDisplay, t)!,
      moneyHeadline: TextStyle.lerp(moneyHeadline, other.moneyHeadline, t)!,
      moneyTitle: TextStyle.lerp(moneyTitle, other.moneyTitle, t)!,
      moneyBody: TextStyle.lerp(moneyBody, other.moneyBody, t)!,
      moneyCaption: TextStyle.lerp(moneyCaption, other.moneyCaption, t)!,
      code: TextStyle.lerp(code, other.code, t)!,
      codeInput: TextStyle.lerp(codeInput, other.codeInput, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppType get type => Theme.of(this).extension<AppType>()!;
}

class AppTheme {
  AppTheme._();

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );
    final body = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
    final display = GoogleFonts.soraTextTheme(base.textTheme);
    final textTheme = body
        .copyWith(
          displayLarge: display.displayLarge?.copyWith(
            fontSize: 36,
            height: 1.12,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
          displayMedium: display.displayMedium?.copyWith(
            fontSize: 32,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          displaySmall: display.displaySmall?.copyWith(
            fontSize: 28,
            height: 1.18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
          headlineLarge: display.headlineLarge?.copyWith(
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          headlineMedium: display.headlineMedium?.copyWith(
            fontSize: 22,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          headlineSmall: display.headlineSmall?.copyWith(
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleLarge: display.titleLarge?.copyWith(
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          titleMedium: body.titleMedium?.copyWith(
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
          titleSmall: body.titleSmall?.copyWith(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: body.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
          bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
          bodySmall: body.bodySmall?.copyWith(fontSize: 12, height: 1.4),
          labelLarge: body.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          labelMedium: body.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          labelSmall: body.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        )
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    return base.copyWith(
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.ink, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.mintLight,
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : AppColors.muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      extensions: [
        AppType(
          moneyDisplay: GoogleFonts.sora(
            fontSize: 40,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            fontFeatures: _tabular,
          ),
          moneyHeadline: GoogleFonts.sora(
            fontSize: 32,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            fontFeatures: _tabular,
          ),
          moneyTitle: GoogleFonts.sora(
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w700,
            fontFeatures: _tabular,
          ),
          moneyBody: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w700,
            fontFeatures: _tabular,
          ),
          moneyCaption: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w600,
            fontFeatures: _tabular,
          ),
          code: GoogleFonts.sora(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            fontFeatures: _tabular,
          ),
          codeInput: GoogleFonts.sora(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            fontFeatures: _tabular,
          ),
        ),
      ],
    );
  }
}
