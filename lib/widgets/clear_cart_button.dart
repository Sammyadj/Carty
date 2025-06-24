import 'package:flutter/material.dart';
import '../base/res/styles/app_styles.dart';

class ClearCartButton extends StatelessWidget {
  final VoidCallback onClear;
  final bool showButton;

  const ClearCartButton({
    super.key,
    required this.onClear,
    required this.showButton,
  });

  @override
  Widget build(BuildContext context) {
    if (!showButton) return SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: onClear,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.clearCartColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        child: Text(
          'Clear Cart',
          style: AppTextStyles.buttonText.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
