import 'package:flutter/material.dart';

import '../../state/cart_store.dart';

Future<void> showFinishShopping({
  required BuildContext context,
  required CartStore store,
}) async {
  if (!await store.waitForPendingSave() || !context.mounted) return;
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _FinishDialog(
      initialName: store.activeList?.name ?? 'Shopping trip',
      pending: store.items.where((item) => item.quantity == 0).length,
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
  const _FinishDialog({required this.initialName, required this.pending});
  final String initialName;
  final int pending;
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
          if (widget.pending > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${widget.pending} products with quantity zero won’t be included in this record.',
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
