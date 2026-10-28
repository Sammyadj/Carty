import 'dart:convert';

import '../cloud/cloud_workspace.dart';
import '../state/cart_store.dart';

/// Keeps the existing cloud envelope contract while storing its snapshots as rows.
class StoredWorkspace {
  StoredWorkspace._(this.ownerId, this.metadata, this.snapshots);
  final String? ownerId;
  final Map<String, dynamic> metadata;
  final Map<String, String> snapshots;
  static const slots = ['payload', 'base', 'backup'];

  factory StoredWorkspace.decode(String raw, {String? ownerId}) {
    if (ownerId == null) {
      if (!CartStore.isValidSnapshot(raw)) {
        throw const FormatException('Invalid shopping workspace');
      }
      return StoredWorkspace._(null, {}, {'payload': canonicalSnapshot(raw)});
    }
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['ownerId'] != ownerId ||
        value['revision'] is! int ||
        value['revision'] < 0) {
      throw const FormatException('Invalid account cache');
    }
    final snapshots = <String, String>{};
    for (final slot in slots) {
      final raw = value[slot];
      if (raw != null) {
        if (raw is! String || !CartStore.isValidSnapshot(raw)) {
          throw const FormatException('Invalid account snapshot');
        }
        snapshots[slot] = canonicalSnapshot(raw);
      }
    }
    if (value['revision'] > 0 && !snapshots.containsKey('base')) {
      throw const FormatException('Missing accepted cloud snapshot');
    }
    return StoredWorkspace._(
      ownerId,
      Map.of(value)..removeWhere((key, _) => slots.contains(key)),
      snapshots,
    );
  }

  String encode() => ownerId == null
      ? snapshots['payload']!
      : jsonEncode({
          ...metadata,
          for (final slot in slots) slot: snapshots[slot],
        });
}

class WorkspaceRecord {
  const WorkspaceRecord(
    this.kind,
    this.parent,
    this.id,
    this.position,
    this.data,
  );
  final String kind;
  final String parent;
  final String id;
  final int position;
  final String data;
  String get key => jsonEncode([kind, parent, id]);
  Map<String, Object?> toRow() => {
    'kind': kind,
    'parent_id': parent,
    'record_id': id,
    'position': position,
    'data': data,
  };
  factory WorkspaceRecord.fromRow(Map<String, Object?> row) => WorkspaceRecord(
    row['kind'] as String,
    row['parent_id'] as String,
    row['record_id'] as String,
    row['position'] as int,
    row['data'] as String,
  );
}

class WorkspaceRows {
  WorkspaceRows(this.metadata, this.records);
  final String metadata;
  final List<WorkspaceRecord> records;

  factory WorkspaceRows.fromSnapshot(String snapshot) {
    if (!CartStore.isValidSnapshot(snapshot)) {
      throw const FormatException('Invalid workspace');
    }
    final value = jsonDecode(snapshot) as Map<String, dynamic>;
    final records = <WorkspaceRecord>[];
    void add(
      String kind,
      String parent,
      String id,
      int position,
      Object? data,
    ) {
      records.add(
        WorkspaceRecord(
          kind,
          parent,
          id,
          position,
          canonicalSnapshot(jsonEncode(data)),
        ),
      );
    }

    void items(String kind, String parent, List<dynamic> items) {
      for (var i = 0; i < items.length; i++) {
        final item = items[i] as Map<String, dynamic>;
        add(kind, parent, item['id'] as String, i, item);
      }
    }

    items('items', '', value['items'] as List);
    final lists = value['savedLists'] as List? ?? [];
    for (var i = 0; i < lists.length; i++) {
      final list = Map<String, dynamic>.from(lists[i] as Map);
      final id = list['id'] as String;
      items('listItems', id, list.remove('items') as List);
      add('lists', '', id, i, list);
    }
    final trips = value['history'] as List? ?? [];
    for (var i = 0; i < trips.length; i++) {
      final trip = Map<String, dynamic>.from(trips[i] as Map);
      final id = trip['id'] as String;
      items('tripItems', id, trip.remove('items') as List);
      final hasPlan = trip.containsKey('plannedItems');
      if (hasPlan) {
        items('tripPlanItems', id, trip.remove('plannedItems') as List);
      }
      add('trips', '', id, i, {'fields': trip, 'hasPlan': hasPlan});
    }
    final preferences = value['productPreferences'] as List? ?? [];
    for (var i = 0; i < preferences.length; i++) {
      final preference = preferences[i] as Map;
      add('preferences', '', preference['name'] as String, i, preference);
    }
    // Remember which optional collections existed, including legacy versions.
    return WorkspaceRows(
      canonicalSnapshot(
        jsonEncode({
          'fields': Map.of(value)
            ..removeWhere(
              (key, _) => const [
                'items',
                'savedLists',
                'history',
                'productPreferences',
              ].contains(key),
            ),
          'collections': [
            for (final key in [
              'items',
              'savedLists',
              'history',
              'productPreferences',
            ])
              if (value.containsKey(key)) key,
          ],
        }),
      ),
      records,
    );
  }

