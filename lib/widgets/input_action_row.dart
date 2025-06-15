import 'package:flutter/material.dart';

class InputActionRow extends StatelessWidget {
  final String labelText;
  final String buttonText;
  final VoidCallback onPressed;
  final TextEditingController controller;
  const InputActionRow({
    super.key,
    required this.labelText,
    required this.buttonText,
    required this.onPressed,
    required this.controller,
    // required this.controller,
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
