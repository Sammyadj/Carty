import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryColor = Color(0xFF1976D2); // Lighter Blue
  static const Color accentColor = Color(0xFFD32F2F); // Red
  static const Color clearCartColor = Color(0xFFCB2552); // Clear Cart button background
  static const Color backgroundColor = Color(0xFFF5F7FB); // Soft background
  static const Color textPrimary = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF555555);
  static const Color borderColor = Color(0xFFDDDDDD);
  static const Color tileBackground = Colors.white;
}

class AppTextStyles {
  static const TextStyle itemTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle itemPrice = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryColor,
  );

  static const TextStyle subhead = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.accentColor,
  );
}
