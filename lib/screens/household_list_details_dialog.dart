import 'package:flutter/material.dart';

import '../core/money.dart';
import '../sharing/shared_list.dart';

class HouseholdListDetailsDialog extends StatefulWidget {
  const HouseholdListDetailsDialog({
    super.key,
    required this.content,
    this.creating = false,
  });
  final SharedContent content;
  final bool creating;
  @override
  State<HouseholdListDetailsDialog> createState() =>
      _HouseholdListDetailsDialogState();
}

class _HouseholdListDetailsDialogState
    extends State<HouseholdListDetailsDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.content.name);
  late final _budget = TextEditingController(
    text: widget.content.budgetPence == null
        ? ''
        : Money.format(widget.content.budgetPence!).substring(1),
  );
  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.creating ? 'Create household list' : 'List details'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.creating)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Only this list’s products and budget will be shared. Your original private list stays available.',
                ),
              ),
            TextFormField(
              key: const Key('household-name'),
              controller: _name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'List name'),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a list name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('household-budget'),
              controller: _budget,
              decoration: const InputDecoration(
                labelText: 'Budget (optional)',
                prefixText: '£ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) =>
                  value == null ||
                      value.trim().isEmpty ||
                      (Money.tryParsePence(value) ?? 0) > 0
                  ? null
                  : 'Enter a valid budget above zero',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('household-details-save'),
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            SharedContent(
              name: _name.text,
              budgetPence: _budget.text.trim().isEmpty
                  ? null
                  : Money.tryParsePence(_budget.text),
              isPlanning: widget.content.isPlanning,
              items: widget.content.items,
            ),
          );
        },
        child: Text(widget.creating ? 'Create shared list' : 'Save details'),
      ),
    ],
  );
}
