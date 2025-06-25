import 'package:flutter/material.dart';
import '../../base/res/styles/app_styles.dart';

class PriceInput extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  const PriceInput({super.key, required this.controller, this.errorText});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
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