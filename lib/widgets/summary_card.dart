import 'package:carty_app/widgets/summary_row.dart';
import 'package:flutter/material.dart';

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
      elevation: 2,
      margin: EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 6),
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
