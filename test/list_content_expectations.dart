import 'package:carty_app/models/saved_shopping_list.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opening a list may update last-used metadata, but never its saved contents.
void expectListContentsPreserved(
  SavedShoppingList actual,
  SavedShoppingList original,
) {
  expect(
    {...actual.toJson()}..remove('lastUsedAt'),
    {...original.toJson()}..remove('lastUsedAt'),
  );
  expect(actual.lastUsedAt, isNotNull);
}
