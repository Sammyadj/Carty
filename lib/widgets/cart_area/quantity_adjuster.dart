import 'package:flutter/material.dart';
import 'editable_text_field.dart';

class QuantityAdjuster extends StatelessWidget {
  final bool isEditing;
  final int value;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onTap;

  const QuantityAdjuster({
    super.key,
    required this.isEditing,
    required this.value,
    required this.controller,
    required this.focusNode,
    required this.onIncrement,
    required this.onDecrement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 55,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: EditableTextField(
              isEditing: isEditing,
              value: value.toString(),
              controller: controller,
              onTap: onTap,
              textAlign: TextAlign.center,
              width: 30,
              focusNode: focusNode,
            ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: () {
                  onIncrement();
                  controller.text = (value + 1).toString();
                },
                child: Icon(Icons.keyboard_arrow_up, size: 16),
              ),
              GestureDetector(
                onTap: () {
                  onDecrement();
                  controller.text = (value - 1).toString();
                },
                child: Icon(Icons.keyboard_arrow_down, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
