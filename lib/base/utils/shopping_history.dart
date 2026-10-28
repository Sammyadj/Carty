import 'package:flutter/material.dart';

import '../../state/cart_store.dart';
import '../../core/money.dart';

Future<void> showFinishShopping({
  required BuildContext context,
  required CartStore store,
}) async {
  if (!await store.waitForPendingSave() || !context.mounted) return;
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _FinishDialog(
      initialName: store.activeList?.name ?? 'Shopping trip',
      pending: store.pendingCount,
      unconfirmed: store.unconfirmedPriceCount,
      pickedTotal: store.totalPence,
    ),
  );
  if (name == null || !context.mounted) return;
  await store.completeShopping(name);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        store.storageError == null
            ? 'Shopping trip saved to History.'
            : 'Couldn’t save the finished shop. Keep Carty open and retry.',
      ),
    ),
  );
}

class _FinishDialog extends StatefulWidget {
  const _FinishDialog({
    required this.initialName,
    required this.pending,
    required this.unconfirmed,
    required this.pickedTotal,
  });
  final String initialName;
  final int pending;
  final int unconfirmed;
  final int pickedTotal;
  @override
  State<_FinishDialog> createState() => _FinishDialogState();
}

class _FinishDialogState extends State<_FinishDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Finish shopping?'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Save the picked products and your entered total to History, then clear this basket and budget. Saved lists stay available. No payment is taken.',
          ),
          const SizedBox(height: 12),
          Text('Picked total: ${Money.format(widget.pickedTotal)}'),
          if (widget.unconfirmed > 0)
            Text(
              '${widget.unconfirmed} picked prices are still estimates. You can go back to confirm them, or save them as entered.',
            ),
          if (widget.pending > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${widget.pending} products still need picking. Only picked quantities will be recorded; unpicked quantities won’t be included.',
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('finish-shop-name'),
            controller: _name,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Shopping trip name'),
            validator: (value) =>
                value == null ||
                    value.trim().isEmpty ||
                    value.trim().length > 60
                ? 'Enter a name of 1 to 60 characters'
                : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('finish-shop-confirm'),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _name.text.trim());
          }
        },
        child: const Text('Finish shopping'),
      ),
    ],
  );
}
