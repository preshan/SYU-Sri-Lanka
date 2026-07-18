import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SYU brand tokens — crimson fist on near-black.
class SyuColors {
  SyuColors._();

  static const Color crimson = Color(0xFFE10600);
  static const Color crimsonDeep = Color(0xFFB00000);
  static const Color crimsonSoft = Color(0xFFFF4D45);
  static const Color ink = Color(0xFF0A0A0A);
  static const Color inkElevated = Color(0xFF141414);
  static const Color inkSoft = Color(0xFF1C1C1C);
  static const Color steel = Color(0xFF8A8A8A);
  static const Color mist = Color(0xFFBDBDBD);
  static const Color paper = Color(0xFFF5F5F5);
  static const Color success = Color(0xFF2BB673);
  static const Color warning = Color(0xFFF5A524);
  static const Color danger = Color(0xFFFF5C5C);
}

class SyuTheme {
  SyuTheme._();

  static ThemeData dark() {
    final baseText = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);
    final display = GoogleFonts.bebasNeueTextTheme(ThemeData.dark().textTheme);

    final scheme = const ColorScheme.dark(
      primary: SyuColors.crimson,
      onPrimary: SyuColors.paper,
      primaryContainer: SyuColors.crimsonDeep,
      onPrimaryContainer: SyuColors.paper,
      secondary: SyuColors.mist,
      onSecondary: SyuColors.ink,
      surface: SyuColors.ink,
      onSurface: SyuColors.paper,
      surfaceContainerHighest: SyuColors.inkSoft,
      error: SyuColors.danger,
      onError: SyuColors.paper,
      outline: Color(0xFF2A2A2A),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: SyuColors.ink,
      textTheme: baseText.copyWith(
        displayLarge: display.displayLarge?.copyWith(
          color: SyuColors.paper,
          letterSpacing: 1.2,
        ),
        displayMedium: display.displayMedium?.copyWith(
          color: SyuColors.paper,
          letterSpacing: 1.0,
        ),
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: SyuColors.paper,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: SyuColors.paper,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: SyuColors.paper,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(color: SyuColors.paper),
        bodyMedium: baseText.bodyMedium?.copyWith(color: SyuColors.mist),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: SyuColors.paper,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SyuColors.inkElevated,
        hintStyle: const TextStyle(color: SyuColors.steel),
        labelStyle: const TextStyle(color: SyuColors.mist),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SyuColors.crimson, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SyuColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SyuColors.crimson,
          foregroundColor: SyuColors.paper,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SyuColors.paper,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: Color(0xFF333333)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: SyuColors.crimsonSoft),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SyuColors.inkSoft,
        contentTextStyle: const TextStyle(color: SyuColors.paper),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF222222), thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SyuColors.inkElevated,
        indicatorColor: SyuColors.crimson.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? SyuColors.crimsonSoft : SyuColors.steel,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? SyuColors.crimsonSoft : SyuColors.steel,
          );
        }),
      ),
    );
  }
}
