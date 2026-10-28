import 'dart:collection';
import 'dart:convert';

/// JSONB may reorder object keys; compare contents rather than wire formatting.
String canonicalSnapshot(String value) {
  Object? ordered(Object? node) {
    if (node is Map<String, dynamic>) {
      return SplayTreeMap<String, Object?>.from(
        node.map((key, value) => MapEntry(key, ordered(value))),
      );
    }
    if (node is List) return node.map(ordered).toList();
    return node;
  }

  return jsonEncode(ordered(jsonDecode(value)));
}

class CloudWorkspace {
  const CloudWorkspace({
    required this.ownerId,
    required this.revision,
    required this.snapshot,
  });
  final String ownerId;
  final int revision;
  final String snapshot;
}

abstract interface class CloudWorkspaceRepository {
  Future<CloudWorkspace?> fetch(String ownerId);

  /// Returns null if another device changed the expected revision.
  Future<CloudWorkspace?> save(
    String ownerId,
    int expectedRevision,
    String snapshot,
  );
}
