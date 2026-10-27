import 'package:flutter/material.dart';

/// City is Carty’s single production design system.
@immutable
class CartyDesign extends ThemeExtension<CartyDesign> {
  const CartyDesign({
    required this.fontFamily,
    required this.primaryColor,
    required this.primaryDark,
    required this.mint,
    required this.backgroundColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
    required this.heroColor,
    required this.heroInk,
    required this.heroAccent,
    required this.radius,
    required this.headline,
    required this.eyebrow,
  });
  final String fontFamily;
  final Color primaryColor;
  final Color primaryDark;
  final Color mint;
  final Color backgroundColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderColor;
  final Color heroColor;
  final Color heroInk;
  final Color heroAccent;
  final double radius;
  final String headline;
  final String eyebrow;
  Color get warning => const Color(0xFF855100);
  Color get warningLight => const Color(0xFFFFE8B5);
  Color get error => const Color(0xFFB32635);
  Color get accentColor => primaryColor;
  Color get clearCartColor => error;
  Color get tileBackground => Colors.white;

  static const city = CartyDesign(
    fontFamily: 'Manrope',
    primaryColor: Color(0xFF151515),
    primaryDark: Color(0xFF151515),
    mint: Color(0xFFEDF4D3),
    backgroundColor: Colors.white,
    textPrimary: Color(0xFF151515),
    textSecondary: Color(0xFF666666),
    borderColor: Color(0xFFE9E9E6),
    heroColor: Color(0xFF171A17),
    heroInk: Colors.white,
    heroAccent: Color(0xFFD9F478),
    radius: 12,
    eyebrow: 'THE EVERYDAY EDIT',
    headline: 'Your shop.\nYour rules.',
  );
  static CartyDesign of(BuildContext context) =>
      Theme.of(context).extension<CartyDesign>() ?? city;
  @override
  CartyDesign copyWith() => this;
  @override
  CartyDesign lerp(covariant CartyDesign? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
