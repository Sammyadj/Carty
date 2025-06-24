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
          backgroundColor: Colors.white,
          foregroundColor: Colors.red,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.red),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text('Clear Cart', style: AppTextStyles.buttonText),
      ),
    );
  }
}
