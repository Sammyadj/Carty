import 'package:carty_app/widgets/summary_area/summary_row.dart';
import 'package:flutter/material.dart';
import '../../base/res/styles/app_styles.dart';

class SummaryCard extends StatelessWidget {
  final double total;
  final double? budget;
  final double? remaining;

  const SummaryCard({
    super.key,
    required this.total,
    required this.budget,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(top: 20, bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderColor),
      ),
      color: AppColors.tileBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SummaryRow(label: 'Total:', value: '£${total.toStringAsFixed(2)}'),
            SummaryRow(
              label: 'Budget:',
              value: budget != null ? '£${budget!.toStringAsFixed(2)}' : '-',
            ),
            SummaryRow(
              label: 'Remaining:',
              value:
                  remaining != null ? '£${remaining!.toStringAsFixed(2)}' : '-',
            ),
          ],
        ),
      ),
    );
  }
}
