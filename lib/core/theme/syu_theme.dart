import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SYU brand tokens — crimson on white.
class SyuColors {
  SyuColors._();

  static const Color crimson = Color(0xFFE10600);
  static const Color crimsonDeep = Color(0xFFB00000);
  static const Color crimsonSoft = Color(0xFFFF4D45);
  /// Primary text
  static const Color ink = Color(0xFF121212);
  /// Cards / elevated surfaces
  static const Color inkElevated = Color(0xFFFFFFFF);
  /// Soft fill / progress track
  static const Color inkSoft = Color(0xFFF0F0F0);
  static const Color steel = Color(0xFF8A8A8A);
  /// Secondary body text
  static const Color mist = Color(0xFF5C5C5C);
  /// Page background / on-primary
  static const Color paper = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E2E2);
  static const Color success = Color(0xFF2BB673);
  static const Color warning = Color(0xFFF5A524);
  static const Color danger = Color(0xFFFF5C5C);
}

class SyuTheme {
  SyuTheme._();

  static ThemeData light() {
    final baseText = GoogleFonts.outfitTextTheme(ThemeData.light().textTheme);
    final display = GoogleFonts.bebasNeueTextTheme(ThemeData.light().textTheme);

    final scheme = const ColorScheme.light(
      primary: SyuColors.crimson,
      onPrimary: SyuColors.paper,
      primaryContainer: Color(0xFFFFE8E6),
      onPrimaryContainer: SyuColors.crimsonDeep,
      secondary: SyuColors.mist,
      onSecondary: SyuColors.paper,
      surface: SyuColors.paper,
      onSurface: SyuColors.ink,
      surfaceContainerHighest: SyuColors.inkSoft,
      error: SyuColors.danger,
      onError: SyuColors.paper,
      outline: SyuColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: SyuColors.paper,
      cardTheme: CardThemeData(
        color: SyuColors.inkElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: SyuColors.border),
        ),
      ),
      textTheme: baseText.copyWith(
        displayLarge: display.displayLarge?.copyWith(
          color: SyuColors.ink,
          letterSpacing: 1.2,
        ),
        displayMedium: display.displayMedium?.copyWith(
          color: SyuColors.ink,
          letterSpacing: 1.0,
        ),
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: SyuColors.ink,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: SyuColors.ink,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: SyuColors.ink,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: SyuColors.ink,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(color: SyuColors.ink),
        bodyMedium: baseText.bodyMedium?.copyWith(color: SyuColors.mist),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: SyuColors.ink,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SyuColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: SyuColors.ink,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SyuColors.inkSoft,
        hintStyle: const TextStyle(color: SyuColors.steel),
        labelStyle: const TextStyle(color: SyuColors.mist),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
          maxHeight: 48,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
          maxHeight: 48,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SyuColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SyuColors.border),
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
          // Prefer height-only mins via Size(0, h) — Size.fromHeight sets
          // width=infinity and crashes FilledButtons inside Rows.
          minimumSize: const Size(0, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SyuColors.ink,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: SyuColors.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: SyuColors.crimson),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SyuColors.ink,
        contentTextStyle: const TextStyle(color: SyuColors.paper),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme:
          const DividerThemeData(color: SyuColors.border, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SyuColors.paper,
        indicatorColor: SyuColors.crimson.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? SyuColors.crimson : SyuColors.steel,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? SyuColors.crimson : SyuColors.steel,
          );
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: SyuColors.paper,
        selectedIconTheme: IconThemeData(color: SyuColors.crimson),
        unselectedIconTheme: IconThemeData(color: SyuColors.steel),
        selectedLabelTextStyle: TextStyle(color: SyuColors.crimson),
        unselectedLabelTextStyle: TextStyle(color: SyuColors.steel),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SyuColors.crimson,
        linearTrackColor: SyuColors.inkSoft,
      ),
    );
  }

  /// Kept for call-site compatibility; maps to light theme.
  static ThemeData dark() => light();
}
