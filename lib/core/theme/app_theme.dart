import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData dark() {
    final textTheme = _buildTextTheme(
      GoogleFonts.plusJakartaSansTextTheme(Typography.whiteMountainView).apply(
        bodyColor: AppColors.darkTextPrimary,
        displayColor: AppColors.darkTextPrimary,
      ),
    );

    final colorScheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: AppColors.primaryAccent,
      secondary: AppColors.secondaryAccent,
      tertiary: AppColors.warningAccent,
      error: AppColors.dangerAccent,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      onPrimary: Colors.white,
      onSecondary: AppColors.brandBlack,
      outline: AppColors.darkBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(10),
          minimumSize: const Size(40, 40),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkCard,
        selectedColor: AppColors.primaryAccent.withValues(alpha: 0.16),
        labelStyle: textTheme.labelMedium ?? const TextStyle(),
        side: const BorderSide(color: AppColors.darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      dividerColor: AppColors.darkBorder,
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Icon(Icons.check_rounded, size: 14);
          }
          return const Icon(Icons.close_rounded, size: 14);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primaryAccent),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        dense: true,
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity(vertical: -1),
      ),
    );
  }

  static ThemeData light() {
    final textTheme = _buildTextTheme(
      GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: AppColors.lightTextPrimary,
        displayColor: AppColors.lightTextPrimary,
      ),
    );

    final colorScheme = const ColorScheme.light(
      primary: AppColors.primaryAccent,
      secondary: AppColors.secondaryAccent,
      tertiary: AppColors.warningAccent,
      error: AppColors.dangerAccent,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      outline: AppColors.lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(10),
          minimumSize: const Size(40, 40),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightCard,
        selectedColor: AppColors.primaryAccent.withValues(alpha: 0.12),
        labelStyle: textTheme.labelMedium ?? const TextStyle(),
        side: const BorderSide(color: AppColors.lightBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      dividerColor: AppColors.lightBorder,
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Icon(Icons.check_rounded, size: 14);
          }
          return const Icon(Icons.close_rounded, size: 14);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primaryAccent),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        dense: true,
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity(vertical: -1),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w800,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w800,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w800,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 14, height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 13, height: 1.45),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12, height: 1.4),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
