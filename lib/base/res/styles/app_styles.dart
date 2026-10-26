import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryColor = Color(0xFF087F5B);
  static const Color primaryDark = Color(0xFF064E3B);
  static const Color mint = Color(0xFFE8F5EE);
  static const Color backgroundColor = Color(0xFFF6F8F7);
  static const Color textPrimary = Color(0xFF152B24);
  static const Color textSecondary = Color(0xFF5F6F67);
  static const Color borderColor = Color(0xFFE2EAE5);
  static const Color warning = Color(0xFF925800);
  static const Color warningLight = Color(0xFFFFF3D6);
  static const Color error = Color(0xFFBA3C40);
  static const Color accentColor = error;
  static const Color clearCartColor = error;
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
