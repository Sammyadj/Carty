import 'package:flutter/material.dart';
import '../../base/res/styles/app_styles.dart';

class PriceDisplay extends StatelessWidget {
  final String value;
  final double width;

  const PriceDisplay({
    super.key,
    required this.value,
    this.width = 70,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        '£$value',
        textAlign: TextAlign.center,
        style: AppTextStyles.itemPrice,
      ),
    );
  }
}
