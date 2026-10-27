import 'package:flutter/material.dart';

enum DesignVariant { city, fresh, pantry }

/// Presentation-only tokens. Shopping state never depends on the selected style.
@immutable
class CartyDesign extends ThemeExtension<CartyDesign> {
  const CartyDesign({
    required this.variant,
    required this.name,
    required this.description,
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
  final DesignVariant variant;
  final String name;
  final String description;
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
    variant: DesignVariant.city,
    name: 'City',
    description: 'Strong type. Crisp edges. A focused everyday shop.',
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
  static const fresh = CartyDesign(
    variant: DesignVariant.fresh,
    name: 'Fresh',
    description: 'Cool teal. Airy cards. A little room to breathe.',
    fontFamily: 'DMSans',
    primaryColor: Color(0xFF006D68),
    primaryDark: Color(0xFF133E3B),
    mint: Color(0xFFDBF3EC),
    backgroundColor: Color(0xFFF3F8F7),
    textPrimary: Color(0xFF173D3A),
    textSecondary: Color(0xFF57716E),
    borderColor: Color(0xFFDDEAE7),
    heroColor: Color(0xFF075E59),
    heroInk: Colors.white,
    heroAccent: Color(0xFFDAD2FF),
    radius: 26,
    eyebrow: 'A FRESH START',
    headline: 'Good food.\nBetter budgets.',
  );
  static const pantry = CartyDesign(
    variant: DesignVariant.pantry,
    name: 'Pantry',
    description: 'Warm colour. Friendly shapes. Big little wins.',
    fontFamily: 'NunitoSans',
    primaryColor: Color(0xFFA83D12),
    primaryDark: Color(0xFF4E281C),
    mint: Color(0xFFFFE2C5),
    backgroundColor: Color(0xFFFFF9F1),
    textPrimary: Color(0xFF432A22),
    textSecondary: Color(0xFF7E675E),
    borderColor: Color(0xFFF0E3D5),
    heroColor: Color(0xFFFFD29D),
    heroInk: Color(0xFF4E281C),
    heroAccent: Color(0xFFA83D12),
    radius: 30,
    eyebrow: 'A LITTLE MORE JOY',
    headline: 'Make room\nfor the good stuff.',
  );
  static CartyDesign forVariant(DesignVariant variant) => switch (variant) {
    DesignVariant.city => city,
    DesignVariant.fresh => fresh,
    DesignVariant.pantry => pantry,
  };
  static CartyDesign of(BuildContext context) =>
      Theme.of(context).extension<CartyDesign>() ?? city;
  @override
  CartyDesign copyWith() => this;
  @override
  CartyDesign lerp(covariant CartyDesign? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

class DesignPreviewScope extends InheritedWidget {
  const DesignPreviewScope({
    super.key,
    required this.variant,
    required this.onChanged,
    required super.child,
  });
  final DesignVariant variant;
  final ValueChanged<DesignVariant> onChanged;
  static DesignPreviewScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesignPreviewScope>();
  @override
  bool updateShouldNotify(DesignPreviewScope oldWidget) =>
      variant != oldWidget.variant;
}
