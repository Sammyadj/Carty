import 'package:flutter/material.dart';
import '../../base/res/styles/app_styles.dart';

class ItemNameEditor extends StatelessWidget {
  final bool isEditing;
  final String value;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onTap;

  const ItemNameEditor({
    super.key,
    required this.isEditing,
    required this.value,
    required this.controller,
    required this.focusNode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return isEditing
        ? TextField(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();
            },
            autofocus: true,
            style: AppTextStyles.itemTitle,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              border: InputBorder.none,
            ),
          )
        : InkWell(
            onTap: () {
              onTap();
              Future.delayed(Duration.zero, () {
                focusNode.requestFocus();
              });
            },
            child: Text(
              value,
              style: AppTextStyles.itemTitle,
            ),
          );
  }
}
