import 'package:flutter/material.dart';

class InputActionRow extends StatelessWidget {
  final String labelText;
  final String buttonText;
  final VoidCallback onPressed;
  final TextEditingController controller;
  final TextEditingController? priceController;
  const InputActionRow({
    super.key,
    required this.labelText,
    required this.buttonText,
    required this.onPressed,
    required this.controller,
    this.priceController,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: labelText,
              border: OutlineInputBorder(),
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
          style: ButtonStyle(
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          child: Text(buttonText),
        ),
      ],
    );
  }
}

class IsPrice extends StatelessWidget {
  final TextEditingController controller;
  const IsPrice({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: "Price",
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
