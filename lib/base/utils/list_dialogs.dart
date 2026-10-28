import 'package:flutter/material.dart';

import '../../models/saved_shopping_list.dart';
import '../../state/cart_store.dart';

Future<bool> showSaveList({
  required BuildContext context,
  required CartStore store,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _ListNameDialog(isCopy: store.activeList != null),
  );
  if (name == null || !context.mounted) return false;
  await store.saveList(name);
  return store.storageError == null && !store.needsStorageReset;
}

enum _LeaveListChoice { save, discard }

/// Protect the current shop before a new or different list replaces it.
Future<bool> confirmLeaveList({
  required BuildContext context,
  required CartStore store,
  bool startingNew = false,
}) async {
  if (store.isLoading) return false;
  final saved = await store.waitForPendingSave();
  if (!context.mounted) return false;
  final prefix = startingNew ? 'new-list' : 'switch-list';
  if (!saved) {
    final retry = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Save changes before leaving?'),
        content: const Text(
          'Your latest changes could not be saved. Retry before leaving this basket. '
          'If saved data cannot be opened, return to the basket to resolve the storage warning.',
        ),
        actions: [
          TextButton(
            key: Key('$prefix-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay here'),
          ),
          FilledButton(
            key: const Key('list-leave-retry'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Retry save'),
          ),
        ],
      ),
    );
    if (retry != true || !context.mounted) return false;
    await store.retrySave();
    if (store.storageError != null ||
        store.needsStorageReset ||
        !context.mounted) {
      return false;
    }
  }
  if (!store.hasUnsavedList) return true;
  final choice = await showDialog<_LeaveListChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(
        startingNew
            ? 'Save before starting a new list?'
            : 'Save before switching lists?',
      ),
      content: Text(
        store.items.isEmpty
            ? 'Your current budget has not been saved as a list. Leaving this basket resets it. Add products first if you want to save this shop.'
            : 'Save your current products and budget as a named list so you can continue this shop later, or leave without saving them.',
      ),
      actions: [
        TextButton(
          key: Key('$prefix-cancel'),
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: Key('$prefix-discard'),
          onPressed: () =>
              Navigator.pop(dialogContext, _LeaveListChoice.discard),
          child: Text(
            startingNew ? 'Start without saving' : 'Switch without saving',
          ),
        ),
        if (store.items.isNotEmpty)
          FilledButton(
            key: Key('$prefix-save'),
            onPressed: () =>
                Navigator.pop(dialogContext, _LeaveListChoice.save),
            child: Text(startingNew ? 'Save and start new' : 'Save and switch'),
          ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return false;
  return choice == _LeaveListChoice.discard ||
      await showSaveList(context: context, store: store);
}

class _ListNameDialog extends StatefulWidget {
  const _ListNameDialog({required this.isCopy});
  final bool isCopy;
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
    title: Text(widget.isCopy ? 'Save a copy' : 'Save shopping list'),
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