  String toSnapshot() {
    final meta = jsonDecode(metadata) as Map<String, dynamic>;
    final collections = meta['collections'] as List;
    if (collections.toSet().length != collections.length ||
        !collections.contains('items') ||
        collections.any(
          (key) => !const [
            'items',
            'savedLists',
            'history',
            'productPreferences',
          ].contains(key),
        )) {
      throw const FormatException('Unsupported stored collections');
    }
    final used = <String>{};
    final groups = <String, List<WorkspaceRecord>>{};
    for (final row in records) {
      final key = jsonEncode([row.kind, row.parent]);
      (groups[key] ??= []).add(row);
    }
    List<WorkspaceRecord> rows(String kind, [String parent = '']) {
      final found = groups.remove(jsonEncode([kind, parent])) ?? [];
      found.sort((a, b) => a.position.compareTo(b.position));
      for (var i = 0; i < found.length; i++) {
        if (found[i].position != i || !used.add(found[i].key)) {
          throw const FormatException('Invalid record order');
        }
      }
      return found;
    }

    Map<String, dynamic> data(WorkspaceRecord row, {String idField = 'id'}) {
      final value = jsonDecode(row.data);
      if (value is! Map<String, dynamic> || value[idField] != row.id) {
        throw const FormatException('Invalid record identifier');
      }
      return value;
    }

    Map<String, dynamic> trip(WorkspaceRecord row) {
      final value = jsonDecode(row.data);
      if (value is! Map<String, dynamic> ||
          value['hasPlan'] is! bool ||
          value['fields'] is! Map<String, dynamic> ||
          value['fields']['id'] != row.id) {
        throw const FormatException('Invalid stored trip');
      }
      return value;
    }

    List<Object?> items(String kind, [String parent = '']) =>
        rows(kind, parent).map(data).toList();
    final snapshot = <String, dynamic>{
      ...meta['fields'] as Map<String, dynamic>,
      'items': items('items'),
      if (collections.contains('savedLists'))
        'savedLists': [
          for (final row in rows('lists'))
            {...data(row), 'items': items('listItems', row.id)},
        ],
      if (collections.contains('history'))
        'history': [
          for (final row in rows('trips'))
            {
              ...trip(row)['fields'] as Map<String, dynamic>,
              'items': items('tripItems', row.id),
              if (trip(row)['hasPlan'] == true)
                'plannedItems': items('tripPlanItems', row.id),
            },
        ],
      if (collections.contains('productPreferences'))
        'productPreferences': [
          for (final row in rows('preferences')) data(row, idField: 'name'),
        ],
    };
    final value = canonicalSnapshot(jsonEncode(snapshot));
    if (used.length != records.length || !CartStore.isValidSnapshot(value)) {
      throw const FormatException('Invalid stored workspace records');
    }
    return value;
  }
}
