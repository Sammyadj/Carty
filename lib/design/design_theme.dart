import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'carty_design.dart';

ThemeData buildDesignTheme(CartyDesign design) {
  final colors = ColorScheme.fromSeed(seedColor: design.primaryColor).copyWith(
    primary: design.primaryColor,
    onPrimary: Colors.white,
    primaryContainer: design.mint,
    onPrimaryContainer: design.primaryDark,
    secondary: design.primaryColor,
    onSecondary: Colors.white,
    secondaryContainer: design.mint,
    onSecondaryContainer: design.primaryDark,
    surface: Colors.white,
    onSurface: design.textPrimary,
    onSurfaceVariant: design.textSecondary,
    outlineVariant: design.borderColor,
    error: design.error,
  );
  final base = ThemeData(
    colorScheme: colors,
    fontFamily: design.fontFamily,
    useMaterial3: true,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(design.radius),
  );
  return base.copyWith(
    extensions: [design],
    scaffoldBackgroundColor: design.backgroundColor,
    textTheme: base.textTheme.copyWith(
      headlineLarge: TextStyle(
        fontFamily: design.fontFamily,
        fontSize: 38,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.8,
        color: design.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: design.fontFamily,
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        color: design.textPrimary,
      ),
      titleLarge: base.textTheme.titleLarge!.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      titleMedium: base.textTheme.titleMedium!.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleSmall: base.textTheme.titleSmall!.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: base.textTheme.bodyMedium!.copyWith(
        fontSize: 14,
        height: 1.45,
      ),
      bodySmall: base.textTheme.bodySmall!.copyWith(
        fontSize: 12,
        height: 1.45,
        color: design.textSecondary,
      ),
      labelLarge: base.textTheme.labelLarge!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: design.backgroundColor,
      foregroundColor: design.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape.copyWith(side: BorderSide(color: design.borderColor)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: design.backgroundColor,
      indicatorColor: design.mint,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: design.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: design.textPrimary,
        ),
      ),
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: design.primaryColor, size: 23),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(design.radius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(design.radius),
        borderSide: BorderSide(color: design.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(design.radius),
        borderSide: BorderSide(color: design.primaryColor, width: 2),
      ),
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: design.primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: design.primaryColor,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: design.borderColor),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: design.primaryColor),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: design.backgroundColor,
      shape: shape,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: design.backgroundColor,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(design.radius + 8),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: design.borderColor,
      thickness: 1,
      space: 1,
    ),
  );
}

void registerDesignFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Manrope']) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/$family-OFL.txt'));
    }
  });
}
