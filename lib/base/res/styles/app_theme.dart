import 'package:flutter/material.dart';
import 'app_styles.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primaryColor: AppColors.primaryColor,
    scaffoldBackgroundColor: AppColors.backgroundColor,
    textTheme: TextTheme(
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.body,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 1,
      centerTitle: true,
      titleTextStyle: AppTextStyles.headline,
      iconTheme: IconThemeData(color: AppColors.primaryColor),
    ),
    useMaterial3: true,
  );
}