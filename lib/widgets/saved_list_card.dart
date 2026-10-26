import 'package:flutter/material.dart';

import '../base/res/styles/app_styles.dart';
import '../models/saved_shopping_list.dart';

/// A saved snapshot with separate, accessible use and delete controls.
class SavedListCard extends StatelessWidget {
  const SavedListCard({
    super.key,
    required this.list,
    required this.onUse,
    this.onDelete,
    this.compact = false,
  });

  final SavedShoppingList list;
  final VoidCallback onUse;
  final VoidCallback? onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: ValueKey('saved-list-load-${list.id}'),
                onTap: onUse,
                child: Padding(
                  padding: EdgeInsets.all(compact ? 12 : 16),
                  child: Row(
                    children: [
                      Container(
                        width: compact ? 44 : 50,
                        height: compact ? 44 : 50,
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.shopping_basket_rounded,
                          color: AppColors.primaryColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              list.name,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: compact ? 15 : 17,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${list.items.length} ${list.items.length == 1 ? 'product' : 'products'} · ${_savedDate(list.savedAt)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                        size: 21,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onDelete != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  key: ValueKey('saved-list-delete-${list.id}'),
                  onPressed: onDelete,
                  tooltip: 'Delete ${list.name}',
                  color: AppColors.textSecondary,
                  icon: const Icon(Icons.delete_outline_rounded, size: 21),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _savedDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = date.toLocal();
    return 'Saved ${local.day} ${months[local.month - 1]} ${local.year}';
  }
}
