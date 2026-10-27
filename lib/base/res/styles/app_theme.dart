import 'package:flutter/material.dart';

import 'app_styles.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final colors = ColorScheme.fromSeed(seedColor: AppColors.primaryColor)
        .copyWith(
          primary: AppColors.primaryColor,
          onPrimary: Colors.white,
          primaryContainer: AppColors.mint,
          onPrimaryContainer: AppColors.primaryDark,
          surface: Colors.white,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          outlineVariant: AppColors.borderColor,
          error: AppColors.error,
        );
    final base = ThemeData(colorScheme: colors, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundColor,
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge!.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          color: AppColors.textPrimary,
        ),
        headlineMedium: base.textTheme.headlineMedium!.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: AppColors.textPrimary,
        ),
        titleLarge: base.textTheme.titleLarge!.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: AppColors.textPrimary,
        ),
        titleMedium: base.textTheme.titleMedium!.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleSmall: base.textTheme.titleSmall!.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        bodyLarge: base.textTheme.bodyLarge!.copyWith(
          fontSize: 16,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
        bodyMedium: base.textTheme.bodyMedium!.copyWith(
          fontSize: 14,
          height: 1.45,
          color: AppColors.textPrimary,
        ),
        bodySmall: base.textTheme.bodySmall!.copyWith(
          fontSize: 12,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
        labelLarge: base.textTheme.labelLarge!.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundColor,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: base.textTheme.titleLarge!.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.mint,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryColor
                : AppColors.textSecondary,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primaryColor,
            width: 1.5,
          ),
        ),
        errorMaxLines: 3,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
