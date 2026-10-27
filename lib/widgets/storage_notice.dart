import 'package:flutter/material.dart';

import '../base/utils/cart_dialogs.dart';
import '../state/cart_store.dart';

class StorageNotice extends StatelessWidget {
  const StorageNotice({super.key, required this.store});
  final CartStore store;

  @override
  Widget build(BuildContext context) {
    if (store.storageError == null) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(store.storageError!),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: store.retrySave,
                  child: const Text('Retry'),
                ),
                if (store.needsStorageReset)
                  TextButton(
                    onPressed: () =>
                        confirmStorageReset(context: context, store: store),
                    child: const Text('Reset saved data'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
