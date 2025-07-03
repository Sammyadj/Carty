
import 'package:flutter/material.dart';
import '../../base/res/styles/app_styles.dart';

class EditableTextField extends StatelessWidget {
  final bool isEditing;
  final String value;
  final TextEditingController controller;
  final VoidCallback onTap;
  final TextAlign textAlign;
  final double? width;
  final FocusNode? focusNode;

  const EditableTextField({
    super.key,
    required this.isEditing,
    required this.value,
    required this.controller,
    required this.onTap,
    this.textAlign = TextAlign.start,
    this.width,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return isEditing
        ? SizedBox(
            width: width ?? 60,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: (_) {
                FocusScope.of(context).unfocus();
              },
              textAlign: textAlign,
              autofocus: true,
              textAlignVertical: TextAlignVertical.center,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                border: InputBorder.none,
              ),
            ),
          )
        : InkWell(
            onTap: () {
              onTap();
              Future.delayed(Duration.zero, () {
                focusNode?.requestFocus();
              });
            },
            child: Text(
              value,
              textAlign: textAlign,
              style: AppTextStyles.body,
            ),
          );
  }
}
