import 'package:flutter/material.dart';

import '../base/res/styles/app_styles.dart';

class InputActionRow extends StatelessWidget {
  final String labelText;
  final String buttonText;
  final VoidCallback onPressed;
  final TextEditingController controller;
  final TextEditingController? priceController;
  final String? inputErrorText;
  final String? priceErrorText;
  const InputActionRow({
    super.key,
    required this.labelText,
    required this.buttonText,
    required this.onPressed,
    required this.controller,
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
                controller: controller,
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
            SizedBox(width: 20),
            if (priceController != null)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: IsPrice(controller: priceController!),
              ),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              child: Text(buttonText),
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

class IsPrice extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  const IsPrice({super.key, required this.controller, this.errorText});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        style: AppTextStyles.body,
        decoration: InputDecoration(
          labelText: "Price",
          hintText: "Price",
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
          errorText: errorText,
        ),
      ),
    );
  }
}
