import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../models/cart_item.dart';
import '../../models/saved_shopping_list.dart';
import '../../state/cart_store.dart';
import '../../widgets/cart_area/cart_item_editor.dart';

Future<void> showItemEditor({
  required BuildContext context,
  required CartStore store,
  CartItem? item,
}) async {
  final draft = await showDialog<CartItemDraft>(
    context: context,
    builder: (_) => CartItemEditor(item: item),
  );
  if (draft == null || !context.mounted) return;
  if (item == null) {
    await store.addItem(
      name: draft.name,
      unitPricePence: draft.unitPricePence,
      quantity: draft.quantity,
    );
  } else {
    await store.updateItem(
      item.copyWith(
        name: draft.name,
        unitPricePence: draft.unitPricePence,
        quantity: draft.quantity,
      ),
    );
  }
}

Future<void> showBudgetEditor({
  required BuildContext context,
  required CartStore store,
}) async {
  final result = await showDialog<_BudgetChoice>(
    context: context,
    builder: (_) => _BudgetDialog(budgetPence: store.budgetPence),
  );
  if (result == null || !context.mounted) return;
  await store.setBudget(result.value);
}

Future<void> confirmAndClearCart({
  required BuildContext context,
  required CartStore store,
}) async {
  final clear = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Clear cart?'),
          content: const Text(
            'Remove all products from this basket? Your budget and saved shopping lists will stay.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('clear-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Clear cart'),
            ),
          ],
        ),
  );
  if (clear != true || !context.mounted) return;
  await store.clearCart();
}

Future<void> showSaveList({
  required BuildContext context,
  required CartStore store,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => const _ListNameDialog(),
  );
  if (name == null || !context.mounted) return;
  await store.saveList(name);
}

Future<bool> showReuseList({
  required BuildContext context,
  required CartStore store,
  required SavedShoppingList list,
}) async {
  final startFresh = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: Text('Use ${list.name}'),
          content: const SingleChildScrollView(
            child: Text(
              'This replaces your current basket. Your saved list stays untouched.\n\nDuplicate list: keep quantities and budget.\n\nStart fresh: keep products and last entered prices, set quantities to 0 and remove the budget. Check prices on your next trip.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Duplicate list'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Start fresh'),
            ),
          ],
        ),
  );
  if (startFresh == null || !context.mounted) return false;
  await store.startFromList(list.id, startFresh: startFresh);
  return true;
}

Future<void> confirmDeleteList({
  required BuildContext context,
  required CartStore store,
  required SavedShoppingList list,
}) async {
  final remove = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Delete saved list?'),
          content: Text(
            'Delete “${list.name}”? Your current basket will stay.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete list'),
            ),
          ],
        ),
  );
  if (remove != true || !context.mounted) return;
  await store.removeSavedList(list.id);
}

Future<void> confirmStorageReset({
  required BuildContext context,
  required CartStore store,
}) async {
  final reset = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Replace unreadable saved data?'),
          content: const Text(
            'Carty could not read the saved basket. This replaces the unreadable local data with the basket and lists currently shown in Carty. The old saved data cannot be recovered after replacement.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reset local data'),
            ),
          ],
        ),
  );
  if (reset != true || !context.mounted) return;
  await store.resetUnreadableStorage();
}

class _BudgetChoice {
  const _BudgetChoice(this.value);
  final int? value;
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.budgetPence});
  final int? budgetPence;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text:
        widget.budgetPence == null
            ? ''
            : Money.format(widget.budgetPence!).replaceAll('£', ''),
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, _BudgetChoice(Money.tryParsePence(_amount.text)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Shopping budget'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: TextFormField(
            key: const Key('budget-input'),
            controller: _amount,
            autofocus: true,
            maxLength: 12,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onFieldSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              labelText: 'Budget',
              prefixText: '£ ',
              counterText: '',
            ),
            validator: (value) {
              final amount = Money.tryParsePence(value ?? '');
              return amount == null || amount <= 0
                  ? 'Enter a budget above £0 with up to 2 decimals'
                  : null;
            },
          ),
        ),
      ),
      actions: [
        if (widget.budgetPence != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const _BudgetChoice(null)),
            child: const Text('Remove budget'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('budget-save'),
          onPressed: _save,
          child: const Text('Set budget'),
        ),
      ],
    );
  }
}

class _ListNameDialog extends StatefulWidget {
  const _ListNameDialog();
  @override
  State<_ListNameDialog> createState() => _ListNameDialogState();
}

class _ListNameDialogState extends State<_ListNameDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Save shopping list'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: TextFormField(
          key: const Key('list-name-input'),
          controller: _name,
          autofocus: true,
          maxLength: SavedShoppingList.maxNameLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'List name',
            hintText: 'Weekly groceries',
          ),
          onFieldSubmitted: (_) => _save(),
          validator: (value) {
            final name = value?.trim() ?? '';
            if (name.isEmpty) return 'Enter a list name';
            if (name.length > SavedShoppingList.maxNameLength) {
              return 'Please use a shorter list name';
            }
            return null;
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('list-save'),
        onPressed: _save,
        child: const Text('Save list'),
      ),
    ],
  );
}
