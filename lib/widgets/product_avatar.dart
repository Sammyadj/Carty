import 'package:flutter/material.dart';

/// A decorative grocery illustration chosen from simple name hints.
class ProductAvatar extends StatelessWidget {
  const ProductAvatar({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hint = name.toLowerCase();
    final (icon, foreground, background) = switch (hint) {
      _ when _contains(hint, ['milk', 'juice', 'water', 'drink']) => (
        Icons.local_drink_outlined,
        const Color(0xFF4D83AD),
        const Color(0xFFEDF5FB),
      ),
      _ when _contains(hint, ['bread', 'bagel', 'croissant', 'loaf']) => (
        Icons.bakery_dining_outlined,
        const Color(0xFFB38238),
        const Color(0xFFFBF2E0),
      ),
      _ when _contains(hint, ['egg']) => (
        Icons.egg_outlined,
        const Color(0xFFA68552),
        const Color(0xFFF8F1E5),
      ),
      _ when _contains(hint, ['apple', 'fruit', 'pear', 'peach', 'berry']) => (
        Icons.apple,
        const Color(0xFFCE6259),
        const Color(0xFFFFEFEB),
      ),
      _ when _contains(hint, ['coffee', 'tea', 'cocoa']) => (
        Icons.coffee_outlined,
        const Color(0xFF947358),
        const Color(0xFFF5EEE8),
      ),
      _ when _contains(hint, ['fish', 'salmon', 'tuna']) => (
        Icons.set_meal_outlined,
        const Color(0xFF4E8A9C),
        const Color(0xFFEBF5F6),
      ),
      _ when _contains(hint, ['rice', 'pasta', 'noodle', 'cereal', 'oat']) => (
        Icons.rice_bowl_outlined,
        const Color(0xFFB08846),
        const Color(0xFFFBF4E7),
      ),
      _
          when _contains(hint, [
            'salad',
            'spinach',
            'vegetable',
            'broccoli',
            'lettuce',
            'avocado',
            'herb',
          ]) =>
        (Icons.eco_outlined, const Color(0xFF438F5D), const Color(0xFFECF6EB)),
      _ => (
        Icons.shopping_bag_outlined,
        const Color(0xFF087F5B),
        const Color(0xFFE8F5EE),
      ),
    };

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * .27),
          border: Border.all(color: foreground.withValues(alpha: .08)),
        ),
        child: Icon(icon, size: size * .56, color: foreground),
      ),
    );
  }

  static bool _contains(String value, List<String> hints) =>
      hints.any(value.contains);
}
