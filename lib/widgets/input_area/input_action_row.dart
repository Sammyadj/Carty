import 'package:flutter/material.dart';

import '../../base/res/styles/app_styles.dart';
import '../primary_button.dart';
import 'price_input.dart';

class InputActionRow extends StatelessWidget {
  final String labelText;
  final String buttonText;
  final VoidCallback onPressed;
  final TextEditingController mainController;
  final TextEditingController? priceController;
  final String? inputErrorText;
  final String? priceErrorText;
  const InputActionRow({
    super.key,
    required this.labelText,
    required this.buttonText,
    required this.onPressed,
    required this.mainController,
    this.priceController,
    this.inputErrorText,
    this.priceErrorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: mainController,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  labelText: labelText,
                  hintText: labelText,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                  ),
                  errorText: inputErrorText,
                ),
              ),
            ),
            SizedBox(width: 15),
            if (priceController != null) ...[
              PriceInput(
                controller: priceController!,
                errorText: priceErrorText,
              ),
              SizedBox(width: 15),
            ],
            PrimaryButton(
              text: buttonText,
              onPressed: onPressed,
              width: 135,
            ),
          ],
        ),
        if (priceErrorText != null && priceErrorText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              priceErrorText!,
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
